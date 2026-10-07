["CopperExplorer"] = function()
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
local CE = {}
local window, content

local function createRow(parent, p)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -6, 0, 38)
    row.BackgroundColor3 = Settings.Theme.Main2
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local name = Instance.new("TextLabel", row)
    name.Size = UDim2.new(1, -12, 0, 18)
    name.Position = UDim2.new(0, 6, 0, 2)
    name.BackgroundTransparency = 1
    name.Text = p.Name
    name.TextColor3 = Settings.Theme.Text
    name.Font = Enum.Font.SourceSansBold
    name.TextSize = 13
    name.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", row)
    sub.Size = UDim2.new(1, -12, 0, 16)
    sub.Position = UDim2.new(0, 6, 0, 20)
    sub.BackgroundTransparency = 1
    local char = p.Character
    local hp = "-"
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hp = math.floor(hum.Health).."/"..math.floor(hum.MaxHealth) end
    end
    sub.Text = "ID: "..p.UserId.."  ·  HP: "..hp.."  ·  Age: "..p.AccountAge.."d"
    sub.TextColor3 = Settings.Theme.PlaceholderText
    sub.Font = Enum.Font.Code
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
end

CE.Init = function()
    window = Lib.Window.new()
    window:SetTitle("Copper Explorer · Players")
    local vp = workspace.CurrentCamera.ViewportSize
    local isMobile = game:GetService("UserInputService").TouchEnabled
    window:Resize(isMobile and 300 or 340, isMobile and 340 or 420)
    CE.Window = window

    local refreshBtn = Lib.Button.new()
    refreshBtn.Text = "Refresh"
    refreshBtn.Size = UDim2.new(0, 80, 0, 22)
    refreshBtn.Position = UDim2.new(0, 4, 0, 4)
    refreshBtn.Parent = window.GuiElems.Content

    local count = Instance.new("TextLabel", window.GuiElems.Content)
    count.Size = UDim2.new(1, -100, 0, 22)
    count.Position = UDim2.new(0, 90, 0, 4)
    count.BackgroundTransparency = 1
    count.Text = ""
    count.TextColor3 = Settings.Theme.PlaceholderText
    count.Font = Enum.Font.SourceSans
    count.TextSize = 12
    count.TextXAlignment = Enum.TextXAlignment.Left

    content = Instance.new("ScrollingFrame", window.GuiElems.Content)
    content.Size = UDim2.new(1, -8, 1, -38)
    content.Position = UDim2.new(0, 4, 0, 32)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local lay = Instance.new("UIListLayout", content)
    lay.Padding = UDim.new(0, 3)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    local function refresh()
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local plrs = service.Players:GetPlayers()
        count.Text = #plrs.." player(s)"
        for _, p in ipairs(plrs) do
            createRow(content, p)
        end
    end

    refreshBtn.OnClick:Connect(refresh)
    service.Players.PlayerAdded:Connect(function() task.wait(0.2) refresh() end)
    service.Players.PlayerRemoving:Connect(function() task.wait(0.2) refresh() end)
    refresh()
end

return CE
end

