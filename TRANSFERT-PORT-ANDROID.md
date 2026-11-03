# World Cup 14 sur Odin 3 : document de transfert

Écrit le 01/11/2026 à la fin du projet NBA 2K14. Ce document suffit pour démarrer une nouvelle conversation.

**But :** une app Android pour l'AYN Odin 3. On choisit l'ISO, puis le jeu démarre en natif, comme « NBA 2K14 Solo ».

## Comment démarrer

Ouvre une nouvelle conversation dans le dossier `C:\Users\viver\Desktop\WORLD CUP 14`, puis colle ce message :

```text
Lis TRANSFERT-PORT-ANDROID.md dans ce dossier et suis-le. Commence par la section "Plan", étape 0, et explique-moi simplement ce que tu vas faire.
```

## En bref

Le port semble faisable, mais rien ne garantit qu'il aboutisse.

| Sujet | État | Explication simple |
|---|---|---|
| Ton ISO | Bon signe | La version Europe est reconnue par le projet PC |
| Code du jeu sur ARM64 | Très encourageant | Le jeu est déjà converti en C++, et l'outil gère ARM64 sous Linux |
| Son, manette, app | Faisable | On réutilise ce qui marche déjà dans NBA 2K14 Solo |
| Image sur Adreno 830 | **Risque principal** | Le projet PC est réglé pour Direct3D 12 et Android utilise Vulkan |
| « Je choisis l'ISO et ça marche » | Faisable | Le code est dans l'APK, l'ISO fournit les données |

Il faudra plusieurs sessions de travail. Ce n'est pas une simple recompilation.

**Attention, la langue :** ton disque contient l'anglais, l'allemand et l'italien, pas le français. Le français existe seulement sur le disque USA. D'après le code du projet, une langue absente fait basculer le jeu en allemand. Il faudra donc forcer l'anglais.

## Le projet de départ

- Dépôt : https://github.com/HossEz/fifa-world-cup-2014-recompiled, version 0.2.0 du 31/10.
- Licence : BSD 3-Clause pour le code du projet. Elle ne couvre ni le jeu ni le code généré depuis le jeu.
- Il utilise le SDK ReXGlue : https://github.com/rexglue/rexglue-sdk, commit `bd833a2`, branche `development`, plus 40 patchs dans `patches/rexglue-sdk/`.
- `rexglue codegen pc/fifawc14_manifest.toml` lit les 3 exécutables du jeu et écrit environ 450 fichiers dans `pc/generated/`. Ce dossier n'est jamais publié.
- Plateforme officielle : Windows 10/11, Direct3D 12, SSE4.2. Android et ARM64 ne sont pas prévus par le projet.

Réglages requis d'après `BUILDING.md` : `gpu_allow_invalid_fetch_constants = true`, `readback_resolve = "none"`,
`protect_zero = false`, `execute_unclipped_draw_vs_on_cpu = true`, `async_shader_compilation = false`,
`d3d12_submit_on_primary_buffer_end = false`, `clear_memory_page_state = false`, `present_interval_cap = 1`,
`frame_rate_floor = 60`.

## Ton ISO, vérifié sans le modifier

Fichier : `2014 FIFA World Cup Brasil [RF][ENG,GER,ITA].iso`, 8 738 846 720 octets.

- Partition de jeu à l'offset `0x2080000`, 222 fichiers, 6,04 Go.
- Media ID `5D31A745`, Title ID `454109D4`, version 13, disque 1 sur 1.
- `default.xex` : 30 691 328 octets. Les deux modules attendus sont présents :
  `dlc/dlc_FootballCompEng/dlc/FootballCompEng/FootballCompEngzf.xex.dll` et `dlc/dlc_powdll/dlc/powdll/powdllzf.xex.dll`.
- `launcher/src/game_check.cpp` liste `0x5D31A745` comme « Europe », langues 1, 3 et 6 (anglais, allemand, italien).
- Ce même fichier indique que le code est identique sur les disques Europe et USA.

**Pas encore vérifié :** le SHA-256 du code décompressé. Le lanceur officiel le contrôlera à l'étape 0.

`outils/lire_iso.py` relit ces informations :

```bash
python -I outils/lire_iso.py "2014 FIFA World Cup Brasil [RF][ENG,GER,ITA].iso"
```

## Ce qui a été vérifié pour le passage à Android

Dans ReXGlue au commit `bd833a2` :

- Présets `linux-arm64-*`, et compilation automatique `build-linux-aarch64.yaml`.
- `thirdparty/simde`, pour traduire les instructions x86 de calcul.
- Moteur graphique Vulkan présent, avec `command_processor` et `render_target_cache`.
- Fonctions `instance_khr_android_surface.inc` présentes, mais **aucun préset Android**.

