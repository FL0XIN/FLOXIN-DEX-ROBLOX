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
local HttpSvc = game:GetService("HttpService")
local localPlayer = service.Players.LocalPlayer

local function copy(t)
    local ok = false
    if env and env.setclipboard then pcall(function() env.setclipboard(t) ok=true end) end
    if not ok and setclipboard then pcall(function() setclipboard(t) ok=true end) end
    if not ok and toclipboard then pcall(function() toclipboard(t) ok=true end) end
    return ok
end

local function fetchJson(url)
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or not raw then return nil end
    local s, d = pcall(function() return HttpSvc:JSONDecode(raw) end)
    return s and d or nil
end

local function getPlayerInfo(p)
    local t = {}
    t["UserId"] = tostring(p.UserId)
    t["Name"] = p.Name
    t["DisplayName"] = p.DisplayName or p.Name
    local ageOk, age = pcall(function() return p.AccountAge end)
    t["AccountAge"] = ageOk and (tostring(age).." days") or "?"
    local mtOk, mt = pcall(function() return p.MembershipType end)
    t["Membership"] = mtOk and tostring(mt):gsub("Enum%.MembershipType%.","") or "None"
    local teamOk, team = pcall(function() return p.Team end)
    t["Team"] = (teamOk and team and team.Name) or "None"
    local chOk, ch = pcall(function() return p.Character end)
    if chOk and ch then
        t["HasCharacter"] = "yes"
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            t["Health"] = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)
            t["WalkSpeed"] = tostring(math.floor(hum.WalkSpeed))
            t["RigType"] = tostring(hum.RigType):gsub("Enum%.HumanoidRigType%.","")
        else
            t["Health"] = "?"
        end
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            t["Position"] = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
        else
            t["Position"] = "?"
        end
    else
        t["HasCharacter"] = "no"
        t["Health"] = "-"
    end
    local fr = pcall(function() return p:IsFriendsWith(localPlayer.UserId) end)
    t["FriendWithMe"] = fr and "yes" or "no"
    return t
end

local function makeRow(parent, label, value, copyText, extraBtn, extraCb)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -6, 0, 22)
    row.BackgroundColor3 = Color3.fromRGB(35,35,40)
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 95, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Settings.Theme.PlaceholderText
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel", row)
    val.Size = UDim2.new(1, -150, 1, 0)
    val.Position = UDim2.new(0, 102, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = tostring(value)
    val.TextColor3 = Settings.Theme.Text
    val.Font = Enum.Font.Code
    val.TextSize = 11
    val.TextTruncate = Enum.TextTruncate.AtEnd
    val.TextXAlignment = Enum.TextXAlignment.Left

    local cpy = Instance.new("TextButton", row)
    cpy.Size = UDim2.new(0, 22, 0, 18)
    cpy.Position = UDim2.new(1, -46, 0, 2)
    cpy.BackgroundColor3 = Color3.fromRGB(50,90,150)
    cpy.Text = "C"
    cpy.TextColor3 = Color3.fromRGB(255,255,255)
    cpy.Font = Enum.Font.SourceSansBold
    cpy.TextSize = 11
    cpy.BorderSizePixel = 0
    Instance.new("UICorner", cpy).CornerRadius = UDim.new(0, 3)
    cpy.MouseButton1Click:Connect(function()
        copy(copyText or tostring(value))
        cpy.Text = "OK"
        task.wait(1)
        cpy.Text = "C"
    end)

    if extraBtn and extraCb then
        local ex = Instance.new("TextButton", row)
        ex.Size = UDim2.new(0, 22, 0, 18)
        ex.Position = UDim2.new(1, -22, 0, 2)
        ex.BackgroundColor3 = Color3.fromRGB(50,130,80)
        ex.Text = extraBtn
        ex.TextColor3 = Color3.fromRGB(255,255,255)
        ex.Font = Enum.Font.SourceSansBold
        ex.TextSize = 10
        ex.BorderSizePixel = 0
        Instance.new("UICorner", ex).CornerRadius = UDim.new(0, 3)
        ex.MouseButton1Click:Connect(extraCb)
    end
end

local function makeBigBtn(parent, text, color, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0.5, -4, 0, 26)
    b.Position = UDim2.new(#parent:GetChildren() % 2 == 0 and 0 or 0.5, 4, 0, 0)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 11
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.MouseButton1Click:Connect(cb)
    return b
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
    header.Text = "  v  "..p.Name
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
    bLay.Padding = UDim.new(0, 3)

    local built = false
    local function build()
        if built then return end
        built = true
        local info = getPlayerInfo(p)
        local order = {
            "UserId", "Name", "DisplayName", "AccountAge", "Membership",
            "Team", "FriendWithMe", "HasCharacter", "Health", "WalkSpeed",
            "RigType", "Position",
        }
        for _, k in ipairs(order) do
            if info[k] then
                makeRow(body, k, info[k], tostring(info[k]))
            end
        end
        -- buttons
        local searchBtn = Instance.new("TextButton", body)
        searchBtn.Size = UDim2.new(1, -6, 0, 26)
        searchBtn.BackgroundColor3 = Color3.fromRGB(11,90,175)
        searchBtn.Text = "Copy 'user:"..tostring(p.UserId).."' for Browser"
        searchBtn.TextColor3 = Color3.fromRGB(255,255,255)
        searchBtn.Font = Enum.Font.SourceSansBold
        searchBtn.TextSize = 11
        searchBtn.BorderSizePixel = 0
        Instance.new("UICorner", searchBtn).CornerRadius = UDim.new(0, 5)
        searchBtn.MouseButton1Click:Connect(function()
            copy("user:"..tostring(p.UserId))
            searchBtn.Text = "Copied!"
            task.wait(1.5)
            searchBtn.Text = "Copy 'user:"..tostring(p.UserId).."' for Browser"
        end)

        local copyNameBtn = Instance.new("TextButton", body)
        copyNameBtn.Size = UDim2.new(1, -6, 0, 24)
        copyNameBtn.BackgroundColor3 = Color3.fromRGB(60,60,70)
        copyNameBtn.Text = "Copy player Name"
        copyNameBtn.TextColor3 = Settings.Theme.Text
        copyNameBtn.Font = Enum.Font.SourceSans
        copyNameBtn.TextSize = 11
        copyNameBtn.BorderSizePixel = 0
        Instance.new("UICorner", copyNameBtn).CornerRadius = UDim.new(0, 5)
        copyNameBtn.MouseButton1Click:Connect(function()
            copy(p.Name)
            copyNameBtn.Text = "Copied!"
            task.wait(1.2)
            copyNameBtn.Text = "Copy player Name"
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
    window:Resize(isMobile and 320 or 380, isMobile and 420 or 480)
    PE.Window = window

    local refreshBtn = Lib.Button.new()
    refreshBtn.Text = "Refresh"
    refreshBtn.Size = UDim2.new(0, 80, 0, 24)
    refreshBtn.Position = UDim2.new(0, 4, 0, 4)
    refreshBtn.Parent = window.GuiElems.Content

    local countLbl = Instance.new("TextLabel", window.GuiElems.Content)
    countLbl.Size = UDim2.new(1, -100, 0, 24)
    countLbl.Position = UDim2.new(0, 90, 0, 4)
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

    refreshBtn.OnClick:Connect(refresh)
    service.Players.PlayerAdded:Connect(function() task.wait(0.3) refresh() end)
    service.Players.PlayerRemoving:Connect(function() task.wait(0.3) refresh() end)
    refresh()
end

return PE
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

