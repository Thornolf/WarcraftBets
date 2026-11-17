# WarcraftBets : spécification

WarcraftBets montre, au survol d'un objet dans WoW: Forever, chaque craft qui l'utilise (3 étapes
max), appris ou non, et ce qu'il rapporte à l'hôtel des ventes (HV), avec une fenêtre dédiée pour le
détail.

Cible : WoW: Forever 1.60.1, `## Interface: 16001`.

## Périmètre

Ce que fait l'add-on :

- Infobulle enrichie : meilleurs crafts utilisant l'objet survolé, et coût de fabrication de l'objet
  s'il se fabrique.
- Fenêtre dédiée : liste complète, filtrable, et détail d'une recette (composants, craft ou achat,
  profit).
- Toutes les recettes du jeu, apprises ou non, en distinguant le personnage connecté et ses rerolls.
- Prix TSM en priorité, Auctionator en secours.

Ce qu'il ne fait pas en version 1 :

- Pas de liste dédiée aux occasions d'achat-revente.
- Pas d'alerte d'achat-revente sur les objets de marchand.
- Pas de groupe TSM ni d'automatisation des achats : seulement une liste de courses Auctionator.
- Pas de données venues de Wowhead : tout vient des tables du client.

## Décisions

| Sujet | Décision |
| --- | --- |
| Infobulle | 2 meilleurs crafts par défaut, 5 avec Maj, puis « +N autres » |
| Recettes couvertes | Toutes les recettes du jeu, apprises ou non, tous les métiers |
| Prix | TSM d'abord, Auctionator en secours, détection auto, option pour forcer |
| Profit net | Prix HV − commission HV − coût des composants par le chemin le moins cher |
| Classement | Par profit par unité de l'objet survolé ; la fenêtre montre aussi le profit par craft |
| « Appris » | Distinction personnage connecté / rerolls (« Connue de : Nom ») |
| Ordre | Tri par profit seul, filtre appris / non appris |
| Rendu des non apprises | Icône désaturée et nom gris, comme le grimoire |
| Composants de marchand | Coût = le moins cher entre marchand et HV, les deux prix affichés |
| Invendables | Fenêtre : groupe « Non vendables » avec coût seul ; absents de l'infobulle |
| Prix manquant | Recette affichée avec « ? », en fin de classement ; jamais de prix inventé |
| Objet fabriqué survolé | Une ligne « Coût de fabrication » |
| Commande | `/wsb`, alias `/wb` |
| Profondeur | 3 étapes par défaut, réglable de 1 à 5, protection contre les boucles |
| Source des recettes | Script maison à partir des tables du client |
| Commission HV | Réglable de 5 % à 15 %, 5 % par défaut ; dépôt ignoré |
| Prix TSM | `DBMarket` par défaut, n'importe quelle formule TSM acceptée |
| Filtre | Toutes / Apprises (ce perso) / Apprises (un reroll) / Non apprises / Apprenables maintenant |
| Valeur transformée | Ligne pour toute transformation à un seul composant, ramenée à une unité d'origine |
| Liste d'achat | Liste de courses Auctionator ; pas de bouton sans Auctionator |
| Lier dans le chat | Lien de l'objet + « coût X, vente Y, profit Z » |
| Combat | Infobulle masquée en combat ; la fenêtre se ferme à l'entrée en combat |
| Apparence | Modèles de cadre et polices de Blizzard uniquement |
| Langues | Français et anglais |
| Licence | MIT |

## Infobulle

Le bloc WarcraftBets s'ajoute sous les lignes de Blizzard. Il n'affiche rien en combat.

Ordre des lignes (libellé à gauche, prix à droite) :

1. Prix HV de l'objet, avec sa source : « TSM, brut » ou « Auctionator, brut ».
2. Une ligne par transformation à un seul composant (minerai → barre) : « Transformé (Barre de
   cuivre) », valeur ramenée à une unité de l'objet survolé.
3. Si l'objet se fabrique : « Coût de fabrication » par le chemin le moins cher.
4. Titre en jaune : « WarcraftBets : meilleurs crafts ».
5. Les 2 meilleurs crafts (5 avec Maj), classés par profit par unité survolée. Nom en blanc si appris
   par ce personnage, en gris sinon.
6. « +N autres · Maj pour en voir plus », ou avec Maj « +N autres · /wsb pour tout voir ».

Règles :

- Les recettes invendables n'apparaissent pas dans l'infobulle.
- Une recette sans prix connu apparaît avec « ? », après celles qui ont un prix.
- Appuyer ou relâcher Maj pendant le survol rafraîchit l'infobulle.
- Rien n'est ajouté pour un objet sans prix, qui n'entre dans aucune recette et ne se fabrique pas.
- Le calcul est mis en cache par objet et invalidé quand les prix, les réglages ou les recettes
  apprises changent.

## Fenêtre dédiée

Elle s'ouvre par `/wsb`, `/wb`, ou `/wsb <objet>` (lien ou nom).

En-tête : icône et nom de l'objet étudié, prix brut et valeurs transformées, choix de la source de
prix (Auto / TSM / Auctionator).

Panneau gauche, la liste des crafts :

- Champ de recherche sur le nom de l'objet produit.
- Filtre : Toutes / Apprises (ce perso) / Apprises (un reroll) / Non apprises / Apprenables
  maintenant.
