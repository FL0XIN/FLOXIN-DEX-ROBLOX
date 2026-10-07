import sys

with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

orig = len(src)
print(f"[i] src: {orig}")

# ============ 1. Serializer + Copy Code Button in ModelViewer ============
ANCHOR = 'window:Resize(350,200)'
if src.count(ANCHOR) != 1:
    print(f"ABORT: 3D Preview anchor = {src.count(ANCHOR)}")
    idx = src.find('3D Preview')
    if idx > 0:
        print("Context:", repr(src[idx-100:idx+300]))
    sys.exit(1)

ADD = '''

-- FLOXIN: serializer + copy code button
local function _esc(s)
return tostring(s):gsub("\\\\","\\\\\\\\"):gsub("\\"","\\\\\\""):gsub("\\n","\\\\n")
end
local function _serialize(obj, indent, counter)
indent = indent or ""
counter.n = counter.n + 1
local v = "obj"..tostring(counter.n)
local L = {}
table.insert(L, indent.."local "..v.." = Instance.new(\\""..obj.ClassName.."\\")")
table.insert(L, indent..v..".Name = \\"".._esc(obj.Name).."\\"")
if obj:IsA("BasePart") then
local s = obj.Size
table.insert(L, string.format("%s%s.Size = Vector3.new(%s, %s, %s)", indent, v, tostring(s.X), tostring(s.Y), tostring(s.Z)))
local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = obj.CFrame:GetComponents()
table.insert(L, string.format("%s%s.CFrame = CFrame.new(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
indent, v, tostring(x),tostring(y),tostring(z),tostring(R00),tostring(R01),tostring(R02),
tostring(R10),tostring(R11),tostring(R12),tostring(R20),tostring(R21),tostring(R22)))
local c = obj.Color
table.insert(L, string.format("%s%s.Color = Color3.new(%s,%s,%s)", indent, v, tostring(c.R), tostring(c.G), tostring(c.B)))
table.insert(L, indent..v..".Material = Enum.Material."..obj.Material.Name)
table.insert(L, indent..v..".Anchored = "..tostring(obj.Anchored))
table.insert(L, indent..v..".CanCollide = "..tostring(obj.CanCollide))
if obj.Transparency > 0 then
table.insert(L, indent..v..".Transparency = "..tostring(obj.Transparency))
end
if obj:IsA("Part") then
table.insert(L, indent..v..".Shape = Enum.PartType."..obj.Shape.Name)
end
if obj:IsA("MeshPart") then
table.insert(L, indent..v..".MeshId = \\"".._esc(obj.MeshId).."\\"")
if obj.TextureID and obj.TextureID ~= "" then
table.insert(L, indent..v..".TextureID = \\"".._esc(obj.TextureID).."\\"")
end
end
end
for _, child in ipairs(obj:GetChildren()) do
local code, cvar = _serialize(child, indent.."\\t", counter)
table.insert(L, code)
table.insert(L, indent..cvar..".Parent = "..v)
end
return table.concat(L, "\\n"), v
end

local copyCodeBtn = Instance.new("TextButton")
copyCodeBtn.Name = "CopyMeshCode"
copyCodeBtn.Size = UDim2.new(0, 16, 0, 16)
copyCodeBtn.Position = UDim2.new(1, -72, 0, 2)
copyCodeBtn.BackgroundTransparency = 1
copyCodeBtn.Text = "{}"
copyCodeBtn.TextColor3 = Color3.fromRGB(220,220,220)
copyCodeBtn.TextSize = 12
copyCodeBtn.Font = Enum.Font.Code
copyCodeBtn.AutoButtonColor = false
copyCodeBtn.Parent = window.GuiElems.TopBar
local _cc = Instance.new("UICorner"); _cc.CornerRadius = UDim.new(0,4); _cc.Parent = copyCodeBtn
copyCodeBtn.MouseButton1Click:Connect(function()
local target = originalModel
if not target then return end
local code = "-- FLOXIN mesh export · "..target:GetFullName().."\\n"
code = code .. "local root = Instance.new(\\"Folder\\")\\nroot.Name = \\"FLOXIN_Export\\"\\n"
code = code .. "root.Parent = workspace\\n\\n"
local body, v = _serialize(target, "", {n=0})
code = code .. body .. "\\n\\n" .. v .. ".Parent = root\\n\\nreturn root"
local okc = false
if setclipboard then pcall(function() setclipboard(code) okc=true end) end
if not okc and env and env.setclipboard then pcall(function() env.setclipboard(code) okc=true end) end
copyCodeBtn.Text = okc and "OK" or "X"
task.wait(1.2)
copyCodeBtn.Text = "{}"
end)'''

src = src.replace(ANCHOR, 'window:Resize(350,200)' + ADD, 1)
print("[1] copy-code button added to 3D Viewer")

# ============ 2. ModelEditor module ============
with open('modeleditor_module.lua', 'r', encoding='utf-8') as f:
    me = f.read()
print(f"[i] modeleditor module: {len(me)}")

if '["ModelEditor"] = function' in src:
    print("ABORT: ModelEditor already in src")
    sys.exit(1)

MARKER = '["Console"] = function()'
src = src.replace(MARKER, me + MARKER, 1)
print("[2] ModelEditor inserted")

OLD = '"ModelViewer","BulkCopier","Browser","PlayersExplorer","Editor"}'
NEW = '"ModelViewer","BulkCopier","Browser","PlayersExplorer","Editor","ModelEditor"}'
if src.count(OLD) != 1:
    print(f"ABORT: ModuleList = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, NEW, 1)
print("[3] ModuleList")

OLD = 'Editor = Apps.Editor'
if src.count(OLD) != 1:
    print(f"ABORT: apps = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tModelEditor = Apps.ModelEditor', 1)
print("[4] apps")

OLD = 'Editor = Editor,'
if src.count(OLD) != 1:
    print(f"ABORT: appTable = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\t\tModelEditor = ModelEditor,', 1)
print("[5] appTable")

OLD = 'Editor.Init()'
if src.count(OLD) != 1:
    print(f"ABORT: Init = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tModelEditor.Init()', 1)
print("[6] Init")

OLD = 'Main.CreateApp({Name = "Editor", IconMap = Main.MiscIcons, Icon = "ViewScript", Window = Editor.Window})'
if src.count(OLD) != 1:
    print(f"ABORT: CreateApp = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tMain.CreateApp({Name = "Model Editor", IconMap = Main.MiscIcons, Icon = "InsertObject", Window = ModelEditor.Window})', 1)
print("[7] CreateApp icon")

for n in ['["ModelEditor"] = function', 'ModelEditor.Init()', 'ModelEditor = Apps.ModelEditor', 'ModelEditor = ModelEditor,', 'Name = "Model Editor"', 'CopyMeshCode']:
    if src.count(n) != 1:
        print(f"FAIL: {n} = {src.count(n)}")
        sys.exit(1)

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)
print()
print(f"[OK] New size: {len(src)} (delta {len(src)-orig:+d})")
print("SUCCESS")