Dans les patchs du projet : la plupart des patchs d'image et de vitesse visent D3D12 (0001, 0007, 0011, 0013, 0014, 0016,
0017, 0027 à 0031, 0033, 0034, 0036, 0037). Certains sont utiles à Windows seulement (0019 à 0021, 0023, 0032).
**Il faudra refaire leur équivalent Vulkan quand le jeu en a besoin.** Le patch 0010 (lecture directe d'un `.iso`) n'a pas
l'air lié à Windows, à confirmer. Dans le code du jeu, `pc/fixes/gpu_memcpy.cpp` remplace une copie mémoire par une copie GPU.
`readback_resolve = "none"` en dépend. Son fonctionnement sous Vulkan reste à vérifier en premier.

Personne n'a encore testé ce jeu sous Vulkan, ni sur ARM64, à ma connaissance.

### Ports Android déjà faits avec cette technique

À étudier avant d'écrire du code. Ce sont des projets amateurs, leurs annonces ne sont pas vérifiées.

| Projet | Intérêt |
|---|---|
| https://github.com/Buku313/Skate3-Android | Jeu EA, ReXGlue, NDK r27c, SDL3, libadrenotools, installation depuis un ISO. Son image est **refaite à la main** en Vulkan, pas émulée |
| https://github.com/SansNope/MarathonRecomp-Android | Testé sur Snapdragon 8 Elite, 4 profils Turnip, reprise après mise en arrière-plan. Autre outil : XenonRecomp |
| https://github.com/gabrielbskk/mcla-recomp-android-g | ReXGlue, mais encore très saccadé. Utile pour les pièges |

Conséquence : le chemin « Vulkan de ReXGlue sur Adreno » n'est prouvé par aucun de ces ports pour un jeu aussi lourd.
Refaire tout le rendu comme Skate 3 serait un très gros chantier, à garder en dernier recours.

## Résultats du 01/11/2026

**Étape 0 validée par l'utilisateur.** Vérifié : ISO lu, RTX 4070 utilisée, intro affichée. Non testé : match en Direct3D 12, contrôle SHA-256 du lanceur.
Référence : `pc-reference/jeu/fifa-world-cup-2014-recompiled/`.

**Étape 1 : un match s'affiche correctement sous Vulkan sur la RTX 4070**, avec le jeu portable non recompilé.

- Outils : `C:\wc14\outils` (LLVM 23.1.4, CMake 4.4.5, Ninja 1.13.2), Visual Studio Community 2022. Scripts : `C:\wc14\scripts`, avec `env.cmd` pour l'environnement.
- SDK patché : `C:\wc14\src\sdk`. Version Vulkan : `cmake --preset win-amd64 -B out/build/vk -DREXGLUE_USE_VULKAN=ON`, installée dans `out/install/vk`.
- Ajout local dans `src/graphics/plugin_main.cpp` : `REX_GPU_BACKEND=vulkan` force le moteur sans recompiler le jeu.
- Test : `C:\wc14\vk-test`, copie du portable avec `rexgpu-xenos.dll` et `rexruntime.dll` de la version Vulkan. Lancer `lancer-vulkan.cmd`.

| Réglages Vulkan | Maillots | Match |
|---|---|---|
| Par défaut (`readback_resolve = "none"`, chemin FBO) | Noirs et déchirés | Blanc-bleu, illisible |
| `readback_resolve = "full"`, chemin FBO | Couleurs revenues, petits pixels, shorts cassés | Voile blanc-bleu |
| `readback_resolve = "full"` + `render_target_path_vulkan = "fsi"` | Propres | Correct |

Pendant l'attente du coup d'envoi : environ 60 images/s d'après le journal, RTX à 50 %, rendu interne 1280x720. Non mesuré : jeu réel, durée d'un match, son.

**FSI est impossible sur l'Odin (lu sur la console le 01/11).** `fragmentShaderSampleInterlock`, `PixelInterlock` et `ShadingRateInterlock` valent 0 sur le pilote Qualcomm (Vulkan 1.3.284) et sur les 3 Turnip de `~/nba2k14/turnip`. `shaderStorageImageMultisample` vaut aussi 0 partout. `VK_EXT_rasterization_order_attachment_access` est présente, mais Xenia et ReXGlue ne l'utilisent pas, à ma connaissance.
Sonde : `C:\wc14\scripts\vkq.c`, `odin2.sh` et `odin4.sh`. Pour Turnip : binaire glibc, `env -u LD_PRELOAD`, `host/ld-linux-aarch64.so.1`.

**Il faut donc réparer le chemin FBO, le seul possible sur l'Odin.** Bon signe : Direct3D 12 utilise déjà le chemin équivalent (host render targets) sur NVIDIA, et le test `render_target_path_d3d12 = "rtv"` avec `readback_resolve = "none"` a donné une 3D correcte sur le mini-jeu de chargement. Le bug semble propre au Vulkan de ce SDK, ou à des patchs D3D12 sans équivalent Vulkan. Pas vu dans ce test : écran des maillots, vrai match.
Le chemin FSI reste une référence d'image sur la RTX. Réglages : `C:\wc14\vk-test\reglages-vulkan-fsi.toml`, `reglages-vulkan-fbo.toml` et `reglages-d3d12-rtv.toml`.
Autre point à mesurer : le coût de la recopie complète sur l'Odin.

**Chemin FBO, meilleur état actuel :** `readback_resolve = "full"` + `native_2x_msaa = false`. Le voile en match disparaît au coup d'envoi. Reste un défaut : shorts cassés et grain sur les maillots à l'écran des maillots. Le fond du menu y est aussi plus pâle qu'en Direct3D 12.

Banc d'essai automatique : `C:\wc14\scripts\banc.ps1` (réglages, navigation jusqu'aux maillots puis au match, captures). La fenêtre doit rester au premier plan.

