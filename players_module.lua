["PlayersExplorer"] = function()
local Main,Lib,Apps,Settings
local Explorer,Properties,ScriptViewer,Notebook
local API,RMD,env,service,plr,create,createSimple
local function initDeps(d)
    Main=d.Main Lib=d.Lib Apps=d.Apps Settings=d.Settings
    API=d.API RMD=d.RMD env=d.env service=d.service plr=d.plr
    create=d.create createSimple=d.createSimple
end
local function initAfterMain()
    Explorer=Apps.Explorer Properties=Apps.Properties
    ScriptViewer=Apps.ScriptViewer Notebook=Apps.Notebook
end
local function main()
local PE = {}
local window, content
local expanded = {}
local localPlayer = service.Players.LocalPlayer

local function copy(t)
    local ok = false
    if env and env.setclipboard then pcall(function() env.setclipboard(t) ok=true end) end
    if not ok and setclipboard then pcall(function() setclipboard(t) ok=true end) end
    if not ok and toclipboard then pcall(function() toclipboard(t) ok=true end) end
    return ok
end

-- scan leaderstats
local function scanLeaderstats(p)
    local list = {}
    local ls = p:FindFirstChild("leaderstats")
    if not ls then return list end
    for _, c in ipairs(ls:GetChildren()) do
        if c:IsA("ValueBase") then
            table.insert(list, {k = "  [LS] "..c.Name, v = tostring(c.Value), copy = tostring(c.Value)})
        end
    end
    return list
end

-- scan attributes of an instance
local function scanAttrs(inst, prefix)
    local list = {}
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or not attrs then return list end
    for name, val in pairs(attrs) do
        table.insert(list, {k = "  "..prefix..name, v = tostring(val), copy = tostring(val)})
    end
    return list
end

-- scan player-specific folder in workspace
local function findWorkspaceFolder(p)
    local candidates = { p.Name, tostring(p.UserId), p.DisplayName }
    for _, name in ipairs(candidates) do
        local f = workspace:FindFirstChild(name)
        if f then return f end
    end
    return nil
end

-- scan ReplicatedStorage player folder
local function findRSFolder(p)
    local RS = game:GetService("ReplicatedStorage")
    local candidates = { p.Name, tostring(p.UserId), p.DisplayName }
    for _, name in ipairs(candidates) do
        local f = RS:FindFirstChild(name)
        if f then return f end
    end
    return nil
end

-- recursive count of descendants
local function countDesc(inst, maxDepth)
    maxDepth = maxDepth or 4
    local count = 0
    local function rec(o, d)
        if d > maxDepth then return end
        for _, c in ipairs(o:GetChildren()) do
            count = count + 1
            if #c:GetChildren() > 0 then rec(c, d+1) end
        end
    end
    rec(inst, 0)
    return count
end

