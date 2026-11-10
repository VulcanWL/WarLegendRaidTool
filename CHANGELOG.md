# Nouveautés

Ce qui change pour les joueurs à chaque version de WaR LegenD RaidTool. Les notes de chaque
[Release](https://github.com/VulcanWL/WarLegendRaidTool/releases) viennent de ce fichier ; avant la 1.41.4, voir les notes des
Releases et les tags git.

## Prochaine version

## 1.41.63 (10/11/2026)

### Corrigé
- Myslot : à l'import, une macro créée ne décale plus les macros déjà présentes vers les mauvais emplacements des barres
  ni vers les mauvais raccourcis de clic.
- Guilde > Métiers : un nom de métier reçu d'un membre qui se lit comme un nombre (« -1e999 ») n'est plus enregistré comme
  un nombre infini dans les données sauvegardées.
- Maj-clic sur un objet : le lien va de nouveau dans la zone de texte de l'addon qui a le curseur (recherche de recette,
  Loot Council...), et un lien de métier maj-cliqué est de nouveau enregistré dans Guilde > Métiers.
- Messages de l'addon retenus pendant un long combat de boss : ceux qui attendaient derrière le premier ne sont plus perdus
  à la fin du combat (un long texte partagé arrivait incomplet).
- Profils (Options > Profil) : une liste ou un texte invalide d'un profil collé n'est plus gardé (liste de consommables,
  rangs, noms, modules coupés, texte avec un code d'icône ou trop long) ; avant, une liste de consommables mal formée
  donnait une erreur à chaque appel de raid, d'une session à l'autre.
- Niveaux d'objet : affichés aussi sur les emplacements de la banque.
- Cadres de champ de bataille : coupés pendant un combat, ils disparaissent bien à la fin du combat.
- Cadres de champ de bataille : après un passage par le mode test, les contrôles, les buffs manquants et l'indicateur de
  combat s'affichent de nouveau sur tous les joueurs sans `/reload`.
- Cadres de champ de bataille : la barre de vie d'un allié prend la couleur du type de débuff que tu peux dissiper.
- Loot Council : après un vote, la fenêtre affiche tout de suite les candidats de l'objet suivant (un deuxième clic rapide
  votait pour un joueur de l'objet précédent sans le montrer).
- Cooldowns de raid : en rejoignant un groupe avec la fenêtre affichée, l'addon demande aussitôt leurs cooldowns aux
  autres (ils restaient en « Nom? » jusqu'à ce que quelqu'un d'autre demande).
- Inspection du raid : ton inspection d'un joueur n'est plus annulée par celles de l'onglet pendant qu'elle charge.
- Recrues : choisir un autre rang de recrue puis revenir au bon ne remet plus toutes les dates « recrue depuis » à
  aujourd'hui.
- Stats de BG : une partie n'est plus enregistrée deux fois après un `/reload` ou une reconnexion sur l'écran des scores.
- Alerte de danger : cocher une option ne vide plus l'alerte et les cadres ennemis tant que les ennemis sont à l'écran.
- Skyborne : un nœud vu sur la minicarte n'est plus renvoyé à chaque passage quand la liste de la carte est pleine.
- DoesItDie : après avoir coupé puis rallumé le module, les listes déroulantes de son onglet s'ouvrent de nouveau.

## 1.41.62 (10/11/2026)

### Ajouté
- Layers : bouton « Demander aux hôtes LayerSwap » (WoW Forever). Un clic cherche les joueurs de ta zone (la recherche
  /who du jeu s'ouvre avec leur liste) puis leur envoie en privé la demande de l'addon LayerSwap, avec ta position sur la
  carte comme LayerSwap (40 joueurs au plus, 8 d'un coup puis un par seconde, une recherche toutes les 30 s ; dans une zone
  peuplée, chaque recherche suivante couvre une classe ; les hôtes qui ont déjà répondu passent en premier). Un utilisateur
  de LayerSwap d'un autre layer de ta zone qui héberge t'invite. À côté du bouton : combien d'utilisateurs de LayerSwap
  ont reçu la demande et combien hébergent sur un autre layer ; l'invitation d'un hôte de ton propre layer est signalée.
  Tu acceptes toi-même, puis tu valides l'avis du jeu (ou « Changer de layer maintenant ») et tu restes dans le groupe.
  Si aucun changement n'est annoncé 15 s après avoir rejoint, un bouton « Quitter ce groupe » apparaît (jamais pendant le
  compte à rebours). Rien ne part tout seul, rien n'est accepté à ta place ; hors groupe et avec ton layer connu.

### Corrigé
- Layers : « Inviter sur mon layer » explique l'étape qui manquait. Depuis le lancement, rejoindre un groupe ne change pas
  de layer tout de suite : le jeu affiche un avis avec un compte à rebours (environ 5 min) et il faut le valider (Refresh
  Now) ou attendre. Le chuchotement d'invitation, le chat et l'onglet le disent, et l'onglet a un bouton « Changer de
  layer maintenant » (le même que celui du jeu, hors combat) pendant le compte à rebours, même quand le changement était
  déjà prévu avant un `/reload` ou un écran de chargement (comme l'avis du jeu depuis la build 70840).

## 1.41.61 (06/11/2026)

### Corrigé
- Cadres de champ de bataille : plus d'erreur Lua quand les cadres s'affichent avant que tous les joueurs soient placés.
- Layers (`/wl layer`) : le numéro affiché est celui du jeu pour le layer, le même pour toute la guilde (et dans les autres
  addons de layers), au lieu d'un numéro donné par ton ordinateur qui grimpait sans fin (« Layer 70 »). Un changement de
  layer annoncé par le jeu relance la détection, et le compte à rebours du jeu s'affiche dans l'onglet.

## 1.41.60 (04/11/2026)

### Corrigé
- DoesItDie : les DoT ne disparaissent plus au bout de quelques secondes depuis que le jeu cache les dégâts des ticks
  (build 70755 de Forever) ; les ticks sont reconnus à leur rythme, mais leur taille n'est plus apprise (estimation par la
  description du sort).

## 1.41.59 (03/11/2026)

### Corrigé
- Alerte de CC : s'affiche encore quand le jeu cache les données de contrôle (build 70707 de Forever : icône, nom et
  durée tels que le jeu les donne, une seule couleur ; « Aussi les immobilisations » sans effet dans ce cas).

### Modifié
- Raid Buffs et cadres de champ de bataille : Salut et Bénédiction de lumière retirés (supprimés du jeu par Blizzard le 3/11).
- Rappel des talents : la fenêtre montre maintenant tes 3 arbres comme la fenêtre de talents du jeu (icônes à leur place,
  rang pris / max, prérequis, points par arbre, description du sort au survol).

## 1.41.58 (02/11/2026)

### Ajouté
- Réglages > Modules : quand un module coché ou décoché a besoin d'un /reload pour prendre tout son effet, une ligne orange et le bouton Recharger apparaissent ; la page « L'activer » d'un module éteint le propose aussi.
- Guilde > Membres > Leveling (`/wl lvl`) : les membres de la guilde en ligne proches de ton niveau (zone, layer, qui cherche
  un groupe, qui est déjà groupé), boutons Inviter et Chuchoter. Coche « Je cherche un groupe de leveling » pour le dire à
  la guilde (un message d'addon par minute au plus, rien hors de la guilde) ; une ligne dans ton chat quand un membre
  proche de ton niveau cherche un groupe.

### Modifié
- La librairie de portée des cadres de champ de bataille (LibRangeCheck) ne se charge plus qu'avec eux : rien à la
  connexion ni en raid pour qui ne fait pas de champ de bataille.

### Corrigé
- Scintillements du butin et Texte de recharge : désactiver le module dans Réglages > Modules remet tout de suite les réglages du jeu (plus besoin de /reload), et la valeur remise est celle que le jeu avait depuis (un préréglage graphique changé entre-temps), pas celle du tout premier lancement.
- Cadres de champ de bataille : après un /reload pendant un champ de bataille, les cadres de raid de Blizzard restaient cachés à la sortie ; désactiver le module les rend aussi.
- Cadres de champ de bataille : la barre d'incantation d'un allié ne cache plus ses debuffs (sous son cadre à 5 joueurs
  ou moins ; au-delà, si elle est cochée, après ses debuffs et plus petite).
- Cadres de champ de bataille : les symboles de dissipation d'un allié restent sur la ligne de son nom à 5 joueurs ou
  moins (ils ne cachent plus sa vie), et ne mordent plus sur le nom quand l'interface ou les cadres sont agrandis.
- Cadres de champ de bataille : le nom du porteur du drapeau s'arrête avant l'icône du drapeau.
- Cadres de champ de bataille : les icônes des debuffs, de tes buffs et des contrôles suivent la taille des cadres quand
  le nombre de joueurs change (elles gardaient celle du début de partie et débordaient sur les lignes voisines).
- Cadres de champ de bataille : la portée de secours (quand le jeu ne répond pas) est mise à jour pour WoW Forever
  (LibRangeCheck 38 : sorts de Forever, plus d'ancienne fonction appelée à son chargement).

## 1.41.57 (30/10/2026)

### Modifié
- Les données sauvegardées par d'anciennes versions ne sont plus reprises : anciens réglages de Myslot et de DoesItDie,
  anciens relevés de présences et de métiers, presets de l'addon RaidPresets. Seules les données de la version actuelle
  sont lues.

## 1.41.56 (30/10/2026)

### Modifié
- DoesItDie allumé coûte bien moins en raid : il ignore les coups reçus par les membres du groupe, ne lit plus que les
  barres de nom des mobs qui portent tes DoT, et son journal de suivi ne note plus les coups des autres joueurs (seulement
  avec `/wl did debug`).
- Cadres de champ de bataille plus légers : à l'entrée en BG (les cadres se préparent sur quelques images au lieu d'une
  seule), en combat et quand le raid change. Le tableau des scores est relu toutes les 6 s quand rien ne change, et un buff
  manquant peut s'afficher jusqu'à 1 s plus tard.
- Métiers de la guilde : apprendre plusieurs recettes d'un coup n'envoie ta liste à la guilde qu'une fois, une minute plus
  tard.
- Myslot : à la fin d'un import, une seule ligne de chat compte ce qui est laissé de côté (sorts inconnus, objets
  introuvables, macros), au lieu d'une ligne par entrée.
- Myslot : les profils enregistrés sont limités à 4 Mo en tout (un vrai profil fait de 5 à 70 Ko) ; au-delà, Enregistrer
  demande d'en supprimer un.
- Loot Council : la fenêtre de vote (votes, votants, notes) est réservée au conseil et au maître du butin. Les autres
  raiders répondent toujours dans leur fenêtre de butin.
- Consommables : une vérification de raid n'est répondue qu'à un chef ou assistant de ta guilde, par chuchotement, jusqu'à
  100 d'un objet : le raid ne lit plus tes sacs.
- Préparation des raiders : une seule ligne par objet est répondue par vérification : plus de compte exact en une demande.
- Une liste de consommables ou un preset partagé donne le nom complet de l'expéditeur et dit s'il n'est pas de ta guilde ;
  nom complet aussi dans la fenêtre des buffs et les lignes de préparation.
- Raid Buffs : une fenêtre de buffs toutes les 10 s au plus (une liste corrigée juste après arrive à la fin des 10 s).

### Corrigé
- DoesItDie, en groupe : un DoT esquivé ou résisté juste avant le départ du sort n'est plus compté. Un coup reçu au même
  moment par un autre joueur ou un autre mob effaçait l'esquive, et l'icône de mort pouvait s'afficher pour un DoT absent.
- Myslot : un texte collé impossible (plus d'entrées qu'un vrai profil) est refusé ; une entrée invalide (emplacement qui
  n'existe pas, macro trop longue) est ignorée, et l'import ne s'arrête plus à moitié.
- Myslot : le nom d'une macro collée ne peut plus afficher une image ou un code sur les barres d'action.
- Myslot : l'export et l'import ne s'arrêtent plus si le jeu n'a pas l'un des textes de l'en-tête de l'export (joueur,
  classe, talents, niveau).
- Le chef de hasard d'un champ de bataille ne peut plus ouvrir de fenêtres de butin ou de vote ni de questions chez toi, et
  les outils de raid ne prennent plus rien du canal de guilde (un seul message y chargeait les outils de raid chez toute la
  guilde).
- Une question envoyée par un autre joueur : son Oui ne répond qu'après 0,5 s. Un double clic sur ton propre Oui, ou un clic
  au moment où elle arrive, ne l'accepte plus sans la lire.
- Un message compressé truqué (des centaines de blocs vides) est refusé dès sa lecture, avant de coûter quoi que ce soit.
- Invitation par mot-clé et réponses `!sr` : 201 expéditeurs d'affilée ne remettent plus leurs limites à zéro.
- Skyborne : seuls les messages de son canal sont lus, 2 000 signalements gardés en tout (un inconnu pouvait en faire garder
  et sauvegarder 16 000), et le mode debug n'affiche plus les codes d'un inconnu.

## 1.41.55 (29/10/2026)

### Modifié
- DoesItDie devient un vrai module de l'addon : son onglet à lui (Raid > Combat > DoesItDie) avec un aperçu en direct
  et ses réglages en sous-onglets (en français), plus de fenêtre à part. L'allumer ou l'éteindre prend effet tout de
  suite, sans `/reload`, et il ne coûte plus rien quand aucun DoT n'est suivi. Tes réglages et les tailles de tick
  apprises sont repris.
- DoesItDie lit les sorts en anglais et en français seulement ; les chemins de cadres à taper (onglet Avancé) sont
  retirés : cadres de Blizzard ou d'EllesmereUI.
- Myslot devient un vrai module de l'addon : son onglet (Options > Petits automatismes > Myslot, en français) avec
  Profil, Profils enregistrés, Parties et Supprimer, plus de fenêtre à part ni de bouton de minicarte. Même format
  d'export : les textes de Myslot s'importent toujours, dans les deux sens. Tes exports et réglages sont repris.
- Myslot : l'import se fait en entier dans le clic de la confirmation (plus de barre de progression), refusé en combat ;
  les liens de partage dans le chat sont retirés (copier-coller seulement).

## 1.41.54 (29/10/2026)

### Modifié
- Annonces en liste (Raid Buffs, soft-res) : ton clic envoie 3 lignes, puis une confirmation envoie les 3 suivantes (plus
  aucune ligne envoyée toute seule).
- Groupes de raid : TOUT APPLIQUER déplace un joueur, puis « Déplacement suivant » demande ton clic pour chaque joueur
  suivant (le jeu n'accepte ces déplacements que sur un clic).
- Invitations en masse : quand le premier joueur rejoint, une question te demande de passer le groupe en raid.
- Loot Council : la ligne « Butin : objet -> gagnant » part de ton clic d'attribution.
- Qui a pull : pas d'annonce dans le canal raid sur WoW Forever (le jeu verrouille le chat au pull) ; le nom s'affiche
  pour toi.
- Petits automatismes : une quête partagée par un joueur attend ton clic (seules celles d'un PNJ sont acceptées).
- Promotion automatique : « promu assistant » n'est dit que si le jeu l'a fait ; après 2 refus, un message te dit de le
  faire à la main.

### Corrigé
- Loot Council : une session de test laissée ouverte par un assistant ne bloque plus le maître du butin pendant 10 minutes ;
  le maître du butin (sinon le chef) remplace toujours une session ouverte, et un assistant ne peut plus retirer un raider
  des sessions en le chuchotant.
- Invitations « guilde seulement » et acceptation automatique : un inconnu qui a le même prénom qu'un membre de la guilde
  n'est plus pris pour lui.
- Import d'un profil : les positions, tailles, échelles, couleurs et listes sont vérifiées (un profil abîmé faisait des
  erreurs à chaque connexion ou couvrait l'écran de cadres de champ de bataille) ; la confirmation dit aussi les modules
  rallumés, les partages avec la guilde et le conseil du butin changés ; tes options d'interface gardées.
- Myslot : la confirmation d'import liste toutes les commandes suspectes de chaque macro (pas seulement la première) ; un
  import qui rencontre un combat attend la fin du combat.
- Cadres de champ de bataille : un allié parti en combat ne prend plus la vie et la cible d'un autre ; après un changement
  de réglage, les barres de vie et les marques de raid sont relues (plus de barre pleine sur un allié mort).
- Temps de recharge du raid : pendant un boss, les sorts prêts ne disparaissent plus de la fenêtre des autres joueurs.
- Historique des champs de bataille : la durée d'une partie est lue même sans l'aura de préparation.
- Améliorations dans les sacs : une arme à deux mains n'est plus proposée si elle est moins bonne que ton bouclier ou ta
  main gauche.
- Invitations en masse : quand le groupe ne peut pas passer en raid, les invitations s'arrêtent avec un message (avant :
  bloquées sans fin).
- Préparation : l'aide de la syntaxe s'affiche sur une seule ligne.

## 1.41.53 (29/10/2026)

### Corrigé
- WoW Forever n'a plus les anciennes fonctions des sorts connus : les temps de recharge du raid montrent enfin tes propres
  sorts, et les cadres de champ de bataille ne comptent que les sorts que tu as appris (portée, dissipations, buffs).
- Minuteur de combat : un minuteur de boss ne s'arrête plus quand tu sors un instant du combat pendant la rencontre.
- Minuteurs de capture : l'icône du point (ferme, mine...) s'affiche sur la barre.

## 1.41.52 (29/10/2026)

### Corrigé
- Groupes de raid : un preset collé ou partagé abîmé (des milliers de virgules, un nom de joueur immense) ne fait plus d'erreur
  Lua, et un tel nom n'est plus enregistré.
- Groupes de raid et soft-res : coller un texte plein d'espaces ne fige plus le jeu.
- Temps de recharge du raid : en combat, une réponse ne dit plus « prêt » pour un sort encore en recharge (le jeu cache ces
  temps pendant un combat).
- Réparation par la banque de guilde : quand la guilde ne couvre pas tout, elle paie sa part et toi le reste (avant : tu payais
  tout, ou rien n'était réparé).
- Montants en or affichés avec les pièces (tri du butin, objectif d'or, réparation).
- Carte : Ctrl + clic laisse le jeu poser et retirer son repère (l'option de WarLegend remettait aussitôt un repère retiré).
- Avec EllesmereUI : la vente de camelote et la réparation de WarLegend ne s'éteignent plus quand le module Qualité de vie
  d'EllesmereUI est désactivé.

### Modifié
- Avec EllesmereUI : butin rapide, mot de suppression, coordonnées de la carte et déplacement des fenêtres ne sont plus faits
  en double quand EllesmereUI les fait.
- Déplacer les fenêtres : aussi talents et grimoire, écurie, Héritage et la fenêtre sociale de WoW Forever.

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
