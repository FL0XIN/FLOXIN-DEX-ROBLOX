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

-- الأيقونات (Material Icons sprite)
local COPY_ICON_INDEX = 216   -- نسخ
local EDIT_ICON_INDEX = 63    -- قلم
local LOCAL_ICON_INDEX = 181  -- قفل/eye

local function copy(t)
    local ok = false
    if env and env.setclipboard then pcall(function() env.setclipboard(t) ok=true end) end
    if not ok and setclipboard then pcall(function() setclipboard(t) ok=true end) end
    if not ok and toclipboard then pcall(function() toclipboard(t) ok=true end) end
    return ok
end

local function scanLeaderstats(p)
    local list = {}
    local ls = p:FindFirstChild("leaderstats")
    if not ls then return list end
    for _, c in ipairs(ls:GetChildren()) do
        if c:IsA("ValueBase") then
            table.insert(list, {name=c.Name, inst=c, kind="leaderstats"})
        end
    end
    return list
end

local function scanAttrs(inst, prefix, kind)
    local list = {}
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or not attrs then return list end
    for name, val in pairs(attrs) do
        table.insert(list, {name=name, inst=inst, attrName=name, kind=kind or "attr", prefix=prefix or ""})
    end
    return list
end

local function findWorkspaceFolder(p)
    for _, name in ipairs({p.Name, tostring(p.UserId), p.DisplayName}) do
        local f = workspace:FindFirstChild(name)
        if f then return f end
    end
end

local function findRSFolder(p)
    local RS = game:GetService("ReplicatedStorage")
    for _, name in ipairs({p.Name, tostring(p.UserId), p.DisplayName}) do
        local f = RS:FindFirstChild(name)
        if f then return f end
    end
end

local function countDesc(inst, maxDepth)
    maxDepth = maxDepth or 4
    local c = 0
    local function rec(o, d)
        if d > maxDepth then return end
        for _, ch in ipairs(o:GetChildren()) do
            c = c + 1
            if #ch:GetChildren() > 0 then rec(ch, d+1) end
        end
    end
    rec(inst, 0)
    return c
end

-- تحديد نوع القيمة + قابلية التعديل
local function valueInfo(inst, isAttr)
    local t
    if isAttr then
        t = typeof(inst:GetAttribute(isAttr))
    else
        t = typeof(inst.Value)
    end
    local editable = (t == "number" or t == "string" or t == "boolean")
    return t, editable
end

-- قراءة القيمة
local function readVal(item)
    if item.attrName then
        return item.inst:GetAttribute(item.attrName)
    elseif item.inst and item.inst.Value ~= nil then
        return item.inst.Value
    end
    return nil
end

-- كتابة القيمة
local function writeVal(item, newVal, typ)
    if item.attrName then
        item.inst:SetAttribute(item.attrName, newVal)
    elseif item.inst then
        item.inst.Value = newVal
    end
end

-- parse الـ input حسب النوع
local function parseInput(txt, typ)
    if typ == "number" then
        local n = tonumber(txt)
        return n
    elseif typ == "boolean" then
        return txt:lower() == "true"
    elseif typ == "string" then
        return txt
    end
    return nil
end

