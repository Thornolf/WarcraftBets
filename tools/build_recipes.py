#!/usr/bin/env python3
"""Generates Data/Recipes.lua from the client tables published by wago.tools.

Usage: python3 tools/build_recipes.py --build 1.60.1.70959

The tables are cached under tools/.cache/<build>/ so a second run is offline.
"""

import argparse
import csv
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLES = [
    "SkillLine",
    "SkillLineAbility",
    "SpellReagents",
    "SpellEffect",
    "SpellName",
    "Item",
    "ItemSparse",
    "ItemEffect",
    "ItemXItemEffect",
]

# SkillLine.CategoryID: 9 is secondary professions, 11 is primary professions.
PROFESSION_CATEGORIES = {"9", "11"}
EFFECT_CREATE_ITEM = "24"
ITEM_TRIGGER_LEARN_SPELL = "6"
# ItemSparse.Bonding: 1 binds on pickup, 4 and 5 are quest items.
UNSELLABLE_BONDING = {"1", "4", "5"}
JUNK_NAME = re.compile(r"\b(OLD|DNT|TEST|DEPRECATED|UNUSED|NYI)\b|^zz")
REAGENT_SLOTS = 8

# The client tables do not say what vendors stock, so this list is kept by hand:
# crafting supplies sold in unlimited quantity. The add-on also records what the
# vendors a player visits actually sell.
VENDOR_ITEMS = [
    159, 1179, 2320, 2321, 2324, 2325, 2593, 2594, 2595, 2596, 2604, 2605, 2678, 2692, 2880, 2894,
    2928, 3371, 3372, 3466, 3713, 3777, 3857, 4289, 4291, 4340, 4341, 4342, 4399, 4400, 4470, 4536,
    5140, 5173, 6217, 6260, 6261, 8343, 8923, 8924, 8925, 10290, 10647, 10648, 11291, 14341, 18256,
    18567,
]


def fetch(build, cache):
    cache.mkdir(parents=True, exist_ok=True)
    for table in TABLES:
        path = cache / f"{table}.csv"
        if path.exists():
            continue
        url = f"https://wago.tools/db2/{table}/csv?build={build}"
        print(f"download {url}", file=sys.stderr)
        request = urllib.request.Request(url, headers={"User-Agent": "recipe-data-builder"})
        with urllib.request.urlopen(request, timeout=300) as response:
            path.write_bytes(response.read())


