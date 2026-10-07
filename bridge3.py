import sys

with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()
with open('editor_module.lua', 'r', encoding='utf-8') as f:
    module = f.read()

orig = len(src)
print(f"[i] src: {orig}")
print(f"[i] module: {len(module)}")

# verify module
if 'Preview = function(obj)' not in module:
    print("ABORT: module missing Preview"); sys.exit(1)
print("[i] module has bridge APIs")

# ========== 1. Remove Editor if exists ==========
if '["Editor"] = function' in src:
    print("[i] removing Editor from src...")
    start = src.find('["Editor"] = function')
    end_pos = src.find('["Console"] = function()', start)
    if start < 0 or end_pos < 0:
        print("ABORT: cannot find Editor boundaries"); sys.exit(1)
    src = src[:start] + src[end_pos:]
    # cleanup refs
    src = src.replace(',"Editor"}', '}')
    src = src.replace('\n\t\tEditor = Apps.Editor', '')
    src = src.replace('\n\t\t\tEditor = Editor,', '')
    src = src.replace('\n\t\tEditor.Init()', '')
    src = src.replace('\n\t\tMain.CreateApp({Name = "Editor", IconMap = Main.MiscIcons, Icon = "ViewScript", Window = Editor.Window})', '')
    print(f"[i] Editor removed, src now: {len(src)}")

if '["Editor"] = function' in src:
    print("ABORT: still has Editor"); sys.exit(1)

# ========== 2. Click-part auto-preview ==========
ANCHOR = 'Explorer.ViewNode(nodes[object])'
if src.count(ANCHOR) != 1:
    print(f"ABORT: click anchor = {src.count(ANCHOR)}")
    idx = src.find('Click part to select')
    if idx > 0:
        print("Context:", repr(src[idx:idx+700]))
    sys.exit(1)

NEW_BLOCK = '''Explorer.ViewNode(nodes[object])
-- FLOXIN: auto-preview in 3D Viewer
if object and (object:IsA("BasePart") or object:IsA("Model")) then
pcall(function()
if Apps and Apps.ModelViewer and Apps.ModelViewer.ViewModel then
Apps.ModelViewer.ViewModel(object)
end
end)
end'''

src = src.replace(ANCHOR, NEW_BLOCK, 1)
print("[1] click-part auto-preview inserted")

# ========== 3. Re-merge Editor ==========
MARKER = '["Console"] = function()'
if src.count(MARKER) != 1:
    print(f"ABORT: marker = {src.count(MARKER)}")
    sys.exit(1)
src = src.replace(MARKER, module + MARKER, 1)
print("[2] editor inserted")

OLD = '"ModelViewer","BulkCopier","Browser","PlayersExplorer"}'
NEW = '"ModelViewer","BulkCopier","Browser","PlayersExplorer","Editor"}'
if src.count(OLD) != 1:
    print(f"ABORT: ModuleList = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, NEW, 1)
print("[3] ModuleList")

OLD = 'PlayersExplorer = Apps.PlayersExplorer'
if src.count(OLD) != 1:
    print(f"ABORT: apps = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tEditor = Apps.Editor', 1)
print("[4] apps")

OLD = 'PlayersExplorer = PlayersExplorer,'
if src.count(OLD) != 1:
    print(f"ABORT: appTable = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\t\tEditor = Editor,', 1)
print("[5] appTable")

OLD = 'PlayersExplorer.Init()'
if src.count(OLD) != 1:
    print(f"ABORT: Init = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tEditor.Init()', 1)
print("[6] Init")

OLD = 'Main.CreateApp({Name = "Players Explorer", IconMap = Main.MiscIcons, Icon = "SelectChildren", Window = PlayersExplorer.Window})'
if src.count(OLD) != 1:
    print(f"ABORT: CreateApp = {src.count(OLD)}")
    sys.exit(1)
src = src.replace(OLD, OLD + '\n\t\tMain.CreateApp({Name = "Editor", IconMap = Main.MiscIcons, Icon = "ViewScript", Window = Editor.Window})', 1)
print("[7] CreateApp icon")

# verify
checks = [
    ('["Editor"] = function', 1),
    ('Editor.Init()', 1),
    ('Editor = Apps.Editor', 1),
    ('Editor = Editor,', 1),
    ('Name = "Editor"', 1),
    ('FLOXIN: auto-preview in 3D Viewer', 1),
]
print()
for n, e in checks:
    c = src.count(n)
    s = "OK" if c == e else "FAIL"
    print(f"  {s}  {n} x{c}")
    if c != e:
        print("ABORT"); sys.exit(1)

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)
print()
print(f"[OK] New size: {len(src)} (delta {len(src)-orig:+d})")
print("SUCCESS")