-- نافذة تعديل القيمة
local function openEditWindow(item, parentCard, onDone)
    local typ, editable = valueInfo(item.inst, item.attrName)
    if not editable then
        return
    end

    local old = readVal(item)

    local dlg = Instance.new("ScreenGui")
    dlg.Name = "FLOXIN_Edit"
    dlg.IgnoreGuiInset = true
    dlg.ResetOnSpawn = false
    dlg.DisplayOrder = 999999
    Lib.ShowGui(dlg)

    local f = Instance.new("Frame", dlg)
    f.Size = UDim2.new(0, 280, 0, 240)
    f.Position = UDim2.new(0.5, -140, 0.5, -120)
    f.BackgroundColor3 = Color3.fromRGB(45,45,45)
    f.BorderSizePixel = 0
    f.Active = true
    f.Draggable = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(30,30,30)

    local title = Instance.new("TextLabel", f)
    title.Size = UDim2.new(1, -20, 0, 24)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Edit: "..item.name
    title.TextColor3 = Color3.fromRGB(230,230,230)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left

    local typeLbl = Instance.new("TextLabel", f)
    typeLbl.Size = UDim2.new(1, -20, 0, 14)
    typeLbl.Position = UDim2.new(0, 10, 0, 32)
    typeLbl.BackgroundTransparency = 1
    typeLbl.Text = "Type: "..typ.."  ·  Old: "..tostring(old)
    typeLbl.TextColor3 = Color3.fromRGB(150,150,155)
    typeLbl.Font = Enum.Font.Code
    typeLbl.TextSize = 11
    typeLbl.TextXAlignment = Enum.TextXAlignment.Left

    local box = Instance.new("TextBox", f)
    box.Size = UDim2.new(1, -20, 0, 30)
    box.Position = UDim2.new(0, 10, 0, 52)
    box.BackgroundColor3 = Color3.fromRGB(38,38,38)
    box.BorderSizePixel = 0
    box.Text = tostring(old)
    box.TextColor3 = Color3.fromRGB(230,230,230)
    box.Font = Enum.Font.Code
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    local bp = Instance.new("UIPadding", box)
    bp.PaddingLeft = UDim.new(0, 6)

    local warnLbl = Instance.new("TextLabel", f)
    warnLbl.Size = UDim2.new(1, -20, 0, 60)
    warnLbl.Position = UDim2.new(0, 10, 0, 90)
    warnLbl.BackgroundColor3 = Color3.fromRGB(60,45,20)
    warnLbl.Text = "⚠ التعديل يحاول يزامن مع السيرفر أولاً.\nلو اللعبة عندها حماية، التعديل هيفضل محلي\n(يظهر عندك بس). دوس OK للتجربة."
    warnLbl.TextColor3 = Color3.fromRGB(255,210,100)
    warnLbl.Font = Enum.Font.SourceSans
    warnLbl.TextSize = 11
    warnLbl.TextWrapped = true
    warnLbl.TextXAlignment = Enum.TextXAlignment.Left
    warnLbl.TextYAlignment = Enum.TextYAlignment.Top
    Instance.new("UICorner", warnLbl).CornerRadius = UDim.new(0, 4)
    local wp = Instance.new("UIPadding", warnLbl)
    wp.PaddingLeft = UDim.new(0, 6); wp.PaddingRight = UDim.new(0, 6)
    wp.PaddingTop = UDim.new(0, 4)

    local okBtn = Instance.new("TextButton", f)
    okBtn.Size = UDim2.new(0.5, -15, 0, 30)
    okBtn.Position = UDim2.new(0, 10, 1, -40)
    okBtn.BackgroundColor3 = Color3.fromRGB(11,90,175)
    okBtn.Text = "OK — تعديل"
    okBtn.TextColor3 = Color3.new(1,1,1)
    okBtn.Font = Enum.Font.SourceSansBold
    okBtn.TextSize = 12
    okBtn.BorderSizePixel = 0
    Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 5)

    local cancelBtn = Instance.new("TextButton", f)
    cancelBtn.Size = UDim2.new(0.5, -15, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 5, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    cancelBtn.Text = "إلغاء"
    cancelBtn.TextColor3 = Color3.new(1,1,1)
    cancelBtn.Font = Enum.Font.SourceSansBold
    cancelBtn.TextSize = 12
    cancelBtn.BorderSizePixel = 0
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 5)

    cancelBtn.MouseButton1Click:Connect(function()
        dlg:Destroy()
    end)

    okBtn.MouseButton1Click:Connect(function()
        local parsed = parseInput(box.Text, typ)
        if parsed == nil then
            box.TextColor3 = Color3.fromRGB(255,100,110)
            box.Text = "قيمة غلط — جرب تاني"
            return
        end
        -- احفظ القيمة القديمة للمقارنة
        local beforeVal = readVal(item)
        pcall(writeVal, item, parsed, typ)
        -- بعد ثانية، نتحقق: هل القيمة اتغيرت محليًا؟
        task.wait(0.6)
        local afterVal = readVal(item)
        local changed = (tostring(afterVal) == tostring(parsed))
        -- حاول نظن لو السيرفر قبِلها — لو القيمة رجعت لأصلها → رفض
        task.wait(0.8)
        local finalVal = readVal(item)
        local stillThere = (tostring(finalVal) == tostring(parsed))
        local statusTxt
        if not changed then
            statusTxt = "❌ فشل التعديل"
        elseif stillThere then
            statusTxt = "✅ LOCAL — القيمة اتغيرت عندك بس (السيرفر رفضها أو مفيش مزامنة)"
        else
            statusTxt = "✅ SERVER — السيرفر وافق والقيمة اتزامنت"
        end
        if onDone then onDone(statusTxt) end
        dlg:Destroy()
    end)
