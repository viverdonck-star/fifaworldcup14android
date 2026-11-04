# Journal des versions — World Cup 14 (Android)

## 0.3 — 04/11/2026

**Réglages recommandés par défaut** (nouvelle installation, ou réglage jamais touché ; les
40 FPS sont aussi appliqués une fois à ceux qui viennent de la 0.2) :
40 FPS, 720p, FSR désactivé, filtrage 16x, profondeur exacte activée, pilote de l'appareil,
cinématiques à 30 FPS. Chaque réglage du lanceur dit maintenant lequel est recommandé et ce
qu'on risque en le changeant.

**Nouveautés**
- Cinématiques à 30 FPS (au choix) : plus régulières, appareil plus frais.
- Mode 40 FPS partout : CPU environ 8 °C et GPU environ 8 °C plus frais en match (mesuré sur l'Odin 3).
- Pilote graphique au choix : celui de l'appareil, Turnip (intégré), ou **n'importe quel pilote
  importé** (.zip AdrenoTools ou .so ; vérifié 64 bits ARM avant d'être accepté). Bouton pour
  retirer les pilotes importés.
- Données : **exporter / importer les sauvegardes** (zip ; les anciennes sont mises de côté
  dans `saves-before-import-<date>`), **partager les journaux** (zip via le menu Partager d'Android).
- Écran d'ISO : la région et la version du jeu trouvé sont affichées (EU / US / autre édition),
  et un message clair dit pourquoi un fichier est refusé (fichier compressé, pas un disque Xbox 360,
  illisible depuis cet emplacement).
- Message clair au lancement sur un appareil incompatible (au lieu d'une fermeture sans rien dire).
- Crédits : libadrenotools et Turnip (Mesa) ajoutés.

**Corrections**
- Commentateurs muets en match : le son est maintenant toujours mélangé en stéréo sur Android
  (la voie centrale, celle des commentaires, se perdait).
- ISO refusée chez certains joueurs : le fichier choisi est maintenant lu directement depuis le
  descripteur que donne Android, sans être rouvert.
- Voile blanc avant le coup d'envoi supprimé, avec environ 25 → 31 FPS dans la présentation du match.
- Textures vidéo (YUV) : table de chargement corrigée.

## 0.2

- Lanceur Android complet (menu du jeu, réglages, contrôles), jeu à 60 FPS en match avec le public.