Ce qui a été éliminé pour les shorts sous Vulkan FBO, sans effet : `gamma_render_target_as_unorm16`, `mrt_edram_used_range_clamp_to_min`, `snorm16_render_target_full_range`, `vulkan_dynamic_rendering`, `native_stencil_value_output`, `clear_memory_page_state`, `vulkan_sparse_shared_memory`, `vulkan_submit_on_primary_buffer_end`, `direct_host_resolve`. `execute_unclipped_draw_vs_on_cpu = false` noircit en plus le fond.
Sous Direct3D 12 sans ROV, les shorts restent propres même avec `readback_resolve = "full"`, `clear_msaa_redirect = false`, `direct_resolve_32bpp = false`, `resolve_to_texture = false` ou `native_2x_msaa = false`. Le bug est donc propre au Vulkan du SDK.
Lu sans trouver d'erreur : mapping des échantillons pour un même bpp, alpha to coverage SPIR-V, indicateur MSAA.
Piste restante : le jeu passe la même zone EDRAM de 4xMSAA à 1xMSAA (journal : 520x1264 4x, 1040x2528 1x). Le défaut existe déjà avec et sans `direct_host_resolve`, donc avant la copie : regarder les transferts entre cibles et les effacements (`PerformTransfersAndResolveClears`).
Il reste aussi à porter le patch 0001 vers Vulkan (`SupportsGpuMemoryCopy`, `ExecuteGpuMemoryCopy`, `ExecuteGpuMemoryReadback`) pour remplacer la recopie complète, qui coûtera cher sur l'Odin.

**Étape 2 : le jeu compile pour Android ARM64 (`libfifawc14.so`, 128 Mo). Rien n'a encore tourné.**

- Dans Debian WSL : NDK r27c `~/android-ndk-r27c`, SDK `~/wc14/sdk` (installé dans `out/install`, bibliothèques dans `out/linux-arm64`), jeu `~/wc14/projet/pc/out/android`. Scripts : `C:\wc14\scripts\tout-arm64.sh`, `sdk-arm64.sh`, `jeu-arm64.sh`. Sources de référence sous Windows : `C:\wc14\src`.
- Code généré sous Windows (`codegen.cmd`, 11 min) depuis `C:\wc14\jeu` (3 exécutables extraits par `extraire.py`). Le `rexglue` ARM64 ne tourne pas sur le PC : `jeu-arm64.sh` remplace l'étape de génération de `rexglue.cmake`.
- 10 fichiers Android repris de `Buku313/rexglue-skate3-android` (mémo : l'historique du fork est séparé de ReXGlue, il n'a pas toutes nos corrections). Adaptations : `fiber.h`, `numeric.h`, `chrono.h`, `threading_posix.cpp`, `window_sdl.cpp`, `windowed_app_main_sdl.cpp`, CMake de `core`, `ui`, `thirdparty`.
- `fifawc14_register.cpp` (114 319 appels) bloquait le compilateur plus de 20 min, même en -O0. `table-register.py` en fait un tableau : 4 secondes. À refaire si le code est régénéré.

**Étape 3 : un match tourne sur l'Odin (01/11/2026), pilote Qualcomm, Vulkan, chemin FBO.**

- APK de test `com.wc14.test` : sources dans `C:\wc14\app`, construit par `C:\wc14\scripts\apk.sh`, clé privée dans `~/wc14/.cle.*` (WSL). Mise à jour complète : `maj-odin.sh`.
- Sur l'Odin : dossier `/storage/emulated/0/WC14` avec `wc14.iso`, `fifawc14.toml`, `portable.txt`, `saves`, `logs`, `fifawc14.log`.
- Test à distance par adb dans Termux : `adb connect 127.0.0.1:<port>`, port affiché dans Débogage sans fil, noté dans les scripts (46255 le 01/11, il change). `odin-jeu.sh demarre`, `odin-jeu.sh "<touches>" <attente> <nom>` (`input keyevent --longpress`, 66 Start, 62 A), `ecran.sh`, `mesure.sh`, `crash.sh`.
- Sur l'Adreno, les maillots, les shorts et le menu sont propres avec `readback_resolve = "full"`, `native_2x_msaa = false` : ces défauts sont ceux du Vulkan NVIDIA. Ne plus chercher sur la RTX sans vérifier sur l'Odin.

