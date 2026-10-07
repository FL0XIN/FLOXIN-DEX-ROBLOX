import sys

PATH = 'dex.source.lua'
with open(PATH, 'r', encoding='utf-8') as f:
    src = f.read()

ORIG = len(src)
print(f"[i] size: {ORIG}")

START = 'openButton.MainFrame.BottomFrame.Information.MouseButton1Click:Connect(function()'
idx_start = src.find(START)
if idx_start < 0:
    print("ABORT: START not found"); sys.exit(1)

# anchor النهاية: سطر Create Main Apps
END_ANCHOR = '-- Create Main Apps'
idx_end = src.find(END_ANCHOR, idx_start)
if idx_end < 0:
    print("ABORT: end anchor not found"); sys.exit(1)

old_block = src[idx_start:idx_end]
print(f"[i] old length: {len(old_block)}")
print(f"[i] starts: {old_block[:80]!r}")
print(f"[i] ends: {old_block[-80:]!r}")

# ========== البلوك الجديد ==========
NEW_BLOCK = '''openButton.MainFrame.BottomFrame.Information.MouseButton1Click:Connect(function()
if Main._AboutGui and Main._AboutGui.Parent then
Main._AboutGui:Destroy()
Main._AboutGui = nil
return
end
local sg = Instance.new("ScreenGui")
sg.Name = "FLOXIN_About"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
Lib.ShowGui(sg)
Main._AboutGui = sg

local frame = Instance.new("Frame", sg)
frame.Size = UDim2.new(0, 300, 0, 400)
frame.Position = UDim2.new(0.5, -150, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(45,45,45)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(30,30,30)
stroke.Thickness = 1

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -20, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "About"
title.TextColor3 = Color3.fromRGB(230,230,230)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left

local sep = Instance.new("Frame", frame)
sep.Size = UDim2.new(1, -20, 0, 1)
sep.Position = UDim2.new(0, 10, 0, 34)
sep.BackgroundColor3 = Color3.fromRGB(30,30,30)
sep.BorderSizePixel = 0

local Y = 44
local function add(text, size, bold, color)
local l = Instance.new("TextLabel", frame)
l.Size = UDim2.new(1, -20, 0, size + 4)
l.Position = UDim2.new(0, 10, 0, Y)
l.BackgroundTransparency = 1
l.Text = text
l.TextColor3 = color or Color3.fromRGB(220,220,220)
l.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
l.TextSize = size
l.TextXAlignment = Enum.TextXAlignment.Left
l.TextTruncate = Enum.TextTruncate.AtEnd
Y = Y + size + 8
end

add("DEX V FLOXIN", 22, true, Color3.fromRGB(255,255,255))
add("Enhanced Dex Explorer", 12, false, Color3.fromRGB(170,170,170))
Y = Y + 6
add("Owner      : FLOXIN", 13, true)
add("Architect  : FLAUX", 13, true)
Y = Y + 6
add("Features:", 13, true)
add("  Explorer / Properties", 12, false, Color3.fromRGB(200,200,200))
add("  Console / Script Viewer", 12, false, Color3.fromRGB(200,200,200))
add("  SaveInstance / Model", 12, false, Color3.fromRGB(200,200,200))
add("  Bulk Copier", 12, false, Color3.fromRGB(200,200,200))
add("  Browser (Web + Roblox)", 12, false, Color3.fromRGB(200,200,200))
Y = Y + 6
add("Version 1.0  ·  (c) 2026", 11, false, Color3.fromRGB(140,140,140))

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0, 100, 0, 28)
closeBtn.Position = UDim2.new(0.5, -50, 1, -38)
closeBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
closeBtn.Text = "Close"
closeBtn.TextColor3 = Color3.fromRGB(230,230,230)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function()
if sg and sg.Parent then sg:Destroy() end
Main._AboutGui = nil
end)
end)

\t\t'''

src = src[:idx_start] + NEW_BLOCK + src[idx_end:]

with open(PATH, 'w', encoding='utf-8') as f:
    f.write(src)

print(f"[OK] new size: {len(src)} (delta {len(src)-ORIG:+d})")
print("SUCCESS")
