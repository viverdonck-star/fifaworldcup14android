#!/bin/bash
# Nomme des décalages de la libc de l'Odin (copiée dans C:\wc14\odin-libs).
Y=~/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-symbolizer
for o in "$@"; do
  echo "$o $($Y -e /mnt/c/wc14/odin-libs/libc.so -f --no-inlines 0x$o | head -1)"
done
