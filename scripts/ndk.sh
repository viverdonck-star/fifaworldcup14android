#!/bin/bash
set -e
cd ~
[ -d android-ndk-r27c ] || {
  python3 -c "import urllib.request as u; u.urlretrieve('https://dl.google.com/android/repository/android-ndk-r27c-linux.zip','/tmp/ndk.zip')"
  sha1sum /tmp/ndk.zip
  python3 -c "
import zipfile, os
z = zipfile.ZipFile('/tmp/ndk.zip')
for i in z.infolist():
    p = z.extract(i, '.')
    m = i.external_attr >> 16
    if m & 0o170000 == 0o120000:
        t = open(p).read(); os.remove(p); os.symlink(t, p)
    elif m:
        os.chmod(p, m & 0o777)
"
  rm -f /tmp/ndk.zip
}
android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --version | head -1
du -sh android-ndk-r27c
df -h / | tail -1
