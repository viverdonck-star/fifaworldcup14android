#include "game_source.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <fstream>
#include <mutex>
#include <unordered_map>

#ifndef _WIN32
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <cstdlib>
#endif

#include "log.h"

namespace launcher {

namespace fs = std::filesystem;

namespace {

std::string Lower(std::string text) {
  std::transform(text.begin(), text.end(), text.begin(),
                 [](unsigned char c) { return char(std::tolower(c)); });
  return text;
}

uint32_t Le32(const uint8_t* p) {
  return uint32_t(p[0]) | uint32_t(p[1]) << 8 | uint32_t(p[2]) << 16 | uint32_t(p[3]) << 24;
}

// ------------------------------------------------------------------ folder

class FolderSource : public GameSource {
 public:
  explicit FolderSource(fs::path root) : root_(std::move(root)) {
    std::error_code ec;
    for (auto it = fs::recursive_directory_iterator(root_, ec);
         it != fs::recursive_directory_iterator(); it.increment(ec)) {
      if (ec) break;
      if (!it->is_regular_file(ec)) continue;
      std::string relative = Lower(fs::relative(it->path(), root_, ec).generic_string());
      files_.push_back(relative);
      paths_[relative] = it->path();
    }
    std::sort(files_.begin(), files_.end());
  }

  const std::vector<std::string>& Files() const override { return files_; }

  int64_t Size(const std::string& path) const override {
    auto found = paths_.find(Lower(path));
    std::error_code ec;
    return found == paths_.end() ? -1 : int64_t(fs::file_size(found->second, ec));
  }

  std::vector<uint8_t> Read(const std::string& path, uint64_t offset,
                            uint32_t size) const override {
    auto found = paths_.find(Lower(path));
    if (found == paths_.end()) return {};
    std::ifstream file(found->second, std::ios::binary);
    file.seekg(0, std::ios::end);
    uint64_t length = uint64_t(file.tellg());
    if (offset >= length) return {};
    size = uint32_t(std::min<uint64_t>(size, length - offset));
    std::vector<uint8_t> data(size);
    file.seekg(std::streamoff(offset));
    if (!file.read(reinterpret_cast<char*>(data.data()), size)) return {};
    return data;
  }

  const fs::path& location() const override { return root_; }

 private:
  fs::path root_;
  std::vector<std::string> files_;
  std::unordered_map<std::string, fs::path> paths_;
};

// ------------------------------------------------------------------ disc image

class IsoSource : public GameSource {
 public:
  static std::unique_ptr<IsoSource> Open(const fs::path& path) {
    auto source = std::unique_ptr<IsoSource>(new IsoSource(path));
    return source->Mount() ? std::move(source) : nullptr;
  }

#ifndef _WIN32
  ~IsoSource() override {
    if (fd_ >= 0) close(fd_);
  }
#endif

  const std::vector<std::string>& Files() const override { return files_; }

  int64_t Size(const std::string& path) const override {
    auto found = entries_.find(Lower(path));
    return found == entries_.end() ? -1 : int64_t(found->second.size);
  }

  std::vector<uint8_t> Read(const std::string& path, uint64_t offset,
                            uint32_t size) const override {
    auto found = entries_.find(Lower(path));
    if (found == entries_.end() || offset >= found->second.size) return {};
    size = uint32_t(std::min<uint64_t>(size, found->second.size - offset));
    return ReadImage(partition_ + uint64_t(found->second.sector) * kSector + offset, size);
  }

  const fs::path& location() const override { return path_; }

 private:
  static constexpr uint64_t kSector = 2048;
  struct Entry {
    uint32_t sector;
    uint32_t size;
  };

#ifdef _WIN32
  explicit IsoSource(fs::path path) : path_(std::move(path)), file_(path_, std::ios::binary) {}

  std::vector<uint8_t> ReadImage(uint64_t offset, uint32_t size) const {
    std::lock_guard lock(mutex_);  // the music streams on its own thread
    std::vector<uint8_t> data(size);
    file_.clear();
    file_.seekg(std::streamoff(offset));
    file_.read(reinterpret_cast<char*>(data.data()), size);
    data.resize(size_t(file_.gcount()));
    return data;
  }

  bool IsOpen() const { return bool(file_); }
#else
  explicit IsoSource(fs::path path) : path_(std::move(path)), fd_(OpenForReading(path_)) {}