local function buildInfo(p)
    local out = {}
    local function add(k, v, copyVal)
        table.insert(out, {k=k, v=v, copy=copyVal or tostring(v)})
    end

    add("Name", p.Name)
    add("Display", p.DisplayName or p.Name)
    add("UserId", tostring(p.UserId), "user:"..p.UserId)
    add("AccountAge", (function()
        local ok, a = pcall(function() return p.AccountAge end)
        return ok and (tostring(a).."d") or "?"
    end)())
    add("Membership", (function()
        local ok, m = pcall(function() return p.MembershipType end)
        return ok and tostring(m):gsub("Enum%.MembershipType%.","") or "None"
    end)())

    -- leaderstats
    local ls = scanLeaderstats(p)
    if #ls > 0 then
        add("── leaderstats ──", "", "")
        for _, item in ipairs(ls) do
            table.insert(out, item)
        end
    end

    -- player attributes
    local pAttrs = scanAttrs(p, "[P] ")
    if #pAttrs > 0 then
        add("── Player Attrs ──", "", "")
        for _, item in ipairs(pAttrs) do
            table.insert(out, item)
        end
    end

    -- character data
    local ch = p.Character
    if ch then
        add("── Character ──", "", "")
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            add("  Health", math.floor(hum.Health).."/"..math.floor(hum.MaxHealth))
            add("  WalkSpeed", tostring(math.floor(hum.WalkSpeed)))
            add("  JumpPower", tostring(math.floor(hum.JumpPower or hum.UseJumpPower and hum.JumpPower or 0)))
            add("  State", tostring(hum:GetState()):gsub("Enum%.HumanoidStateType%.",""))
            add("  RigType", tostring(hum.RigType):gsub("Enum%.HumanoidRigType%.",""))
        end
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            local vel = hrp.Velocity
            add("  Position", string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z))
            add("  Velocity", string.format("%.0f, %.0f, %.0f", vel.X, vel.Y, vel.Z))
        end

        -- equipped tools
        local equipped = {}
        for _, c in ipairs(ch:GetChildren()) do
            if c:IsA("Tool") then table.insert(equipped, c.Name) end
        end
        if #equipped > 0 then
            add("  Equipped ("..#equipped..")", table.concat(equipped, ", "))
        else
            add("  Equipped", "(none)")
        end

        -- char attributes
        local cAttrs = scanAttrs(ch, "[C] ")
        if #cAttrs > 0 then
            add("── Char Attrs ──", "", "")
            for _, item in ipairs(cAttrs) do
                table.insert(out, item)
            end
        end
    else
        add("── Character ──", "no character loaded")
    end

    -- backpack
    local bp = p:FindFirstChild("Backpack")
    if bp then
        local items = {}
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") then table.insert(items, c.Name) end
        end
        add("Backpack ("..#items..")", #items > 0 and table.concat(items, ", ") or "(empty)")
    end

    -- PlayerGui
    local pg = p:FindFirstChild("PlayerGui")
    if pg then
        local guis = {}
        for _, c in ipairs(pg:GetChildren()) do
            if c:IsA("ScreenGui") or c:IsA("LayerCollector") then
                table.insert(guis, c.Name)
            end
        end
        if #guis > 0 then
            add("PlayerGui ("..#guis..")", table.concat(guis, ", "))
        end
    end

    -- PlayerScripts
    local ps = p:FindFirstChild("PlayerScripts")
    if ps then
        add("PlayerScripts", #ps:GetChildren().." items")
    end

    -- workspace folder
    local wf = findWorkspaceFolder(p)
    if wf then
        add("── Workspace Folder ──", "", "")
        add("  Name", wf.Name)
        add("  Class", wf.ClassName)
        add("  Children", #wf:GetChildren())
        add("  Total Items", countDesc(wf, 4))
    end

    -- ReplicatedStorage folder
    local rf = findRSFolder(p)
    if rf then
        add("── RS Folder ──", "", "")
        add("  Name", rf.Name)
        add("  Class", rf.ClassName)
        add("  Children", #rf:GetChildren())
        add("  Total Items", countDesc(rf, 4))
    end

    -- Team
    if p.Team then
        add("Team", p.Team.Name.." ("..tostring(p.Team.TeamColor)..")")
    else
        add("Team", "None")
    end

    return out
end

local function makeRow(parent, k, v, copyVal)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -6, 0, 22)
    row.BackgroundColor3 = Color3.fromRGB(35,35,40)
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 110, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = k
    lbl.TextColor3 = Settings.Theme.PlaceholderText
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 11
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(1, -155, 1, 0)
    val.Position = UDim2.new(0, 116, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = tostring(v)
    val.TextColor3 = Settings.Theme.Text
    val.Font = Enum.Font.Code
    val.TextSize = 11
    val.TextTruncate = Enum.TextTruncate.AtEnd
    val.TextXAlignment = Enum.TextXAlignment.Left

    if v ~= "" and tostring(v) ~= "(none)" and tostring(v) ~= "(empty)" and tostring(v) ~= "no character loaded" then
        local cpy = Instance.new("TextButton", row)
        cpy.Size = UDim2.new(0, 26, 0, 18)
        cpy.Position = UDim2.new(1, -30, 0, 2)
        cpy.BackgroundColor3 = Color3.fromRGB(50,90,150)
        cpy.Text = "C"
        cpy.TextColor3 = Color3.fromRGB(255,255,255)
        cpy.Font = Enum.Font.SourceSansBold
        cpy.TextSize = 11
        cpy.BorderSizePixel = 0
        Instance.new("UICorner", cpy).CornerRadius = UDim.new(0, 3)
        cpy.MouseButton1Click:Connect(function()
            copy(copyVal or tostring(v))
            cpy.Text = "OK"
            task.wait(1)
            cpy.Text = "C"
        end)
    end
end

local function createCard(parent, p)
    local holder = Instance.new("Frame", parent)
    holder.Size = UDim2.new(1, -6, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundColor3 = Settings.Theme.Main2
    holder.BorderSizePixel = 0
    holder.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local header = Instance.new("TextButton", holder)
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundTransparency = 1
    header.Text = "  >  "..p.Name
    header.TextColor3 = Settings.Theme.Text
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.AutoButtonColor = false

    local body = Instance.new("Frame", holder)
    body.Size = UDim2.new(1, -12, 0, 0)
    body.Position = UDim2.new(0, 6, 0, 32)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Visible = false
    local bLay = Instance.new("UIListLayout", body)
    bLay.Padding = UDim.new(0, 2)
    bLay.SortOrder = Enum.SortOrder.LayoutOrder

    local built = false

    local function build()
        if built then return end
        built = true
        local info = buildInfo(p)
        for _, item in ipairs(info) do
            makeRow(body, item.k, item.v, item.copy)
        end

        -- search user button
        local sb = Instance.new("TextButton", body)
        sb.Size = UDim2.new(1, -6, 0, 26)
        sb.BackgroundColor3 = Color3.fromRGB(11,90,175)
        sb.Text = "Copy user:"..tostring(p.UserId).." (Browser)"
        sb.TextColor3 = Color3.fromRGB(255,255,255)
        sb.Font = Enum.Font.SourceSansBold
        sb.TextSize = 11
        sb.BorderSizePixel = 0
        Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 5)
        sb.MouseButton1Click:Connect(function()
            copy("user:"..tostring(p.UserId))
            sb.Text = "Copied!"
            task.wait(1.5)
            sb.Text = "Copy user:"..tostring(p.UserId).." (Browser)"
        end)

        -- rescan button
        local rb = Instance.new("TextButton", body)
        rb.Size = UDim2.new(1, -6, 0, 24)
        rb.BackgroundColor3 = Color3.fromRGB(50,130,80)
        rb.Text = "Rescan (refresh data)"
        rb.TextColor3 = Color3.fromRGB(255,255,255)
        rb.Font = Enum.Font.SourceSansBold
        rb.TextSize = 11
        rb.BorderSizePixel = 0
        Instance.new("UICorner", rb).CornerRadius = UDim.new(0, 5)
        rb.MouseButton1Click:Connect(function()
            built = false
            for _, c in ipairs(body:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
            end
            build()
        end)
    end

    header.MouseButton1Click:Connect(function()
        local now = not expanded[p.Name]
        expanded[p.Name] = now
        if now then
            build()
            body.Visible = true
            header.Text = "  v  "..p.Name
        else
            body.Visible = false
            header.Text = "  >  "..p.Name
        end
    end)
end

PE.Init = function()
    window = Lib.Window.new()
    window:SetTitle("Players Explorer")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 340 or 400, isMobile and 440 or 520)
    PE.Window = window

    local refreshBtn = Lib.Button.new()
    refreshBtn.Text = "Refresh"
    refreshBtn.Size = UDim2.new(0, 80, 0, 24)
    refreshBtn.Position = UDim2.new(0, 4, 0, 4)
    refreshBtn.Parent = window.GuiElems.Content

    local expandAllBtn = Lib.Button.new()
    expandAllBtn.Text = "Expand All"
    expandAllBtn.Size = UDim2.new(0, 90, 0, 24)
    expandAllBtn.Position = UDim2.new(0, 90, 0, 4)
    expandAllBtn.Parent = window.GuiElems.Content

    local countLbl = Instance.new("TextLabel", window.GuiElems.Content)
    countLbl.Size = UDim2.new(1, -190, 0, 24)
    countLbl.Position = UDim2.new(0, 186, 0, 4)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = ""
    countLbl.TextColor3 = Settings.Theme.PlaceholderText
    countLbl.Font = Enum.Font.SourceSans
    countLbl.TextSize = 12
    countLbl.TextXAlignment = Enum.TextXAlignment.Left

    content = Instance.new("ScrollingFrame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -40)
    content.Position = UDim2.new(0, 4, 0, 34)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout", content)
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    local function refresh()
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        expanded = {}
        local plrs = service.Players:GetPlayers()
        countLbl.Text = #plrs.." player(s)"
        for _, p in ipairs(plrs) do
            createCard(content, p)
        end
    end

    expandAllBtn.OnClick:Connect(function()
        for _, card in ipairs(content:GetChildren()) do
            if card:IsA("Frame") then
                local header = card:GetChildren()[1]
                if header and header:IsA("TextButton") then
                    local nm = header.Text:gsub("  .  ","")
                    if not expanded[nm] then
                        expanded[nm] = true
                        local body = card:GetChildren()[2]
                        if body then
                            body.Visible = true
                            header.Text = "  v  "..nm
                        end
                    end
                end
            end
        end
    end)

    refreshBtn.OnClick:Connect(refresh)
    service.Players.PlayerAdded:Connect(function() task.wait(0.3) refresh() end)
    service.Players.PlayerRemoving:Connect(function() task.wait(0.3) refresh() end)
    refresh()
end

return PE
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

