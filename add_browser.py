with open('dex.source.lua', 'r', encoding='utf-8') as f:
    src = f.read()

BROWSER = '''["Browser"] = function()
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
local Browser={}
local window,urlBox,statusLbl,viewFrame,pageFrame
local history,historyIdx={},0
local orderN=0
local function nextOrder() orderN=orderN+1 return orderN end
local SKIP={script=1,style=1,head=1,meta=1,link=1,noscript=1,iframe=1,svg=1,video=1,audio=1,canvas=1}
local BLOCK={p=1,div=1,h1=1,h2=1,h3=1,h4=1,h5=1,h6=1,li=1,ul=1,ol=1,br=1,hr=1,section=1,article=1,header=1,footer=1,nav=1,table=1,tr=1,blockquote=1,pre=1}
local H_SIZE={h1=22,h2=20,h3=18,h4=16,h5=14,h6=13}
local function decode(s)
    s=s:gsub("&nbsp;"," "):gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
    s=s:gsub("&quot;",'"'):gsub("&#39;","'"):gsub("&apos;","'")
    s=s:gsub("&#(%d+);",function(n) return utf8.char(tonumber(n) or 63) end)
    return s
end
local function tokenize(html)
    local tokens={}
    local i,n=1,#html
    local skip=nil
    while i<=n do
        local lt=html:find("<",i,true)
        if not lt then
            if i<=n then table.insert(tokens,{type="text",content=html:sub(i)}) end
            break
        end
        if lt>i then table.insert(tokens,{type="text",content=html:sub(i,lt-1)}) end
        local gt=html:find(">",lt,true)
        if not gt then break end
        local raw=html:sub(lt+1,gt-1)
        local isClose=raw:sub(1,1)=="/"
        local isSelf=raw:sub(-1)=="/"
        local body=raw:gsub("^/",""):gsub("/$","")
        local tagName=(body:match("^([%w%-]+)") or ""):lower()
        if skip then
            if isClose and tagName==skip then skip=nil end
        elseif SKIP[tagName] and not isClose then
            skip=tagName
        else
            local attrs={}
            for k,v in body:gmatch('([%w%-]+)%s*=%s*"([^"]*)"') do attrs[k:lower()]=v end
            for k,v in body:gmatch("([%w%-]+)%s*=%s*'([^']*)'") do attrs[k:lower()]=v end
            table.insert(tokens,{type=isClose and "close" or "open",tag=tagName,attrs=attrs,selfClose=isSelf})
        end
        i=gt+1
    end
    return tokens
end
local function clearPage()
    if not pageFrame then return end
    for _,c in ipairs(pageFrame:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    orderN=0
end
local function pushBlock(text,opts)
    opts=opts or {}
    local f=Instance.new("Frame",pageFrame)
    f.Size=UDim2.new(1,0,0,0)
    f.AutomaticSize=Enum.AutomaticSize.Y
    f.BackgroundTransparency=1
    f.LayoutOrder=nextOrder()
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,0,0)
    l.AutomaticSize=Enum.AutomaticSize.Y
    l.BackgroundTransparency=1
    l.Text=text
    l.TextColor3=opts.color or Color3.fromRGB(30,30,30)
    l.Font=opts.bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
    l.TextSize=opts.size or 14
    l.TextWrapped=true
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Top
end
local function normalizeUrl(u)
    u=(u or ""):gsub("%s+","")
    if u=="" then return nil end
    if not u:match("^https?://") then u="https://"..u end
    return u
end
local function resolveUrl(href,base)
    if not href or href=="" then return nil end
    if href:match("^https?://") then return href end
    if href:sub(1,2)=="//" then return "https:"..href end
    if href:sub(1,1)=="/" then
        return (base:match("^(https?://[^/]+)") or "")..href
    end
    return (base:match("^(https?://.+/)") or base)..href
end
local navigate
local function render(tokens,baseUrl)
    clearPage()
    local stack={}
    local pending={}
    local function flush()
        if #pending==0 then return end
        local text=decode(table.concat(pending," "))
        text=text:gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
        pending={}
        if text=="" then return end
        local ctx=stack[#stack]
        if ctx and ctx.tag=="a" and ctx.href then
            local abs=resolveUrl(ctx.href,baseUrl)
            local f=Instance.new("Frame",pageFrame)
            f.Size=UDim2.new(1,0,0,0)
            f.AutomaticSize=Enum.AutomaticSize.Y
            f.BackgroundTransparency=1
            f.LayoutOrder=nextOrder()
            local b=Instance.new("TextButton",f)
            b.Size=UDim2.new(1,0,0,0)
            b.AutomaticSize=Enum.AutomaticSize.Y
            b.BackgroundTransparency=1
            b.Text="> "..text
            b.TextColor3=Color3.fromRGB(60,120,220)
            b.Font=Enum.Font.SourceSans
            b.TextSize=14
            b.TextWrapped=true
            b.TextXAlignment=Enum.TextXAlignment.Left
            b.AutoButtonColor=false
            b.MouseButton1Click:Connect(function() if abs then navigate(abs) end end)
        elseif ctx and H_SIZE[ctx.tag] then
            pushBlock(text,{size=H_SIZE[ctx.tag],bold=true,color=Color3.fromRGB(10,10,10)})
        else
            pushBlock(text,{size=14})
        end
    end
    for _,tk in ipairs(tokens) do
        if tk.type=="text" then
            table.insert(pending,tk.content)
        elseif tk.type=="open" then
            local t=tk.tag
            if t=="br" then
                flush()
            elseif t=="hr" then
                flush()
                local hr=Instance.new("Frame",pageFrame)
                hr.Size=UDim2.new(1,0,0,1)
                hr.BackgroundColor3=Color3.fromRGB(200,200,200)
                hr.BorderSizePixel=0
                hr.LayoutOrder=nextOrder()
            elseif BLOCK[t] or t=="a" then
                if BLOCK[t] then flush() end
                table.insert(stack,{tag=t,href=tk.attrs.href})
                if tk.selfClose then table.remove(stack) end
            end
        elseif tk.type=="close" then
            if BLOCK[tk.tag] then flush() end
            for i=#stack,1,-1 do
                if stack[i].tag==tk.tag then
                    table.remove(stack,i)
                    break
                end
            end
        end
    end
    flush()
    if #pageFrame:GetChildren()<=1 then
        pushBlock("(empty page)",{color=Color3.fromRGB(150,150,150)})
    end
end
navigate=function(url)
    url=normalizeUrl(url)
    if not url then return end
    if urlBox then urlBox:SetText(url) end
    if statusLbl then statusLbl.Text="Loading..." end
    clearPage()
    task.spawn(function()
        local ok,html=pcall(function() return game:HttpGet(url) end)
        if not ok or not html then
            pushBlock("Failed to load "..url,{color=Color3.fromRGB(200,60,60)})
            if statusLbl then statusLbl.Text="Failed" end
            return
        end
        if statusLbl then statusLbl.Text=#html.." bytes" end
        local tokens=tokenize(html)
        render(tokens,url)
        historyIdx=historyIdx+1
        history[historyIdx]=url
        for i=historyIdx+1,#history do history[i]=nil end
    end)
end
Browser.Init=function()
    window=Lib.Window.new()
    window:SetTitle("Browser")
    window:Resize(460,520)
    Browser.Window=window
    local content=window.GuiElems.Content
    local tb=Instance.new("Frame",content)
    tb.Size=UDim2.new(1,0,0,30)
    tb.BackgroundColor3=Settings.Theme.Main1
    tb.BorderSizePixel=0
    local function navBtn(txt,x,cb)
        local b=Lib.Button.new()
        b.Text=txt
        b.Size=UDim2.new(0,24,0,22)
        b.Position=UDim2.new(0,x,0,4)
        b.Parent=tb
        b.OnClick:Connect(cb)
    end
    navBtn("<",4,function()
        if historyIdx>1 then historyIdx=historyIdx-1 navigate(history[historyIdx]) end
    end)
    navBtn(">",30,function()
        if historyIdx<#history then historyIdx=historyIdx+1 navigate(history[historyIdx]) end
    end)
    navBtn("H",56,function() navigate("https://example.com") end)
    navBtn("R",82,function() if history[historyIdx] then navigate(history[historyIdx]) end end)
    local ub=Lib.ViewportTextBox.new()
    ub.Position=UDim2.new(0,110,0,4)
    ub.Size=UDim2.new(1,-160,0,22)
    ub.Parent=tb
    ub:SetText("")
    urlBox=ub
    ub.TextBox.FocusLost:Connect(function(enter) if enter then navigate(ub:GetText()) end end)
    local gb=Lib.Button.new()
    gb.Text="Go"
    gb.Size=UDim2.new(0,40,0,22)
    gb.Position=UDim2.new(1,-46,0,4)
    gb.Parent=tb
    gb.OnClick:Connect(function() navigate(ub:GetText()) end)
    statusLbl=Instance.new("TextLabel",content)
    statusLbl.Size=UDim2.new(1,0,0,14)
    statusLbl.Position=UDim2.new(0,2,0,32)
    statusLbl.BackgroundTransparency=1
    statusLbl.Text="Ready"
    statusLbl.TextColor3=Settings.Theme.PlaceholderText
    statusLbl.Font=Enum.Font.SourceSans
    statusLbl.TextSize=11
    statusLbl.TextXAlignment=Enum.TextXAlignment.Left
    viewFrame=Instance.new("ScrollingFrame",content)
    viewFrame.Size=UDim2.new(1,0,1,-54)
    viewFrame.Position=UDim2.new(0,0,0,48)
    viewFrame.BackgroundColor3=Color3.fromRGB(250,250,250)
    viewFrame.BorderSizePixel=0
    viewFrame.ScrollBarThickness=6
    viewFrame.ScrollBarImageColor3=Color3.fromRGB(120,120,120)
    viewFrame.CanvasSize=UDim2.new(0,0,0,0)
    pageFrame=Instance.new("Frame",viewFrame)
    pageFrame.Size=UDim2.new(1,-8,0,0)
    pageFrame.Position=UDim2.new(0,4,0,4)
    pageFrame.AutomaticSize=Enum.AutomaticSize.Y
    pageFrame.BackgroundTransparency=1
    local vl=Instance.new("UIListLayout",pageFrame)
    vl.Padding=UDim.new(0,4)
    vl.SortOrder=Enum.SortOrder.LayoutOrder
    pageFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        viewFrame.CanvasSize=UDim2.new(0,0,0,pageFrame.AbsoluteSize.Y+12)
    end)
    task.delay(0.3,function()
        pcall(function() navigate("https://example.com") end)
    end)
end
return Browser
end

'''

