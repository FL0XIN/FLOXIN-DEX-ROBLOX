["ModelEditor"] = function()
local Main,Lib,Apps,Settings
local API,RMD,env,service,plr,create,createSimple
local function initDeps(d)
    Main=d.Main Lib=d.Lib Apps=d.Apps Settings=d.Settings
    API=d.API RMD=d.RMD env=d.env service=d.service plr=d.plr
    create=d.create createSimple=d.createSimple
end
local function initAfterMain() end

local function main()
local ME = {}
local window, content
local spawned = {}
local lastSettings = {
    shape = "Block",
    material = "Plastic",
    color = {r=1, g=1, b=1},
    sizeX = 4, sizeY = 4, sizeZ = 4,
    anchored = true,
    cancollide = true,
    transparency = 0,
}

local SHAPES = {"Block", "Ball", "Cylinder", "Wedge", "CornerWedge"}
local MATERIALS = {
    "Plastic","Wood","Slate","Concrete","CorrodedMetal","DiamondPlate",
    "Foil","Grass","Ice","Marble","Granite","Brick","Pebble","Sand",
    "Fabric","SmoothPlastic","Metal","WoodPlanks","Cobblestone","Neon",
    "Glass","ForceField","Marble"
}

local function getSpawnPosition()
    local cam = workspace.CurrentCamera
    if not cam then return Vector3.new(0, 10, 0) end
    local cf = cam.CFrame
    return (cf * CFrame.new(0, 0, -20)).Position
end

local function createPart()
    local p = Instance.new("Part")
    p.Name = "FLOXIN_Part_"..math.random(1000,9999)
    p.Shape = Enum.PartType[lastSettings.shape]
    p.Material = Enum.Material[lastSettings.material]
    p.Color = Color3.new(lastSettings.color.r, lastSettings.color.g, lastSettings.color.b)
    p.Size = Vector3.new(lastSettings.sizeX, lastSettings.sizeY, lastSettings.sizeZ)
    p.Anchored = lastSettings.anchored
    p.CanCollide = lastSettings.cancollide
    p.Transparency = lastSettings.transparency
    p.Position = getSpawnPosition()
    p.Parent = workspace
    table.insert(spawned, p)
    return p
end

-- UI helpers
local function mkRow(parent)
    local f = Instance.new("Frame", parent)
    f.Size = UDim2.new(1, -6, 0, 26)
    f.BackgroundColor3 = Settings.Theme.Main2
    f.BorderSizePixel = 0
    f.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    return f
end

local function mkLabel(parent, text, w)
    local l = Instance.new("TextLabel", parent)
    l.Size = UDim2.new(0, w or 80, 1, 0)
    l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Settings.Theme.Text
    l.Font = Enum.Font.SourceSans
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

local function mkNum(parent, x, default, cb)
    local box = Instance.new("TextBox", parent)
    box.Size = UDim2.new(0, 46, 0, 20)
    box.Position = UDim2.new(0, x, 0, 3)
    box.BackgroundColor3 = Settings.Theme.TextBox
    box.BorderSizePixel = 0
    box.Text = tostring(default)
    box.TextColor3 = Settings.Theme.Text
    box.Font = Enum.Font.Code
    box.TextSize = 11
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then cb(n) end
    end)
    return box
end