| Réglage | Menus | Écran des maillots | Match | GPU | CPU maxi |
|---|---|---|---|---|---|
| `readback_resolve = "full"` | 60 images/s | 17-30 | 16 | 33 % à 900 MHz | 52 °C |
| `readback_resolve = "fast"` | 58-60 | 32-60 | 31 | 56 % à 900 MHz | 60 °C |

Mesures de quelques dizaines de secondes, au coup d'envoi ou peu après, sans jouer. **`fast` n'est pas utilisable tel quel, l'image est fausse** : en match, équipes aux maillots mélangés (rouges et jaunes pour l'Argentine) et image plus sombre ; à l'écran des maillots, l'Argentine porte le maillot du Brésil. Il montre seulement la vitesse possible sans l'attente de `full`.
Fils les plus chargés en match : `SDLThread` 89-100 %, `GPU Commands` 44-78 %, `Audio Worker` 70-74 %. Le 100 % de `SDLThread` et le coût de `Audio Worker` sont à comprendre en premier : le GPU a encore de la marge.
**Patch 0001 porté vers Vulkan** (`C:\wc14\scripts\port-0001.py`, déjà appliqué sur `C:\wc14\src\sdk`) : `readback_resolve = "none"` + `gpu_memcpy.cpp` donnent l'image correcte, maillots de l'Argentine compris, 60 images/s aux maillots et 33 en match, GPU 54 % à 900 MHz, CPU maxi 55 °C.

**Le CPU était bridé pendant toutes ces mesures** : `scaling_max_freq` à 1,79 et 1,96 GHz (maxima 3,53 et 4,32 GHz), `performance_mode=1`, tuile `com.aure.clustertune` présente. Réglage de l'utilisateur : ne pas le changer soi-même. Refaire les mesures avec un autre mode. `simpleperf` est refusé (Permission denied) ; un profilage demandera une autre méthode.
**L'utilisateur garde le mode éco : optimiser sans changer ce réglage.**

État de l'APK de test installé : `readback_resolve = "none"`, `native_2x_msaa = true`, 33 images/s au coup d'envoi, GPU 51 % à 900 MHz, CPU maxi 56 °C, écran des maillots non remesuré dans ce réglage exact. `SDLThread` passe de 100 à 26 % grâce à `SDL_PollEvent` + 2 ms sous Android. `GPU Commands` tourne moins longtemps à vide (16 tours). Attentes multiples à 2 ms sous Android.
Le jeu reste vers 30-33 images/s alors qu'aucun fil de jeu n'est saturé. Hypothèse non prouvée : une image dépasse juste les 16,7 ms et rate le rendez-vous de 60 Hz. `Audio Worker` reste à 67 %, cause inconnue.
Échantillonneur intégré (`pc/src/sampler_android.cpp`, sans `simpleperf`) : `C:\wc14\scripts\echantillon.sh`, à lancer pendant le jeu.

**DÉFAUT MAJEUR : pas de public en Vulkan.** Signalé par l'utilisateur, confirmé sur l'Odin et la RTX : tribunes vides, alors qu'elles sont pleines en Direct3D 12 (mêmes écrans). Sans effet : `vulkan_force_convert_quad_lists_to_triangle_lists`, `vulkan_force_expand_point_sprites_in_vs`. Aucune erreur GPU au journal. Direct3D 12 ne journalise pas ses pipelines : la comparaison de shaders par journal n'a rien donné. `saves/cache/shaders/shareable/*.d3d12.xpso.cote` est une copie mise de côté, sans importance.
**Cause trouvée et corrigée le 02/11/2026** dans `src/graphics/pipeline/shader/spirv_translator_fetch.cpp` : le traducteur SPIR-V lisait `exp_adjust` (multiplicateur 2^n des textures) dans le mot 4 de la constante de texture au lieu du mot 3, comme le fait le DXBC et comme le dit `xenos.h`. Pour la texture des spectateurs, le mot 4 donnait 2^-16 : rouge, vert et bleu noirs dans l'atlas 2048×2048 en 4-4-4-4 (`1BEEB000`, refait à chaque image), puis cartes de foule (VS `61E2DADF`) invisibles. Public revenu en Vulkan sur la RTX. Ce défaut touche toutes les textures dont le mot 4 a des bits 13-18 non nuls : d'autres écarts de couleur Vulkan peuvent venir de là.
Méthode, réutilisable : `vulkan_capture_trigger = 'chemin'` (le fichier, quand il apparaît, déclenche la capture d'une image dans les deux moteurs ; `banc.ps1 -Capture`), `C:\wc14\scripts\compare-capture.py` (dessins), `gpu_skip_vertex_shader = 'HASH HASH'` en D3D12 (sauter des shaders pour trouver ce qu'ils dessinent), `dump_shaders` (le Vulkan écrit maintenant aussi ses SPIR-V), `C:\wc14\scripts\spvdis\spvdis.exe` (désassembleur SPIR-V construit avec glslang), `compare-atlas.py`. adb pour Windows : `C:\wc14\outils\platform-tools\adb.exe`, l'Odin marche en USB.
Vérifié sur l'Odin le 02/11/2026 (APK refait par `C:\wc14\scripts\apk-libs.sh` sans Termux, installé par USB, match lancé par `C:\wc14\scripts\odin-usb.ps1` puis Start au mini-jeu de chargement) : public présent, maillots corrects. Mesure en match : 57 images/s, GPU 77 % à 900 MHz, **mais le CPU n'était plus bridé** (3,53 et 4,20 GHz sur des maxima de 3,53 et 4,32, alors que `performance_mode` affichait toujours 1) et a atteint 105 °C ; jeu fermé, 65 °C après 15 s. Ce chiffre n'est donc pas une mesure en mode éco. Je n'ai touché à aucun réglage. L'utilisateur confirme l'avoir passé en **mode performance**, puis l'a remis dans **son mode habituel** (CPU plafonné à 2,23 et 2,25 GHz, GPU max 1,1 GHz) : c'est la cible, sans jamais changer ce réglage.