- Groupes par étape : « Directement », « Avec <objet intermédiaire> », puis « Non vendables ».
- Chaque ligne : icône, nom (couleur de qualité si apprise, gris et icône désaturée sinon), profit
  par unité en vert ou rouge.

Panneau droit, le détail de la recette sélectionnée :

- Nom, métier, compétence requise, état : « Apprise », « Connue de : Nom » ou « Non apprise ».
- Composants : pour chacun, quantité, coût retenu et origine du coût (HV, marchand ou fabrication) ;
  cliquer un composant ouvre la fenêtre sur lui.
- Rentabilité : prix de vente HV, commission, coût, profit net par craft et par unité.
- Source des prix.
- Boutons « Lier dans le chat » et « Liste d'achat » (ce dernier seulement si Auctionator est
  chargé).

Comportement :

- Déplaçable partout ; pendant le glisser, voile et bordure verts.
- Position mémorisée par compte, ramenée à l'écran si elle en sort.
- Échap ferme la fenêtre.
- La fenêtre se ferme à l'entrée en combat et ne s'ouvre pas pendant un combat.

## Moteur de calcul

Le moteur est du Lua pur, sans appel à l'API du jeu, testé hors du jeu avec busted.

- Coût d'un objet : le moins cher entre son prix HV, son prix marchand et sa fabrication (somme des
  coûts de ses composants divisée par le rendement), récursivement.
- Profit net d'une recette : rendement × prix HV du produit × (1 − commission) − somme des coûts des
  composants.
- Profit par unité survolée : profit de la recette divisé par le nombre d'unités de l'objet survolé
  qu'elle consomme sur toute la chaîne. C'est le critère de tri.
- Profondeur : on suit l'objet survolé sur 3 étapes par défaut (1 à 5). Le coût de fabrication d'un
  composant s'arrête à la même profondeur.
- Boucles : un objet déjà sur le chemin en cours n'est pas redéveloppé ; on prend son prix d'achat.
- Prix manquant : si le produit ou un composant sans alternative n'a pas de prix, le profit est
  inconnu et la recette passe après celles qui ont un prix.
- Invendable (lié quand ramassé, enchantement) : coût seul, sans profit.
- Montants en pièces de cuivre, arrondis à l'affichage seulement.

Exemple : une ceinture vendue 1 po 20 pa, commission 6 pa, 6 barres fondues à partir de 6 minerais à
6 pa, soit 36 pa. Profit net +78 pa par craft, soit +13 pa par minerai.

## Données

Base de recettes : `tools/build_recipes.py` lit les tables du client (SkillLine, SkillLineAbility,
SpellReagents, SpellEffect, ItemSparse) publiées par wago.tools et génère `Data/Recipes.lua`. Aucun
nom n'est stocké : ils viennent du client, dans sa langue. Les tables du client ne disent pas quels
objets les marchands vendent : une courte liste est tenue à la main dans le script, et l'add-on la
complète en jeu avec ce que vendent les marchands visités.

Recettes apprises : relevées à la connexion et à l'ouverture d'une fenêtre de métier, stockées par
personnage dans les variables sauvegardées du compte. Un reroll n'est connu qu'après s'être connecté
une fois avec l'add-on.

Prix : `TSM_API.GetCustomPriceValue(formule, "i:<id>")` et
`Auctionator.API.v1.GetAuctionPriceByItemID("WarcraftBets", id)`. En mode Auto, TSM s'il renvoie un
prix, sinon Auctionator.

## Réglages et commandes

| Réglage | Valeurs | Défaut |
| --- | --- | --- |
| Source de prix | Auto / TSM / Auctionator | Auto |
| Formule TSM | Texte libre | `DBMarket` |
| Commission HV | 5 % à 15 % | 5 % |
| Profondeur des chaînes | 1 à 5 | 3 |
| Crafts dans l'infobulle | Par défaut / avec Maj | 2 / 5 |
| Infobulle activée | Oui / non | Oui |

- `/wsb` ou `/wb` : ouvre ou ferme la fenêtre.
- `/wsb <lien ou nom d'objet>` : ouvre la fenêtre sur cet objet.
- `/wsb options` : ouvre les réglages.
- `/wsb reset` : remet la fenêtre au centre de l'écran.

## Architecture

Seul le moteur fait les calculs ; l'infobulle et la fenêtre affichent ce qu'il renvoie.

| Fichier | Rôle |
| --- | --- |
| `Core.lua` | Chargement, événements, commandes, réglages par défaut |
| `Locales/` | Textes français et anglais |
| `Data/Recipes.lua` | Base de recettes générée |
| `Compat.lua` | Accès à l'API du jeu, quelle que soit sa génération |
| `Prices.lua` | TSM, Auctionator, marchand |
| `Learned.lua` | Recettes apprises par personnage |
| `Engine.lua` | Coût le moins cher, profit, chaînes |
| `View.lua` | Lignes de l'infobulle et de la liste, sans cadre |
| `Tooltip.lua` | Accroche de l'infobulle |
| `UI/Window.lua` | Fenêtre à deux panneaux |
| `UI/Settings.lua` | Panneau de réglages |
| `tools/` | Script de génération des recettes |
| `spec/` | Tests busted |