  // pread keeps no position, so the music's thread needs no lock.
  std::vector<uint8_t> ReadImage(uint64_t offset, uint32_t size) const {
    std::vector<uint8_t> data(size);
    size_t done = 0;
    while (done < size) {
      ssize_t got = pread(fd_, data.data() + done, size - done, off_t(offset + done));
      if (got < 0 && errno == EINTR) continue;
      if (got <= 0) break;
      done += size_t(got);
    }
    data.resize(done);
    return data;
  }

  bool IsOpen() const { return fd_ >= 0; }
#endif

  // Finds the game partition by its volume descriptor and reads the tree.
  bool Mount() {
    if (!IsOpen()) return false;
    for (uint64_t partition : {uint64_t(0), uint64_t(0x2080000), uint64_t(0xFD90000),
                               uint64_t(0x18300000)}) {
      std::vector<uint8_t> descriptor = ReadImage(partition + 32 * kSector, 28);
      if (descriptor.size() == 28 &&
          std::memcmp(descriptor.data(), "MICROSOFT*XBOX*MEDIA", 20) == 0) {
        partition_ = partition;
        ReadDirectory(Le32(&descriptor[20]), Le32(&descriptor[24]), "", 0);
        std::sort(files_.begin(), files_.end());
        return !files_.empty();
      }
    }
    return false;
  }

  // A directory: entries packed in sectors (none crosses a sector boundary),
  // each u16 left / right subtree offsets (in 4-byte units), u32 start
  // sector, u32 size, u8 attributes (0x10: directory), u8 name length, the
  // name, padded to 4 bytes. The whole table is read and walked in order.
  void ReadDirectory(uint32_t sector, uint32_t size, const std::string& prefix, int depth) {
    if (depth > 32 || !size) return;
    std::vector<uint8_t> table = ReadImage(partition_ + uint64_t(sector) * kSector, size);
    size_t pos = 0;
    while (pos + 14 <= table.size()) {
      uint16_t left = uint16_t(table[pos] | table[pos + 1] << 8);
      if (left == 0xFFFF) {  // padding to the next sector
        pos = (pos / kSector + 1) * kSector;
        continue;
      }
      uint32_t start = Le32(&table[pos + 4]), length = Le32(&table[pos + 8]);
      uint8_t attributes = table[pos + 12], name_length = table[pos + 13];
      if (pos + 14 + name_length > table.size()) break;
      std::string name(reinterpret_cast<const char*>(&table[pos + 14]), name_length);
      std::string path = prefix + Lower(name);
      if (attributes & 0x10) {
        ReadDirectory(start, length, path + "/", depth + 1);
      } else {
        files_.push_back(path);
        entries_[path] = {start, length};
      }
      pos = (pos + 14 + name_length + 3) & ~size_t(3);
    }
  }

  fs::path path_;
#ifdef _WIN32
  mutable std::mutex mutex_;
  mutable std::ifstream file_;
#else
  int fd_;
#endif
  uint64_t partition_ = 0;
  std::vector<std::string> files_;
  std::unordered_map<std::string, Entry> entries_;
};

}  // namespace

#ifndef _WIN32
int OpenForReading(const fs::path& path) {
  // /proc/self/fd/<n> is a document Android's picker opened for the app: it's
  // read through that descriptor. Opening the path again checks the app's own
  // access to the file, which many devices refuse (the provider opened it).
  const std::string text = path.string();
  const std::string own = "/proc/self/fd/";
  if (text.compare(0, own.size(), own) == 0) {
    char* end = nullptr;
    long fd = std::strtol(text.c_str() + own.size(), &end, 10);
    if (end && !*end && fd >= 0) {
      int copy = fcntl(int(fd), F_DUPFD_CLOEXEC, 0);
      if (copy >= 0) return copy;
    }
  }
  int fd = open(text.c_str(), O_RDONLY | O_CLOEXEC);
  if (fd < 0) Log("can't open %s: %s", text.c_str(), std::strerror(errno));
  return fd;
}
#endif

std::vector<uint8_t> GameSource::ReadAll(const std::string& path) const {
  int64_t size = Size(path);
  return size < 0 ? std::vector<uint8_t>{} : Read(path, 0, uint32_t(size));
}

std::unique_ptr<GameSource> OpenGameSource(const fs::path& location) {
  std::error_code ec;
  if (fs::is_directory(location, ec)) return std::make_unique<FolderSource>(location);
  if (fs::is_regular_file(location, ec)) return IsoSource::Open(location);
  return nullptr;
}

}  // namespace launcher