**Vitesse dans le mode habituel, 02/11/2026 : de 33-37 à 60 images/s en match** (597 images en 10 s, stable sur 40 s), public présent, GPU 82-85 % à 900 MHz, CPU 76 °C et GPU 66 °C après environ une minute. Échantillonneur (`C:\wc14\scripts\echantillon-usb.sh`, noms de la libc par `libc-noms.sh` avec `C:\wc14\odin-libs\libc.so`) : deux causes, corrigées dans le SDK.
1. `src/system/mmio_handler.cpp` : à chaque faute d'écriture sur une page surveillée, `memory::QueryProtect` relisait tout `/proc/self/maps` (`std::ifstream`, `read`/`lseek`), sur les fils du jeu. Retiré sous Android, comme Xenia sous Linux où `QueryProtect` n'existe pas : le rappel vérifie déjà son propre état de surveillance et rétablit l'accès d'une page déjà libérée.
2. `src/core/threading_posix.cpp` `WaitMultiple` : boucle sans sommeil quand un verrou est pris, tableau alloué à chaque tour (verrous de l'allocateur scudo), sommeil arrondi à 0 ms près de l'échéance. Corrigé sous Android (tableau alloué une fois, 100 µs si verrou pris, sommeil en microsecondes). `Audio Worker` n'apparaît plus parmi les fils chargés.
Les relectures GPU (patch 0001, compteur ajouté au journal) ne se produisent pas en match.
**Chaleur sur une mi-temps entière** (mode habituel, IA contre IA, `C:\wc14\scripts\chaleur.ps1` + `mesure-odin.sh`, coupure à 95 °C) : 57-60 images/s du début à la fin, GPU 76-86 %, CPU max 75 → 83 °C, GPU max 68 → 75 °C, en lente montée sans palier atteint. Jeu fermé à la mi-temps : CPU 61 °C et GPU 53 °C 30 s après. L'overlay de l'Odin affichait 60,3 images/s et 74,1 °C.
Non vérifié : un match joué à la manette, le son, une seconde mi-temps (la température montait encore lentement), et le même gain dans les menus.
**App finale, 02/11/2026 : le lanceur PC porté sur Android** (demande de l'utilisateur : le design du jeu 2014 et toutes les fonctions du lanceur PC, juste importer l'ISO). Mêmes sources que le lanceur PC (`launcher/src`, variantes `#ifdef __ANDROID__`), partie Android dans `launcher/android` (`main_android.cpp`, `CMakeLists.txt`, `updater_stub.cpp`) :
- `liblauncher.so` (Dear ImGui sur l'API GPU de SDL3, donc Vulkan : le SDL du SDK n'a ni rendu 2D ni OpenGL ES), textures DXT décodées sur le CPU, son par flux audio SDL3, SHA-256 et AES par FFmpeg (`libavutil`), police Roboto du système pour l'écran de choix.
- `LauncherActivity` (Java) : sélecteur de fichiers Android (`ACTION_OPEN_DOCUMENT`), permission persistante sur l'ISO, lecture native par `/proc/self/fd/<n>`. Plus besoin de `MANAGE_EXTERNAL_STORAGE` (retirée). Réglages, journaux et sauvegardes dans `Android/data/com.wc14.test/files` (+ `portable.txt`, donc `saves/`).
- Jouer : `MainActivity` (le jeu) dans le processus `:game`, qui rouvre l'ISO et écrit son descripteur dans `game_data_root` ; le processus se termine avec le jeu (`killProcess`). Retour au menu détecté par le focus de la fenêtre, musique relancée.
- Retirés sous Android : fenêtre, taille, écran, VSync, raccourci bureau, mises à jour. « Open folder » affiche le chemin. Cadence : 60 FPS ou comme sur console. Résolution : 720p ou 1440p (1440p non testée). Texte « À propos » et accueil adaptés. « (Alt+F4) » retiré du message de sortie du jeu (`pc/src/quit_shortcut.cpp`).
- APK sans Termux : `C:\wc14\scripts\apk2.sh`, manifeste binaire par `C:\wc14\scripts\axml.py` (l'aapt de Debian ne lit pas les ressources d'Android 15 ; identifiants d'attributs tirés d'android.jar par `attrs.sh`). Tout d'un coup : `C:\wc14\scripts\lanceur-apk.ps1` (lanceur `lanceur-arm64.sh`, jeu `jeu-arm64.sh` à part).
Vérifié sur l'Odin par adb : écran de choix, sélecteur Android, contrôle « European disc », menu aux images du jeu, musique EA Trax, réglages, Jouer (intro du jeu), retour au menu avec la musique, réouverture de l'ISO au redémarrage sans nouveau choix.
Non vérifié : navigation avec les vrais boutons de l'Odin, sortie du jeu par Back + Start, écrans Commandes et À propos, 1440p, FSR. Pas d'icône d'app à soi (icône Android par défaut, nom « World Cup 14 »). Les sauvegardes de test de `/storage/emulated/0/WC14` ne sont plus utilisées : nouveau profil, et cache de shaders vide au premier match.
**Icône de l'app, 02/11/2026** (choix de l'utilisateur : l'icône du jeu) : la même que le lanceur PC, la tuile `custompanels_77.dds` (logo EA Sports, « 2014 FIFA World Cup Brazil »), extraite de sa copie par `Launcher.exe --icon` puis `C:\wc14\scripts\ico-png.py` ; icône adaptative (`C:\wc14\app\res\mipmap-anydpi-v26\app.xml`, calques par `icone-calques.py` : image au cercle sûr, fond de la couleur de ses bords). Ressources compilées par l'aapt de Debian sans framework, XML de l'icône et manifeste encodés par `axml.py` avec les identifiants obtenus (`apk2.sh`). Cette image du jeu est dans l'APK : il reste strictement privé.
**Bandes noires : corrigé le 02/11/2026.** C'étaient les barres d'état et de navigation d'Android, noires et vides, laissées visibles au-dessus du jeu lancé depuis le menu (`dumpsys window` : `statusBars frame=[0,0][1920,55] visible=true`, `navigationBars [0,1025][1920,1080]`). `LauncherActivity.Immersive` les masque (`WindowInsetsController.hide(systemBars)`, glisser pour les montrer), à la création et à chaque retour du focus, dans les deux activités. Vérifié : barres `visible=false`, image entière. Le journal `Presenter layout` (`presenter.cpp`) reste, une ligne quand le cadrage change.
Historique de la recherche (DÉFAUT signalé par l'utilisateur : bandes noires en haut et en bas en jeu) (environ 55 pixels chacune, intro, choix des maillots), absentes avec l'ancienne app de test (menu du 01/11 plein écran). La chaîne d'échange est en 1920×1080 (`VulkanPresenter: Created 1920x1080 swapchain`) et l'écran aussi (`wm size`). Le calcul de `presenter.cpp` donne exactement ces bandes si la surface est vue en 16:10. Sans effet : retirer `present_late_tolerance`, `anisotropic_override`, `resolution_scale`, `mnk_exact_modifiers`, les `keybind_*`, la police et le panneau de sortie (`futurastd-condensed.ttf`, `quit-panel.png`). Pas encore testés : `user_language`, `quit_*` et `video_mode_refresh_rate` (réécrits à chaque Jouer ; `run-as … am start` est refusé, il faut un lanceur modifié), et la différence d'activité (ancienne app : `singleInstance`, lancée seule). Piste suivante : journaliser dans `presenter.cpp` la taille de surface, le rapport d'aspect de l'image du jeu et la zone de sortie.

## Plan

Chaque étape a une condition pour continuer. Si elle échoue, on s'arrête et on explique les options à l'utilisateur.

**Étape 0, référence PC.** Installer la version portable 0.2.0 sur le PC et lancer l'ISO.
Il faut l'accord de l'utilisateur pour télécharger, et ses mains pour jouer. Vérifier : l'ISO est accepté, le jeu démarre, un match se lance.

**Étape 1, Vulkan sur le PC (test décisif).** Compiler le projet pour PC avec le moteur Vulkan de ReXGlue, sur la RTX 4070.
C'est le test le moins cher : il montre ce qui casse sans la Direct3D 12, sans Android.
Lister les effets perdus (écrans noirs, maillots, ombres), puis porter uniquement les patchs nécessaires.

**Étape 2, ARM64.** Générer le code puis compiler avec le NDK dans Debian WSL.
Maximum 4 tâches en parallèle, car WSL n'a que 7 Go de RAM environ et a déjà planté au-delà.
Vérifier : la mémoire invitée de 4 Go sur Android, la taille de page réelle de l'Odin, et `simde`. Regarder comment Skate3-Android a réglé ces points.

**Étape 3, premier démarrage sur l'Odin.** Petit APK de test avec journaux, sans interface.
Atteindre les menus. Essayer le pilote système Qualcomm et Turnip par libadrenotools.

**Étape 4, image et vitesse en match.** Voir les leçons plus bas. Mesurer avant d'optimiser.

**Étape 5, l'app finale.** Écran de choix de l'ISO, contrôle par Media ID et SHA-256 du code, réglages, manette, son, menu et quitter, sauvegardes.

### Choisir l'ISO dans l'app

Le code du jeu est compilé une fois sur le PC, puis placé dans l'APK. L'ISO sert ensuite pour les textures, sons et stades.
Le patch 0010 attend un vrai chemin de fichier. Options, à trancher à l'étape 5 :

1. Lire l'ISO directement avec la permission « tous les fichiers ». Recommandé : aucune copie, 6 Go économisés.
2. Extraire 6 Go en stockage privé, comme Skate 3. Plus simple pour le système, mais tout disparaît à la désinstallation.

## Ce qu'on reprend de NBA 2K14 Solo

Tout est dans `C:\Users\viver\Desktop\NBA2K14 Next Gen\android-build\`.

| Besoin | Fichier | Remarque |
|---|---|---|
| Vue d'ensemble | `PLAN-APP-AUTONOME.md`, `PASSATION-CLAUDE.md` | Historique complet |
| Compiler Java sans SDK, signer | `app/construire.sh` | Le SDK ou NDK peut remplacer cette méthode ici |
| Afficher une image, cadence 40 images/s | `app/jni/ecran.c`, `patch-flip-sync.py` | À adapter : pas de processus séparé ici |
| Manette et touches | `app/src/com/nba2k14/lanceur/Manette.java`, `JeuActivity.java` | `TOUCHES_MENU` contient la touche bas droite de l'Odin |
| Jeu en arrière-plan | `Partie.java`, `PartieService.java` | Service au premier plan |
| Accès à distance | `termux-kit/LISEZ-MOI-SSH.md`, `termux-kit/odin-test.sh`, `termux-kit/odin.conf` | Tests sans toucher la console |
| Signature | `keys/LISEZ-MOI.txt` | Ne jamais recopier le mot de passe, ni dans un document ni dans une conversation |

Différences importantes : pas de FEX, pas de `exec`, le jeu est une bibliothèque `.so` dans l'APK. On peut donc viser un `targetSdk` récent. Pas de Turnip glibc : il faut une version Android.

Le dossier `outils/` contient `appbuild.sh`, `final7.sh`, `rythme.sh` et `etat.sh`, les derniers scripts de NBA à titre d'exemple.
Ils visent les chemins de NBA : à lire avant usage. Historique complet de la conversation NBA :
`C:\Users\viver\.claude\projects\C--Users-viver-Desktop-NBA2K14-Next-Gen\9c22a707-abaa-4d94-8358-ecdb8dcf7ea5.jsonl`.

## Leçons de NBA 2K14 à appliquer ici

- **Turnip n'a pas `shaderStorageImageMultisample`.** Sur NBA, cela cassait l'image en silence (`patch-msaa-storage.py`). Le rendu Xbox 360 utilise du MSAA, à vérifier tout de suite.
- **Comparer le même écran avec la même sauvegarde.** Une fausse conclusion PC contre Odin a coûté très cher.
- **Le PC sert à trancher vite.** Une recherche sur PC coûte bien moins qu'une série de tests sur l'Odin.
- **Mesurer avant d'optimiser.** Journaliser images/s, temps GPU et températures.
- **Limiter le MSAA** a été le gain le plus fort sur NBA : dépassements supprimés, GPU à 60 %, point chaud à 81-88 °C ventilateur au maximum.
- **`TU_DEBUG=sysmem`** a apporté un petit gain. Mailbox provoquait des saccades.
- **Horloge :** sur NBA, le jeu tournait 1,8 fois trop vite à cause d'une horloge fausse. Vérifier la vitesse réelle du jeu.
- **Cadence :** seules 30, 40 et 60 images/s divisent bien 120 Hz. La synchronisation sur Choreographer a supprimé les saccades. `ANativeWindow_setFrameRate` ramène le rappel de l'app vers 41 Hz en mode 40, c'est normal.
- **Le jeu vise 60 images/s sur PC.** La vitesse du jeu dépend peut-être de vblank : à vérifier avant de proposer 40.
- **Son :** AAudio en mode partagé. Le mode MMAP exclusif donnait 500 sous-capacités par seconde.

## L'Odin et le PC

- AYN Odin 3, Snapdragon 8 Elite, Adreno 830, 12 Go de RAM, Android 15, écran 120 Hz. Laisser l'écran en 120 Hz.
- Stockage au 01/11 : interne 75 Go libres, carte SD 160 Go libres (`/storage/6B7B-D8D6`). L'ISO doit encore être copié sur l'Odin.
- SSH : Termux, port 8022, utilisateur `u0_a155`, IP `192.168.129.50` (peut changer), clé `~/.ssh/odin_nba2k14` dans Debian WSL. L'utilisateur doit lancer `sshd` dans Termux.
- Commandes Linux depuis Windows, toujours par un script :

```bash
wsl -d Debian -u viver --exec bash -c "tr -d '\r' < '<chemin>' > /tmp/x-lf.sh; bash /tmp/x-lf.sh < /dev/null"
```

- PC : i7-13700HX, RTX 4070. Il y a aussi un GPU Intel : vérifier que le jeu utilise la RTX.
- **Disque C : seulement 22 Go libres au 01/11.** Le NDK, le SDK et la compilation risquent de ne pas tenir. Faire le point avant de télécharger. Ne rien supprimer soi-même : proposer une liste à l'utilisateur.

## Règles de travail avec l'utilisateur

- Répondre en français simple, étape par étape. L'utilisateur débute en programmation.
- Pour le ressenti et les choix par défaut (images/s, qualité, chaleur), donner les options et attendre un oui.
- Tester sans l'utilisateur dès que c'est possible. Demander ses mains seulement si c'est vraiment nécessaire, et dire ce que le test simulé ne prouve pas.
- Prévenir avant un test qui fait souffler le ventilateur. Vérifier qu'aucun jeu ne tourne avant un test.
- La chaleur et la fluidité comptent beaucoup pour l'utilisateur.
- Ne jamais supprimer ses fichiers personnels soi-même. Ne pas toucher à ses ROMs. Ne pas changer ses réglages Android ou de sécurité.
- Pas de commit sans demande.
- Codex peut prendre le travail de développement répétitif. Claude garde la recherche, l'architecture et les décisions.

**Partage :** cet APK contiendra du code issu du jeu. Il reste strictement privé. Ne jamais publier ni distribuer l'APK, `pc/generated/`, l'ISO ou des fichiers du jeu.

## Sources

- [Dépôt World Cup recompilé](https://github.com/HossEz/fifa-world-cup-2014-recompiled) et [version 0.2.0](https://github.com/HossEz/fifa-world-cup-2014-recompiled/releases/tag/v0.2.0)
- [BUILDING.md](https://raw.githubusercontent.com/HossEz/fifa-world-cup-2014-recompiled/main/BUILDING.md) et [liste des patchs](https://raw.githubusercontent.com/HossEz/fifa-world-cup-2014-recompiled/main/patches/rexglue-sdk/README.md)
- [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk)
- [Skate3-Android](https://github.com/Buku313/Skate3-Android), [MarathonRecomp-Android 0.1.0](https://github.com/SansNope/MarathonRecomp-Android/releases/tag/v0.1.0), [Midnight Club Android](https://github.com/gabrielbskk/mcla-recomp-android-g)

**Voile blanc d'avant-match, 02/11/2026 : corrigé par `depth_float24_convert_in_pixel_shader = true`.** Défaut signalé par l'utilisateur : pendant la présentation du match (plans avec flou de profondeur, bandeau « Brazil v Argentina »), tout l'écran devient blanc-bleu ; le voile disparaît au coup d'envoi. Avec ce réglage, sur le même plan de la présentation (même parcours, script `C:\wc14\scripts\odin-stade.ps1`), l'image est correcte. En match : 59,7 images/s (597 en 10 s), image propre, public présent, CPU 69,5 °C. Le lanceur Android l'ajoute au `fifawc14.toml` s'il manque (`EnsureGameConfig` de `launcher/android/main_android.cpp`). Le lanceur PC ne l'a pas : non testé en Direct3D 12.
Vus pendant ces essais, non corrigés : (1) une fois sur quatre, plantage au démarrage, « Call to invalid or unregistered function at guest address 0x00000000 (called from 0x836CEF78) » ; (2) quand Android recrée la surface du jeu (journal : « Presentation ... dropped as the swapchain or the surface has become outdated », logcat « BufferQueue has been abandoned »), le présentateur ne se raccroche pas : le jeu continue, écran noir. Arrivé deux fois sur quatre pendant mes essais par adb, pas pendant la partie de l'utilisateur.
Pilotage par adb : le lanceur ne reçoit pas les touches adb ; `input tap 235 400` (Play) marche juste après `am start`. `screencap` en PowerShell : passer par un fichier sur l'Odin puis `adb pull` (la redirection de `exec-out` abîme le PNG).
