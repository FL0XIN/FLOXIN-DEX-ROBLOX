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
local expandedState = {}

local function buildInfo(p)
    local info = {}
    info.Name = p.Name
    info.DisplayName = p.DisplayName or p.Name
    info.UserId = tostring(p.UserId)
    local ok, age = pcall(function() return p.AccountAge end)
    info.AccountAge = ok and (tostring(age).." days") or "?"
    local ok2, team = pcall(function() return p.Team end)
    info.Team = (ok2 and team and team.Name) or "None"
    local char = p.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            info.Health = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
        else
            info.Health = "?"
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            info.Position = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
        else
            info.Position = "?"
        end
    else
        info.Health = "-"
        info.Position = "-"
    end
    return info
end

local function createRow(parent, p)
    local holder = Instance.new("Frame", parent)
    holder.Size = UDim2.new(1, -6, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.BackgroundColor3 = Settings.Theme.Main2
    holder.BorderSizePixel = 0
    holder.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 5)

    local header = Instance.new("TextButton", holder)
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundTransparency = 1
    header.Text = "  "..p.Name
    header.TextColor3 = Settings.Theme.Text
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.AutoButtonColor = false

    local body = Instance.new("Frame", holder)
    body.Size = UDim2.new(1, -12, 0, 0)
    body.Position = UDim2.new(0, 8, 0, 26)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Visible = false
    local bodyLay = Instance.new("UIListLayout", body)
    bodyLay.Padding = UDim.new(0, 2)

    local expanded = expandedState[p.Name] or false

    local function rebuildBody()
        for _, c in ipairs(body:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        local info = buildInfo(p)
        local order = {
            {"UserID", info.UserId},
            {"DisplayName", info.DisplayName},
            {"AccountAge", info.AccountAge},
            {"Team", info.Team},
            {"Health", info.Health},
            {"Position", info.Position},
        }
        for _, kv in ipairs(order) do
            local lbl = Instance.new("TextLabel", body)
            lbl.Size = UDim2.new(1, 0, 0, 15)
            lbl.BackgroundTransparency = 1
            lbl.Text = "    "..kv[1]..": "..tostring(kv[2])
            lbl.TextColor3 = Settings.Theme.PlaceholderText
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
        end
    end

    header.MouseButton1Click:Connect(function()
        expanded = not expanded
        expandedState[p.Name] = expanded
        if expanded then
            rebuildBody()
            body.Visible = true
            header.Text = "  "..p.Name.."  v"
        else
            body.Visible = false
            header.Text = "  "..p.Name
        end
    end)

    if expanded then
        rebuildBody()
        body.Visible = true
        header.Text = "  "..p.Name.."  v"
    end
end

PE.Init = function()
    window = Lib.Window.new()
    window:SetTitle("Players Explorer")
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 300 or 360, isMobile and 380 or 460)
    PE.Window = window

    local refreshBtn = Lib.Button.new()
    refreshBtn.Text = "Refresh"
    refreshBtn.Size = UDim2.new(0, 80, 0, 22)
    refreshBtn.Position = UDim2.new(0, 4, 0, 4)
    refreshBtn.Parent = window.GuiElems.Content

    local countLbl = Instance.new("TextLabel", window.GuiElems.Content)
    countLbl.Size = UDim2.new(1, -100, 0, 22)
    countLbl.Position = UDim2.new(0, 90, 0, 4)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = ""
    countLbl.TextColor3 = Settings.Theme.PlaceholderText
    countLbl.Font = Enum.Font.SourceSans
    countLbl.TextSize = 12
    countLbl.TextXAlignment = Enum.TextXAlignment.Left

    content = Instance.new("ScrollingFrame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -38)
    content.Position = UDim2.new(0, 4, 0, 32)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout", content)
    lay.Padding = UDim.new(0, 4)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    local function refresh()
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local plrs = service.Players:GetPlayers()
        countLbl.Text = #plrs.." player(s)"
        for _, p in ipairs(plrs) do
            createRow(content, p)
        end
    end

    refreshBtn.OnClick:Connect(refresh)
    service.Players.PlayerAdded:Connect(function() task.wait(0.2) refresh() end)
    service.Players.PlayerRemoving:Connect(function() task.wait(0.2) refresh() end)
    refresh()
end

return PE
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

