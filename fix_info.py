import sys

PATH = 'dex.source.lua'
with open(PATH, 'r', encoding='utf-8') as f:
    src = f.read()

ORIG = len(src)
print(f"[i] size: {ORIG}")

# ========== ابحث عن بلوك Info button ==========
START = 'openButton.MainFrame.BottomFrame.Information.MouseButton1Click:Connect(function()'
idx_start = src.find(START)
if idx_start < 0:
    print("ABORT: info button handler not found")
    sys.exit(1)

# نهاية البلوك: أول \t\tend) بعد البداية
END_PATTERN = '\t\tend)'
idx_end = src.find(END_PATTERN, idx_start)
if idx_end < 0:
    print("ABORT: end pattern not found")
    sys.exit(1)
idx_end += len(END_PATTERN)

old_block = src[idx_start:idx_end]
print(f"[i] old block length: {len(old_block)}")
print(f"[i] old block starts: {old_block[:80]!r}")
print(f"[i] old block ends:   {old_block[-80:]!r}")

# تأكد إن ده البلوك الصح
if 'Contributors' not in old_block and 'LegacyAuthor' not in old_block:
    print("ABORT: wrong block (no Contributors/LegacyAuthor)")
    print("Full block:")
    print(old_block)
    sys.exit(1)

# ========== البلوك الجديد ==========
NEW_BLOCK = '''openButton.MainFrame.BottomFrame.Information.MouseButton1Click:Connect(function()
if Main._InfoWindow and Main._InfoWindow.Gui and Main._InfoWindow.Gui.Parent then
pcall(function() Main._InfoWindow:Close() end)
Main._InfoWindow = nil
return
end
local win = Lib.Window.new()
win:SetTitle("About")
win:Resize(340, 400)
win.Resizable = false
win.Alignable = false
Main._InfoWindow = win
local Y = 0
local function addLine(text, size, bold, color)
local lbl = Lib.Label.new()
lbl.Text = text
lbl.Size = UDim2.new(1, -20, 0, 20)
lbl.Position = UDim2.new(0, 10, 0, Y)
lbl.Gui.TextSize = size or 13
lbl.Gui.TextTruncate = Enum.TextTruncate.AtEnd
if bold then lbl.Gui.Font = Enum.Font.SourceSansBold end
if color then lbl.Gui.TextColor3 = color end
win:Add(lbl)
Y = Y + (size or 13) + 6
end
addLine("DEX V FLOXIN", 22, true)
addLine("Enhanced Dex Explorer for Roblox", 12, false, Color3.fromRGB(170,170,170))
Y = Y + 8
addLine("Owner     : FLOXIN", 13, true)
addLine("Architect : FLAUX", 13, true)
Y = Y + 8
addLine("Features:", 13, true)
addLine("  Explorer + Properties", 12, false, Color3.fromRGB(200,200,200))
addLine("  Console + Script Viewer", 12, false, Color3.fromRGB(200,200,200))
addLine("  SaveInstance + Model Viewer", 12, false, Color3.fromRGB(200,200,200))
addLine("  Bulk Copier", 12, false, Color3.fromRGB(200,200,200))
addLine("  In-game Browser (Web + Roblox)", 12, false, Color3.fromRGB(200,200,200))
Y = Y + 10
addLine("Version 1.0  ·  (c) 2026 FLOXIN & FLAUX", 11, false, Color3.fromRGB(140,140,140))
local closeBtn = Lib.Button.new()
closeBtn.Text = "Close"
closeBtn.Size = UDim2.new(0, 120, 0, 26)
closeBtn.Position = UDim2.new(0.5, -60, 1, -34)
closeBtn.OnClick:Connect(function()
pcall(function() win:Close() end)
Main._InfoWindow = nil
end)
win:Add(closeBtn, "CloseBtn")
win:Show()
end)'''

src = src[:idx_start] + NEW_BLOCK + src[idx_end:]

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"[OK] new size: {len(src)} (delta {len(src)-ORIG:+d})")
print("SUCCESS")
