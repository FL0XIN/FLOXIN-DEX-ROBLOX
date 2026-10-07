with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

REPLACEMENTS = [
    # 1. DumpFunctions header
    ('-- // Function Dumper made by King.Kevin',
     '-- // Function Dumper by FLAUX'),

    # 2. IncompatibleTest message
    ('Hello Skidsploit user,\\nFLAUX does not approve of Dex being used on your skidsploit.\\nPlease consider getting something better.',
     'Hello,\\nDEX V FLOXIN is protected.\\nUnauthorized use detected.'),

    # 3. Commented Secret Service Panel
    ('--Main.CreateApp({Name = "Secret Service Panel", IconMap = Main.LargeIcons, Icon = "Output", Window = SecretServicePanel.Window})',
     '--Main.CreateApp({Name = "Tools Panel", IconMap = Main.LargeIcons, Icon = "Output", Window = SecretServicePanel.Window})'),

    # Additional cleanup
    ('SecretServicePanel',
     'ToolsPanel'),

    # Header comment at top of file
    ('FLOXIN Explorer\n\tVersion 1.0',
     'DEX V FLOXIN\n\tProtected Build'),
    ('FLOXIN Explorer is a revival',
     'DEX V FLOXIN is a revival'),
    ('FLOXIN Explorer',
     'DEX V FLOXIN'),

    # Dex → DEX V FLOXIN in remaining spots
    ('DeX being used',
     'DEX V FLOXIN being used'),
    ('DeX',
     'DEX V FLOXIN'),
    ('Dex-Explorer',
     'FLOXIN-DEX-ROBLOX'),
    ('Dex Explorer',
     'DEX V FLOXIN'),

    # FusionWTF anywhere else
    ('FusionWTF',
     'FLOXIN'),

    # Skidsploit fallback
    ('Skidsploit',
     'Unknown'),
    ('skidsploit',
     'executor'),

    # Remaining King.Kevin
    ('King.Kevin',
     'FLAUX'),

    # lovrewe anywhere
    ('lovrewe',
     'FLAUX'),
]

count = 0
for old, new in REPLACEMENTS:
    if old in src:
        n = src.count(old)
        src = src.replace(old, new)
        count += n
        print("  [{}x] {}".format(n, old[:60]))

print()
print("Total:", count)

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)

print("SUCCESS")
