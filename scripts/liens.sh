#!/bin/bash
# Remplace les liens symboliques git restés en petits fichiers texte par une copie de leur cible.
cd /c/wc14/src/sdk || exit 1
n=0; ko=0
for d in . $(git submodule --quiet foreach --recursive 'echo $displaypath'); do
  while read -r _ _ _ f; do
    p="$d/$f"
    [ -f "$p" ] || continue
    t=$(cat "$p")
    s="$(dirname "$p")/$t"
    if [ -e "$s" ]; then
      rm -f "$p"; cp -r "$s" "$p"; n=$((n+1))
    else
      echo "cible absente: $p -> $t"; ko=$((ko+1))
    fi
  done < <(git -C "$d" ls-files -s | grep '^120000')
done
echo "liens remplaces: $n, sans cible: $ko"
