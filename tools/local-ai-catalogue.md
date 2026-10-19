Bugs déjà rencontrés dans ce projet (à vérifier en priorité) :
1. Fonction "local" utilisée plus haut que sa déclaration : à l'endroit de l'appel c'est une globale nil
   ("attempt to call global 'X' (a nil value)"). Corriger en déplaçant la déclaration au-dessus des fonctions qui l'appellent.
2. Valeurs secrètes (ce client WoW) : UnitPower, UnitPowerMax, GetRaidTargetIndex, IsVisible, GetWidth, les auras... peuvent
   renvoyer une valeur secrète. Une valeur secrète ne peut être ni testée (if v, v and, not v), ni comparée (==, ~=, <),
   ni servir d'index de table : erreur. Toujours tester issecretvalue(v) / issecret(v) EN PREMIER, avant tout autre test ;
   pour savoir si elle est nil : type(v) == "nil".
3. Une erreur avalée (SafeCall, pcall) donne un symptôme "figé, sans erreur" : chercher une opération qui lève une erreur
   au début de la fonction de mise à jour.
4. La liste de guilde de Classic peut ne contenir que les membres connectés : un membre absent de la liste n'a pas forcément
   quitté la guilde.
5. Chaque fonctionnalité doit tester SA propre option (db.queue, db.flag...), pas celle d'une autre (db.enabled).
6. Un état perdu puis retrouvé (mort puis résurrection, caché puis montré) a besoin d'un traitement de l'événement de retour
   (UnitRevived...), pas seulement de l'événement de perte.
Méthode : relie le symptôme à la ligne exacte qui le produit, puis vérifie pour chaque valeur venant du jeu (API, événement) :
peut-elle être nil, secrète, ou appartenir à une autre unité / un autre joueur ? L'ordre de chargement et de déclaration
est-il bon ?