end

-- صف ببيانات
local function makeRow(parent, item, displayName)
    local typ, editable = valueInfo(item.inst, item.attrName)
    local val = readVal(item)

    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -6, 0, 24)
    row.BackgroundColor3 = Color3.fromRGB(35,35,40)
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 108, 1, 0)
    lbl.Position = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = displayName
    lbl.TextColor3 = Settings.Theme.PlaceholderText
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 11
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(1, -190, 1, 0)
    valLbl.Position = UDim2.new(0, 114, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(val)
    valLbl.TextColor3 = Settings.Theme.Text
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 11
    valLbl.TextTruncate = Enum.TextTruncate.AtEnd
    valLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- نوع صغير
    local typeTag = Instance.new("TextLabel", row)
    typeTag.Size = UDim2.new(0, 36, 1, 0)
    typeTag.Position = UDim2.new(1, -76, 0, 0)
    typeTag.BackgroundTransparency = 1
    typeTag.Text = typ
    typeTag.TextColor3 = Color3.fromRGB(120,180,120)
    typeTag.Font = Enum.Font.Code
    typeTag.TextSize = 9
    typeTag.TextXAlignment = Enum.TextXAlignment.Right

    -- زر النسخ (أيقونة)
    local cpy = Instance.new("TextButton", row)
    cpy.Size = UDim2.new(0, 22, 0, 20)
    cpy.Position = UDim2.new(1, -50, 0, 2)
    cpy.BackgroundColor3 = Color3.fromRGB(50,90,150)
    cpy.Text = ""
    cpy.TextColor3 = Color3.new(1,1,1)
    cpy.BorderSizePixel = 0
    cpy.AutoButtonColor = false
    Instance.new("UICorner", cpy).CornerRadius = UDim.new(0, 4)
    local icon1 = Instance.new("ImageLabel", cpy)
    icon1.Size = UDim2.new(0, 16, 0, 16)
    icon1.Position = UDim2.new(0.5, -8, 0.5, -8)
    icon1.BackgroundTransparency = 1
    icon1.Image = "rbxassetid://3926305904"
    icon1.ImageRectOffset = Vector2.new((COPY_ICON_INDEX % 25) * 36, math.floor(COPY_ICON_INDEX / 25) * 36)
    icon1.ImageRectSize = Vector2.new(36, 36)
    cpy.MouseButton1Click:Connect(function()
        copy(tostring(readVal(item)))
        cpy.BackgroundColor3 = Color3.fromRGB(50,150,70)
        task.wait(0.6)
        cpy.BackgroundColor3 = Color3.fromRGB(50,90,150)
    end)

    -- زر التعديل
    if editable then
        local ed = Instance.new("TextButton", row)
        ed.Size = UDim2.new(0, 22, 0, 20)
        ed.Position = UDim2.new(1, -26, 0, 2)
        ed.BackgroundColor3 = Color3.fromRGB(80,130,50)
        ed.Text = ""
        ed.BorderSizePixel = 0
        ed.AutoButtonColor = false
        Instance.new("UICorner", ed).CornerRadius = UDim.new(0, 4)
        local icon2 = Instance.new("ImageLabel", ed)
        icon2.Size = UDim2.new(0, 16, 0, 16)
        icon2.Position = UDim2.new(0.5, -8, 0.5, -8)
        icon2.BackgroundTransparency = 1
        icon2.Image = "rbxassetid://3926305904"
        icon2.ImageRectOffset = Vector2.new((EDIT_ICON_INDEX % 25) * 36, math.floor(EDIT_ICON_INDEX / 25) * 36)
        icon2.ImageRectSize = Vector2.new(36, 36)
        ed.MouseButton1Click:Connect(function()
            openEditWindow(item, row, function(statusTxt)
                valLbl.Text = tostring(readVal(item))
                -- صف حالة صغير
                local statusRow = Instance.new("TextLabel", parent)
                statusRow.Size = UDim2.new(1, -6, 0, 16)
                statusRow.BackgroundTransparency = 1
                statusRow.LayoutOrder = #parent:GetChildren()
                statusRow.Text = statusTxt
                statusRow.TextColor3 = Color3.fromRGB(200,200,220)
                statusRow.Font = Enum.Font.Code
                statusRow.TextSize = 10
                statusRow.TextXAlignment = Enum.TextXAlignment.Left
                task.delay(4, function() if statusRow.Parent then statusRow:Destroy() end end)
            end)
        end)
    end
end

local function buildInfo(p)
    local out = {}
    local function push(name, item)
        table.insert(out, {name=name, item=item})
    end

    -- leaderstats
    for _, item in ipairs(scanLeaderstats(p)) do
        push("[LS] "..item.name, item)
    end

    -- Player attrs
    for _, item in ipairs(scanAttrs(p, "[P] ", "pattr")) do
        push("[P] "..item.name, item)
    end

    -- Character attrs
    local ch = p.Character
    if ch then
        for _, item in ipairs(scanAttrs(ch, "[C] ", "cattr")) do
            push("[C] "..item.name, item)
        end
    end

    return out
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

        local list = buildInfo(p)
        if #list == 0 then
            local empty = Instance.new("TextLabel", body)
            empty.Size = UDim2.new(1, -6, 0, 20)
            empty.BackgroundTransparency = 1
            empty.Text = "(no editable values found)"
            empty.TextColor3 = Settings.Theme.PlaceholderText
            empty.Font = Enum.Font.SourceSans
            empty.TextSize = 11
            empty.TextXAlignment = Enum.TextXAlignment.Left
        end
        for _, entry in ipairs(list) do
            makeRow(body, entry.item, entry.name)
        end

        -- copy user:ID
        local sb = Instance.new("TextButton", body)
        sb.Size = UDim2.new(1, -6, 0, 26)
        sb.BackgroundColor3 = Color3.fromRGB(11,90,175)
        sb.Text = "Copy user:"..tostring(p.UserId).." (Browser)"
        sb.TextColor3 = Color3.new(1,1,1)
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

        local rb = Instance.new("TextButton", body)
        rb.Size = UDim2.new(1, -6, 0, 24)
        rb.BackgroundColor3 = Color3.fromRGB(50,130,80)
        rb.Text = "Rescan"
        rb.TextColor3 = Color3.new(1,1,1)
        rb.Font = Enum.Font.SourceSansBold
        rb.TextSize = 11
        rb.BorderSizePixel = 0
        Instance.new("UICorner", rb).CornerRadius = UDim.new(0, 5)
        rb.MouseButton1Click:Connect(function()
            built = false
            for _, c in ipairs(body:GetChildren()) do
                if c:IsA("Frame") or c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
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
    window:Resize(isMobile and 340 or 400, isMobile and 460 or 540)
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

