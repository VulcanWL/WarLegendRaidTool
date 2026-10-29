# Nouveautés

Ce qui change pour les joueurs à chaque version de WaR LegenD RaidTool. Les notes de chaque
[Release](https://github.com/VulcanWL/WarLegendRaidTool/releases) viennent de ce fichier ; avant la 1.41.4, voir les notes des
Releases et les tags git.

## Prochaine version

## 1.41.51 (28/10/2026)

### Modifié
- Sécurité : tout message reçu d'un autre joueur est borné avant d'être lu. Un message piégé pouvait figer le jeu de tout le
  raid (Préparation des raiders) ou de toute la guilde (Métiers).
- Champs de bataille : cadres JcJ beaucoup plus légers à l'entrée en BG, en combat et quand le raid change.
- Soft-res par chuchotement (`!sr`) décoché par défaut ; il reste allumé chez qui a déjà une liste.
- Métiers de la guilde : les réponses à « Demander à la guilde » arrivent en chuchotement, une à la fois.
- Invitations par mot-clé : seulement si tu peux inviter, une fois par 30 s par joueur ; passage en raid automatique pour un
  membre de la guilde seulement.
- Promotion auto : rien sans nom ni rang choisi, ni en champ de bataille.
- Liste de summon : les noms sont annoncés en une seule ligne.
- Import de profil : seules les options du jeu d'Options > Interface sont reprises, une position ou une taille absurde est
  ignorée, et la confirmation signale le mot-clé d'invitation, les modules éteints et les macros PvP sensibles.
- Myslot : `/myslot load` met le profil dans la fenêtre (Importer pour confirmer) ; la confirmation liste chaque macro qui
  fait autre chose que cibler ou lancer un sort ; `/myslot clear` demande confirmation.
- Skyborne : rien n'est lu du canal en instance ni en combat ; une position entendue n'est retenue qu'après 2 joueurs et
  oubliée après 30 jours ; `/wl sk share forget` oublie celles apprises des autres.
- Checklist : un raider ne répond que jusqu'à la quantité demandée.
- Les outils de raid ne se chargent plus en plein combat : une commande qui en a besoin dit de réessayer après le combat.

### Corrigé
- `/wl bugs` ne marchait plus dès la première vraie erreur Lua.
- Loot Council : un objet déjà donné ne peut plus être donné ni dû une 2e fois ; l'échange se fait avec le bon joueur ; une
  confirmation prévient avant une session lancée par-dessus une autre.
- Le rappel de recrutement ne remplace plus une question ouverte (celle du Loot Council, par exemple).
- Raid Buffs et soft-res : une longue annonce part en plusieurs lignes, une par seconde.
- Après un `/reload`, une ligne tapée dans un canal numéroté (`/5 bonjour`) pouvait partir sur le canal de Skyborne.
- Groupes de raid : le placement s'arrête si tu ne peux plus mener ; glisser un joueur pendant un changement du groupe est
  sans effet (avant : erreur ou mauvais joueur retiré).
- Cadres de champ de bataille : alliés tenus à jour quand le raid change en combat.
- Améliorations dans les sacs (niveau d'objet) : plus d'arme à une main proposée quand tu portes une deux-mains.
- DoesItDie : Échap annule le choix d'un cadre.

## 1.41.5 (27/10/2026)

### Modifié
- Fenêtre plus sobre : un tableau vide le dit en une phrase grise, plus de rayures, nombres alignés à droite, menu et
  en-tête sans dégradé ni majuscules forcées, légendes du menu en gris.
- Couleurs gardées pour l'essentiel : en Préparation des raiders seul le « X » reste rouge ; stock complet de la checklist et
  défaites de l'historique des BG en gris.
- Consignes de clic passées dans les infobulles (Layers, verrou du chrono de cimetière, rang des recrues).

### Corrigé
- Appel et talents : le texte du ready check ne déborde plus sur le rappel des talents en français.

## 1.41.4 (27/10/2026)

### Modifié
- Un clic sur un onglet du haut rouvre le dernier outil vu dans cet onglet.
- Myslot : la confirmation d'import liste les macros `/run`, `/script`, `/dump` et les raccourcis qui cliquent un bouton ou
  lancent une macro.

### Corrigé
- Loot Council : le délai de réponse est tenu même si la fenêtre de choix est fermée.
- Métiers de la guilde : un nom de métier reçu ne peut plus contenir de faux liens.
- Déplacer les fenêtres : la molette revient au jeu quand l'option des fenêtres est décochée.
- Menu : l'entrée sélectionnée garde son texte blanc après avoir allumé / éteint son module ; le texte des onglets du haut
  rapetisse s'il dépasse ; la fenêtre revient dans l'écran si sa taille sauvée le dépasse.
- Skyborne : messages limités par joueur, carte redessinée moins souvent.