# 1. Insert module
marker = '["Console"] = function()'
assert marker in src, "marker Console not found"
src = src.replace(marker, BROWSER + marker, 1)
print("[1] module inserted")

# 2. ModuleList - match the actual line with BulkCopier
old = 'Main.ModuleList = {"Explorer","Properties","ScriptViewer","Console","SaveInstance","ModelViewer","BulkCopier"}'
new = 'Main.ModuleList = {"Explorer","Properties","ScriptViewer","Console","SaveInstance","ModelViewer","BulkCopier","Browser"}'
assert old in src, "ModuleList not found"
src = src.replace(old, new, 1)
print("[2] ModuleList updated")

# 3. apps assignment (line ~14276)
old = 'ModelViewer = Apps.ModelViewer\n'
cnt = src.count(old)
print("[3] Apps.ModelViewer count:", cnt)
# target the second occurrence (in LoadModules)
parts = src.split(old)
if len(parts) >= 3:
    # rebuild with insert on second occurrence
    src = parts[0] + old + parts[1] + old + 'Browser = Apps.Browser\n' + old.join(parts[2:])
    print("[3] apps assignment patched (2nd occurrence)")

# 4. appTable (line ~14287)
old = 'ModelViewer = ModelViewer,\n'
if old in src:
    src = src.replace(old, old + '\t\t\t\tBrowser = Browser,\n', 1)
    print("[4] appTable patched")

# 5. Init call (line ~15391)
old = 'ModelViewer.Init()\n'
if old in src:
    src = src.replace(old, old + '\t\tBrowser.Init()\n', 1)
    print("[5] Init patched")

# 6. CreateApp for icon (line ~15270)
old = 'Main.CreateApp({Name = "3D Viewer", IconMap = Explorer.LegacyClassIcons, Icon = 54, Window = ModelViewer.Window})'
if old in src:
    src = src.replace(old, old + '\n\t\tMain.CreateApp({Name = "Browser", IconMap = Main.MiscIcons, Icon = "Reference", Window = Browser.Window})', 1)
    print("[6] Icon added")

with open('dex.source.lua', 'w', encoding='utf-8') as f:
    f.write(src)

print("SIZE:", len(src))
print("SUCCESS")
