import re, sys
with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

orig = len(src)
print("[i] src:", orig)

# ═══════════════════════════════════════════════════════
# 1. CodeFrame EditBox → mobile-friendly
# ═══════════════════════════════════════════════════════
pat = re.compile(
    r'local\s+editBox\s*=\s*Instance\.new\("TextBox"\)\s*\n'
    r'\s*editBox\.Name\s*=\s*"EditBox"\s*\n'
    r'\s*editBox\.MultiLine\s*=\s*true\s*\n'
    r'\s*editBox\.Visible\s*=\s*false\s*\n'
    r'\s*editBox\.Parent\s*=\s*frame'
)
c = len(pat.findall(src))
print("[1] editBox anchor:", c)
if c == 1:
    new = '''local editBox = Instance.new("TextBox")
editBox.Name = "EditBox"
editBox.MultiLine = true
editBox.Visible = true
editBox.BackgroundTransparency = 1
editBox.TextTransparency = 1
editBox.TextColor3 = Color3.fromRGB(0,0,0)
editBox.Size = UDim2.new(1, 0, 1, 0)
editBox.Position = UDim2.new(0, 0, 0, 0)
editBox.ZIndex = 999
editBox.Active = true
editBox.TextEditable = true
editBox.Selectable = true
editBox.Parent = frame'''
    src = pat.sub(new, src, count=1)
    print("[1] CodeFrame editBox fixed")

# ═══════════════════════════════════════════════════════
# 2. Material Icons map (after LargeIcons definition)
# ═══════════════════════════════════════════════════════
anchor = 'Main.LargeIcons:SetDict({'
if src.count(anchor) != 1:
    print("ABORT: LargeIcons =", src.count(anchor)); sys.exit(1)

# Find end of LargeIcons SetDict block
idx = src.find(anchor)
end_idx = src.find('})', idx)
if end_idx < 0:
    print("ABORT: LargeIcons block end not found"); sys.exit(1)
end_idx += 2

MAT = '''

-- Material Icons pack (rbxassetid://3926305904 · 900x900 · 36px cells)
if Lib.IconMap then
Main.FloxIcons = Lib.IconMap.new("rbxassetid://3926305904", 900, 900, 36, 36)
end'''

src = src[:end_idx] + MAT + src[end_idx:]
print("[2] Material Icons map added")

# ═══════════════════════════════════════════════════════
# 3. Apply Material Icons to our tools
# ═══════════════════════════════════════════════════════
ICON_MAP = {
    'Browser':            ('FloxIcons', 242),
    'Players Explorer':   ('FloxIcons', 12),
    'Editor':             ('FloxIcons', 63),
    'Developer Scripts':  ('FloxIcons', 216),
}

for name, (map_name, index) in ICON_MAP.items():
    # pattern: Main.CreateApp({Name = "XXX", IconMap = ..., Icon = ..., Window = ...})
    pat = re.compile(
        r'(Main\.CreateApp\(\{Name\s*=\s*"' + re.escape(name) + r'",\s*)'
        r'IconMap\s*=\s*[^,]+,\s*'
        r'Icon\s*=\s*[^,]+',
        re.DOTALL
    )
    m = pat.findall(src)
    if len(m) == 1:
        replacement = r'\1IconMap = Main.' + map_name + ', Icon = ' + str(index)
        src = pat.sub(replacement, src, count=1)
        print(f"[3] {name} → Material {index}")
    else:
        print(f"[3] WARN: {name} matches = {len(m)}")

# ═══════════════════════════════════════════════════════
# 4. Compact About window (find and shrink)
# ═══════════════════════════════════════════════════════
pat = re.compile(
    r'frame\.Size\s*=\s*UDim2\.new\(0,\s*300,\s*0,\s*400\)\s*\n'
    r'\s*frame\.Position\s*=\s*UDim2\.new\(0\.5,\s*-150,\s*0\.5,\s*-200\)'
)
c = len(pat.findall(src))
print("[4] About size anchor:", c)
if c == 1:
    src = pat.sub(
        'frame.Size = UDim2.new(0, 260, 0, 340)\n'
        'frame.Position = UDim2.new(0.5, -130, 0.5, -170)',
        src, count=1
    )
    print("[4] About compacted")

# ═══════════════════════════════════════════════════════
# 5. Mobile keyboard scanner (end of file)
# ═══════════════════════════════════════════════════════
MARKER = '-- Start\nMain.Init()'
if src.count(MARKER) != 1:
    print("ABORT: Main.Init marker =", src.count(MARKER)); sys.exit(1)

MOBILE_FIX = '''-- Start
Main.Init()

-- ═══════════════════════════════════════════════════════
-- FLOXIN Mobile Keyboard Support
-- Runs after Dex loads · fixes all TextBoxes
-- ═══════════════════════════════════════════════════════
task.delay(5, function()
local UIS = game:GetService("UserInputService")
if not UIS.TouchEnabled then return end
print("[FLOXIN] mobile keyboard fix active")

local function fixTB(tb)
pcall(function()
tb.Active = true
tb.TextEditable = true
tb.Selectable = true
tb.ManualFocusRelease = true
if tb.Name == "EditBox" and not tb.Visible then
tb.Visible = true
tb.BackgroundTransparency = 1
tb.TextTransparency = 1
end
end)
end

task.spawn(function()
while true do
task.wait(3)
local roots = {}
pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
if gethui then
local ok, h = pcall(gethui)
if ok and h and typeof(h) == "Instance" then table.insert(roots, h) end
end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
if pg then table.insert(roots, pg) end

for _, root in ipairs(roots) do
pcall(function()
for _, tb in ipairs(root:GetDescendants()) do
if tb:IsA("TextBox") then fixTB(tb) end
end
end)
end
end
end)
end)'''

src = src.replace(MARKER, MOBILE_FIX, 1)
print("[5] mobile keyboard fix injected")

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)
print("[OK] size:", len(src), "(delta", len(src)-orig, ")")
print("SUCCESS")
