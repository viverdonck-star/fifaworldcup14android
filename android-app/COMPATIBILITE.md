# Compatibilité — World Cup 14 (Android)

## Configuration

| | Minimum | Recommandé |
|---|---|---|
| Android | 13 (API 33), 64 bits | 14 ou plus |
| Processeur | ARM 64 bits (arm64-v8a) | Snapdragon 8 Gen 2 ou plus récent |
| Graphismes | Vulkan 1.1 | Adreno 7xx / 8xx (testé : Adreno 830, AYN Odin 3) |
| Mémoire | 6 Go | 8 Go ou plus |
| Stockage | ~200 Mo pour l'app + l'ISO du joueur (~7 Go) | |
| Commandes | manette intégrée ou manette Bluetooth / USB | |

- Le jeu n'est **pas fourni** : il faut sa propre image disque Xbox 360 (.iso, non compressée).
  Les éditions EU et US sont reconnues ; une autre édition est signalée comme telle.
- Les puces MediaTek (Mali, ex. Helio G99) et les appareils 32 bits ne sont pas pris en charge.
  Sans Vulkan utilisable, le lanceur affiche un message au lieu de se fermer sans rien dire.

## Testé

| Appareil | Résultat |
|---|---|
| AYN Odin 3 (Snapdragon 8 Elite, Adreno 830, Android 15) | match à 40 FPS (recommandé, plus frais) ou 60 FPS ; cinématiques ~28–30 FPS en mode 30 |

## Si ça ne marche pas

1. Lanceur → Réglages → Graphismes : remettre les valeurs « Recommandé ».
2. Si un pilote importé est choisi et que le jeu ne démarre plus : choisir « Celui de l'appareil ».
3. Lanceur → Réglages → Données → Journaux → **Partager**, et envoyer le zip.

## Licences

Code du projet : BSD 3-Clause. Composants : ReXGlue / Xenia (BSD), FFmpeg (LGPL), SDL (zlib),
Dear ImGui (MIT), libmspack (LGPL), stb (domaine public / MIT), libadrenotools (BSD 2-Clause),
Mesa Turnip (MIT).