local function mkDropdown(parent, x, list, default, cb)
    local holder = Instance.new("Frame", parent)
    holder.Size = UDim2.new(0, 110, 0, 20)
    holder.Position = UDim2.new(0, x, 0, 3)
    holder.BackgroundColor3 = Settings.Theme.TextBox
    holder.BorderSizePixel = 0
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 3)

    local lbl = Instance.new("TextLabel", holder)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(default)
    lbl.TextColor3 = Settings.Theme.Text
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    local btn = Instance.new("TextButton", holder)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        local ctx = Instance.new("Frame", window.GuiElems.Content)
        ctx.Size = UDim2.new(0, 130, 0, math.min(#list*22+8, 200))
        ctx.Position = UDim2.new(0, holder.AbsolutePosition.X - window.GuiElems.Content.AbsolutePosition.X, 0, holder.AbsolutePosition.Y - window.GuiElems.Content.AbsolutePosition.Y + 22)
        ctx.BackgroundColor3 = Settings.Theme.Main1
        ctx.BorderSizePixel = 0
        ctx.ZIndex = 99
        Instance.new("UICorner", ctx).CornerRadius = UDim.new(0, 5)
        local st = Instance.new("UIStroke", ctx)
        st.Color = Settings.Theme.Outline1
        local sc = Instance.new("ScrollingFrame", ctx)
        sc.Size = UDim2.new(1, 0, 1, 0)
        sc.BackgroundTransparency = 1
        sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 4
        sc.CanvasSize = UDim2.new(0,0,0,#list*22+4)
        local lay = Instance.new("UIListLayout", sc)
        lay.Padding = UDim.new(0,1)
        for _, item in ipairs(list) do
            local ib = Instance.new("TextButton", sc)
            ib.Size = UDim2.new(1, -4, 0, 20)
            ib.BackgroundColor3 = Settings.Theme.Main2
            ib.Text = tostring(item)
            ib.TextColor3 = Settings.Theme.Text
            ib.Font = Enum.Font.SourceSans
            ib.TextSize = 11
            ib.BorderSizePixel = 0
            ib.AutoButtonColor = false
            Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 3)
            ib.MouseButton1Click:Connect(function()
                lbl.Text = tostring(item)
                cb(item)
                ctx:Destroy()
            end)
        end
        -- close on outside click
        local mConn
        mConn = service.UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                ctx:Destroy()
                mConn:Disconnect()
            end
        end)
    end)
    return holder
end

local function mkBtn(parent, text, color, cb, w, x, y)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, w or 100, 0, 28)
    b.Position = UDim2.new(0, x or 0, 0, y or 0)
    b.BackgroundColor3 = color or Settings.Theme.Button
    b.Text = text
    b.TextColor3 = Settings.Theme.Text
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

