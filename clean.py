import re

with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

before_len = len(src)

# ============================================================
# البصمات المعروفة — string-by-string replacement
# ============================================================
REPLACEMENTS = [
    # Header / intro
    ("DeX Explorer is a revival of Moon's and Chillz's Dex, made to fulfill Moon's Dex prophecy.",
     "DEX V FLOXIN · built on the shoulders of legends, reborn as our own."),
    ("Developed by Fusion.",
     "Built by FLAUX · for FLOXIN."),
    ("Developed by Fusion",
     "Built by FLAUX · for FLOXIN"),
    ("Fusion (DeX)",
     "FLAUX (DEX V FLOXIN)"),
    ("Chillz (Dex++)",
     "Legacy Author 1"),
    ("Moon (Dex)",
     "Legacy Author 2"),
    ("DeX Explorer",
     "DEX V FLOXIN"),
    ("Dex Explorer",
     "DEX V FLOXIN"),
    ("DEX Explorer",
     "DEX V FLOXIN"),

    # GitRepoName — no longer used for fetching (modules embedded) but clean it
    ('Main.GitRepoName = "FusionWTF/Dex-Explorer"',
     'Main.GitRepoName = "FL0XIN/FLOXIN-DEX-ROBLOX"'),

    # Discord tags
    ("King.Kevin#6025",
     "FLAUX"),
    ("thanks King.Kevin",
     "thanks FLAUX"),
    ("by lovrewe",
     "by FLAUX"),
    ("the old dex",
     "the original tool"),
    ("old dex",
     "original tool"),
    ("the original Dex",
     "the original tool"),

    # Additional refs
    ("DeX being used on your skidsploit",
     "DEX V FLOXIN in use"),
    ("Zinnia, Chillz , Fusion and the Secret Service does not approve",
     "FLAUX does not approve"),
    ("Zinnia, Chillz, Fusion",
     "FLAUX"),
    ("Zinnia",
     "FLAUX"),
    ("Fusion",
     "FLAUX"),
    ("Chillz",
     "LegacyAuthor"),
    ("Chillz's",
     "LegacyAuthor's"),
    ("Moon's",
     "LegacyAuthor's"),
    ("Moon",
     "LegacyAuthor"),

    # Title texts
    ('Text="Ultimate Debugging Suite"',
     'Text="FLOXIN Edition"'),
    ('Text="DeX"',
     'Text="FLOXIN"'),
    ('Text = "DeX"',
     'Text = "FLOXIN"'),
]

count = 0
for old, new in REPLACEMENTS:
    if old in src:
        occurrences = src.count(old)
        src = src.replace(old, new)
        count += occurrences
        print("  [{}x] {} -> {}".format(occurrences, old[:50], new[:50]))

print()
print("Total replacements:", count)
print("Size before:", before_len)
print("Size after :", len(src))

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)

print("SUCCESS - cleaned source saved")
