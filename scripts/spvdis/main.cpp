// Petit désassembleur SPIR-V : spvdis fichier.spv > fichier.txt
#include <fstream>
#include <iostream>
#include <vector>
#include "SPIRV/disassemble.h"

int main(int argc, char** argv) {
  if (argc < 2) return 1;
  std::ifstream f(argv[1], std::ios::binary);
  std::vector<char> b((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
  std::vector<unsigned int> words(b.size() / 4);
  memcpy(words.data(), b.data(), words.size() * 4);
  spv::Disassemble(std::cout, words);
  return 0;
}