ME.Init = function()
    window = Lib.Window.new()
    window:SetTitle("Model Editor")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 320 or 380, isMobile and 460 or 540)
    ME.Window = window

    content = Instance.new("ScrollingFrame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -8)
    content.Position = UDim2.new(0, 4, 0, 4)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = Settings.Theme.Outline1
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout", content)
    lay.Padding = UDim.new(0, 4)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    -- header
    local hdr = Instance.new("TextLabel", content)
    hdr.Size = UDim2.new(1, -6, 0, 22)
    hdr.BackgroundTransparency = 1
    hdr.Text = "Create Part"
    hdr.TextColor3 = Settings.Theme.Text
    hdr.Font = Enum.Font.SourceSansBold
    hdr.TextSize = 13
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.LayoutOrder = #content:GetChildren()

    -- Shape
    local r1 = mkRow(content)
    mkLabel(r1, "Shape", 50)
    mkDropdown(r1, 60, SHAPES, lastSettings.shape, function(v) lastSettings.shape = v end)

    -- Material
    local r2 = mkRow(content)
    mkLabel(r2, "Material", 60)
    mkDropdown(r2, 70, MATERIALS, lastSettings.material, function(v) lastSettings.material = v end)

    -- Size
    local r3 = mkRow(content)
    mkLabel(r3, "Size X/Y/Z", 70)
    mkNum(r3, 76, lastSettings.sizeX, function(v) lastSettings.sizeX = v end)
    mkNum(r3, 128, lastSettings.sizeY, function(v) lastSettings.sizeY = v end)
    mkNum(r3, 180, lastSettings.sizeZ, function(v) lastSettings.sizeZ = v end)

    -- Color R/G/B
    local r4 = mkRow(content)
    mkLabel(r4, "Color R/G/B", 76)
    mkNum(r4, 82, lastSettings.color.r, function(v) lastSettings.color.r = math.clamp(v, 0, 1) end)
    mkNum(r4, 134, lastSettings.color.g, function(v) lastSettings.color.g = math.clamp(v, 0, 1) end)
    mkNum(r4, 186, lastSettings.color.b, function(v) lastSettings.color.b = math.clamp(v, 0, 1) end)

    -- Transparency
    local r5 = mkRow(content)
    mkLabel(r5, "Transparency", 80)
    mkNum(r5, 88, lastSettings.transparency, function(v) lastSettings.transparency = math.clamp(v, 0, 1) end)

    -- Anchored / CanCollide
    local r6 = mkRow(content)
    mkLabel(r6, "Anchored", 60)
    local anchBtn = mkBtn(r6, lastSettings.anchored and "ON" or "OFF", lastSettings.anchored and Settings.Theme.ListSelection or Settings.Theme.Button, function() end, 40, 66, 0)
    anchBtn.MouseButton1Click:Connect(function()
        lastSettings.anchored = not lastSettings.anchored
        anchBtn.Text = lastSettings.anchored and "ON" or "OFF"
        anchBtn.BackgroundColor3 = lastSettings.anchored and Settings.Theme.ListSelection or Settings.Theme.Button
    end)

    mkLabel(r6, "  CanCollide", 0)
    local ccLbl = r6:GetChildren()[#r6:GetChildren()]
    ccLbl.Position = UDim2.new(0, 116, 0, 0)
    ccLbl.Size = UDim2.new(0, 70, 1, 0)
    local ccBtn = mkBtn(r6, lastSettings.cancollide and "ON" or "OFF", lastSettings.cancollide and Settings.Theme.ListSelection or Settings.Theme.Button, function() end, 40, 190, 0)
    ccBtn.MouseButton1Click:Connect(function()
        lastSettings.cancollide = not lastSettings.cancollide
        ccBtn.Text = lastSettings.cancollide and "ON" or "OFF"
        ccBtn.BackgroundColor3 = lastSettings.cancollide and Settings.Theme.ListSelection or Settings.Theme.Button
    end)

    -- separator
    local sep = Instance.new("Frame", content)
    sep.Size = UDim2.new(1, -6, 0, 1)
    sep.BackgroundColor3 = Settings.Theme.Outline1
    sep.BorderSizePixel = 0
    sep.LayoutOrder = #content:GetChildren()

    -- Actions header
    local hdr2 = Instance.new("TextLabel", content)
    hdr2.Size = UDim2.new(1, -6, 0, 20)
    hdr2.BackgroundTransparency = 1
    hdr2.Text = "Actions"
    hdr2.TextColor3 = Settings.Theme.Text
    hdr2.Font = Enum.Font.SourceSansBold
    hdr2.TextSize = 13
    hdr2.TextXAlignment = Enum.TextXAlignment.Left
    hdr2.LayoutOrder = #content:GetChildren()

    -- Spawn
    mkBtn(content, "Spawn Part", Settings.Theme.ListSelection, function()
        local p = createPart()
        if Apps.ModelViewer and Apps.ModelViewer.ViewModel then
            pcall(function() Apps.ModelViewer.ViewModel(p) end)
        end
    end, 200, 0, 0).Size = UDim2.new(0, 200, 0, 30)

    -- Clear spawned
    mkBtn(content, "Clear My Spawned Parts ("..#spawned..")", Settings.Theme.Button, function()
        for _, p in ipairs(spawned) do
            pcall(function() p:Destroy() end)
        end
        spawned = {}
    end, 260, 0, 0).Size = UDim2.new(0, 260, 0, 28)

    -- Spawn Cube 10x10
    mkBtn(content, "Quick: 10x10 Cube", Settings.Theme.Button, function()
        lastSettings.sizeX = 10; lastSettings.sizeY = 10; lastSettings.sizeZ = 10
        createPart()
    end, 140, 0, 0).Size = UDim2.new(0, 140, 0, 26)

    -- Spawn Sphere
    mkBtn(content, "Quick: Ball r=5", Settings.Theme.Button, function()
        lastSettings.shape = "Ball"
        lastSettings.sizeX = 10; lastSettings.sizeY = 10; lastSettings.sizeZ = 10
        createPart()
    end, 140, 0, 0).Size = UDim2.new(0, 140, 0, 26)
end

return ME
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