def read(cache, table):
    csv.field_size_limit(10**9)
    with open(cache / f"{table}.csv", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def recipe_item_requirements(cache, items):
    """Skill needed to learn a recipe, for recipes taught by an item (plans, patterns)."""
    taught = {
        row["ID"]: row["SpellID"]
        for row in read(cache, "ItemEffect")
        if row["TriggerType"] == ITEM_TRIGGER_LEARN_SPELL
    }
    required = {}
    for link in read(cache, "ItemXItemEffect"):
        recipe = taught.get(link["ItemEffectID"])
        item = items.get(link["ItemID"])
        if recipe and item and int(item["RequiredSkillRank"]) > 0:
            rank = int(item["RequiredSkillRank"])
            required[recipe] = min(rank, required.get(recipe, rank))
    return required


def build(cache):
    # ItemSparse only describes part of the items the client knows; Item lists them all.
    items = {row["ID"]: row for row in read(cache, "ItemSparse")}
    item_ids = {row["ID"] for row in read(cache, "Item")}
    names = {row["ID"]: row["Name_lang"] for row in read(cache, "SpellName")}
    reagents = {row["SpellID"]: row for row in read(cache, "SpellReagents")}
    required = recipe_item_requirements(cache, items)

    products = {}
    for effect in read(cache, "SpellEffect"):
        if effect["Effect"] == EFFECT_CREATE_ITEM and effect["EffectItemType"] != "0":
            amount = max(1, round(float(effect["EffectBasePointsF"])))
            products.setdefault(effect["SpellID"], (effect["EffectItemType"], amount))

    professions = {
        row["ID"]: row["DisplayName_lang"]
        for row in read(cache, "SkillLine")
        if row["CategoryID"] in PROFESSION_CATEGORIES
        and row["ParentSkillLineID"] == "0"
        and not JUNK_NAME.search(row["DisplayName_lang"])
    }

    recipes = {}
    skipped = 0
    for ability in read(cache, "SkillLineAbility"):
        spell = ability["Spell"]
        if ability["SkillLine"] not in professions or spell not in reagents or spell in recipes:
            continue
        name = names.get(spell)
        if not name or JUNK_NAME.search(name):
            skipped += 1
            continue
        row = reagents[spell]
        parts = []
        for slot in range(REAGENT_SLOTS):
            item, count = row[f"Reagent_{slot}"], int(row[f"ReagentCount_{slot}"])
            if item != "0" and count > 0:
                parts.append((int(item), count))
        product, amount = products.get(spell, ("0", 1))
        known_items = all(str(item) in item_ids for item, _ in parts)
        if not parts or not known_items or (product != "0" and product not in item_ids):
            skipped += 1
            continue
        learn_at = max(int(ability["MinSkillLineRank"]), required.get(spell, 0))
        recipes[int(spell)] = [
            int(ability["SkillLine"]),
            int(ability["TrivialSkillLineRankLow"]),
            int(ability["TrivialSkillLineRankHigh"]),
            learn_at if learn_at > 1 else 0,
            int(product),
            amount,
        ] + [value for part in parts for value in part]

    used_skills = {recipe[0] for recipe in recipes.values()}
    skills = {int(key): name for key, name in professions.items() if int(key) in used_skills}

    vendor = {}
    for item in VENDOR_ITEMS:
        row = items.get(str(item))
        if not row or int(row["BuyPrice"]) <= 0:
            sys.exit(f"vendor item {item} has no buy price in this build")
        vendor[item] = max(1, int(row["BuyPrice"]) // max(1, int(row["VendorStackCount"])))

    unsellable = sorted(
        {
            recipe[4]
            for recipe in recipes.values()
            if items.get(str(recipe[4]), {}).get("Bonding") in UNSELLABLE_BONDING
        }
    )
    print(f"{len(recipes)} recipes, {skipped} skipped, {len(skills)} professions", file=sys.stderr)
    return skills, recipes, vendor, unsellable


def render(build_name, skills, recipes, vendor, unsellable):
    out = [
        "local _, ns = ...",
        "",
        f"-- Generated by tools/build_recipes.py from client build {build_name}. Do not edit.",
        "-- Recipe: { skill line, yellow at, grey at, learnable at (0 if unknown), product (0 if none),",
        "--           yield, reagent, count, reagent, count, ... }",
        "ns.RecipeData = {",
        f'    build = "{build_name}",',
        "    skills = {",
    ]
    for key in sorted(skills):
        out.append(f'        [{key}] = "{skills[key]}",')
    out += ["    },", "    recipes = {"]
    for spell in sorted(recipes):
        out.append(f"        [{spell}] = {{ {', '.join(str(v) for v in recipes[spell])} }},")
    out += ["    },", "    vendor = {"]
    for item in sorted(vendor):
        out.append(f"        [{item}] = {vendor[item]},")
    out += ["    },", "    unsellable = {"]
    for start in range(0, len(unsellable), 12):
        out.append("        " + ", ".join(str(v) for v in unsellable[start : start + 12]) + ",")
    out += ["    },", "}", ""]
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--build", required=True, help="client build, for example 1.60.1.70959")
    parser.add_argument("--cache", type=pathlib.Path, help="directory holding the table CSV files")
    args = parser.parse_args()
    cache = args.cache or ROOT / "tools" / ".cache" / args.build
    fetch(args.build, cache)
    output = ROOT / "Data" / "Recipes.lua"
    output.write_text(render(args.build, *build(cache)), encoding="utf-8")
    print(f"wrote {output.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
