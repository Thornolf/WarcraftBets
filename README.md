# WarcraftBets

Add-on pour WoW: Forever. Au survol d'un objet, il montre chaque craft qui l'utilise (jusqu'à 3 étapes),
appris ou non, et ce qu'il rapporte à l'hôtel des ventes. Une fenêtre dédiée (`/wsb`) donne le détail.

An add-on for WoW: Forever. Hover an item to see every craft that uses it (up to 3 steps), learned or
not, and what each is worth at the auction house. A dedicated window (`/wsb`) shows the details.

## Installation

1. Copier ce dossier dans `World of Warcraft/_forever_/Interface/AddOns/` sous le nom `WarcraftBets`.
2. Installer TradeSkillMaster ou Auctionator pour les prix (les deux sont facultatifs, l'un des deux est
   nécessaire pour voir des profits).
3. Relancer le jeu ou taper `/reload`.

## Utilisation

- Survoler un objet : les 2 meilleurs crafts s'affichent, 5 en maintenant Maj.
- `/wsb` ou `/wb` : ouvre la fenêtre sur le dernier objet survolé.
- `/wsb <lien ou nom d'objet>` : ouvre la fenêtre sur cet objet.
- `/wsb options` : ouvre les réglages. `/wsb reset` : recentre la fenêtre.

Ouvrir une fois la fenêtre de chaque métier, sur chaque personnage, pour que l'add-on sache quelles
recettes sont apprises.

## Développement

- `make lint test` : luacheck et tests busted (Lua 5.1).
- `make data` : régénère `Data/Recipes.lua` depuis les tables du client publiées par wago.tools.
- `make zip` : crée `dist/WarcraftBets.zip`, prêt à décompresser dans `AddOns`.

La spécification est dans [`docs/spec.md`](docs/spec.md).

## Licence

MIT.
