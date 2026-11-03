# 2014 FIFA World Cup Brazil sur Android (AYN Odin 3)

Dépôt **privé**, pour usage personnel. Il contient le code issu du jeu (`projet/pc/generated/`) et l'icône du jeu : ne pas le rendre public ni le partager.

| Dossier | Contenu |
|---|---|
| `projet/` | Le projet PC d'origine ([HossEz/fifa-world-cup-2014-recompiled](https://github.com/HossEz/fifa-world-cup-2014-recompiled), commit `6167d07`) avec nos modifications : lanceur Android (`launcher/android/`), corrections, code généré |
| `rexglue-sdk/` | Le SDK ReXGlue (`bd833a2`) avec les 40 patchs du projet d'origine et nos modifications Android / ARM64 / Vulkan (Adreno) |
| `android-app/` | L'app Android : manifeste, activités Java (lanceur et jeu), icône, réglages |
| `scripts/` | Compilation (WSL Debian + NDK r27c), construction de l'APK, tests par adb sur l'Odin |
| `TRANSFERT-PORT-ANDROID.md` | L'historique et les résultats du port |

Pas dans le dépôt : l'ISO du jeu, l'APK, la clé de signature et son mot de passe, les sorties de compilation, les outils (NDK, adb, cmake).

Compilation : voir `scripts/` (`sdk-arm64.sh`, `jeu-arm64.sh`, `lanceur-arm64.sh`, `apk2.sh`) et `TRANSFERT-PORT-ANDROID.md`.
