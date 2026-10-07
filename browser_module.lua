["Browser"] = function()
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
local HttpSvc=game:GetService("HttpService")
local window,contentHolder,urlBox
local activeTab="WEB"
local navigate

local function httpGet(url,timeout)
    timeout=timeout or 10
    local done,ok,data=false,false,nil
    task.spawn(function()
        local s,r=pcall(function() return game:HttpGet(url) end)
        if s and type(r)=="string" and #r>0 then ok=true data=r end
        done=true
    end)
    local t0=tick()
    while not done and (tick()-t0)<timeout do task.wait(0.1) end
    return ok,data
end

local function httpPost(url,body,extra,timeout)
    timeout=timeout or 10
    if not request then return false,nil end
    local done,ok,res=false,false,nil
    task.spawn(function()
        local h={["Content-Type"]="application/json"}
        if extra then for k,v in pairs(extra) do h[k]=v end end
        local s,r=pcall(function() return request({Url=url,Method="POST",Headers=h,Body=HttpSvc:JSONEncode(body)}) end)
        if s and type(r)=="table" then ok=true res=r end
        done=true
    end)
    local t0=tick()
    while not done and (tick()-t0)<timeout do task.wait(0.1) end
    return ok,res
end

local function fetchJson(url)
    local ok,raw=httpGet(url,10)
    if not ok or not raw then return nil end
    local s,d=pcall(function() return HttpSvc:JSONDecode(raw) end)
    return s and d or nil
end

local function fmt(n)
    n=tonumber(n) or 0
    if n>=1e9 then return string.format("%.1fB",n/1e9) end
    if n>=1e6 then return string.format("%.1fM",n/1e6) end
    if n>=1e3 then return string.format("%.1fK",n/1e3) end
    return tostring(n)
end

local function clearContent()
    if not contentHolder then return end
    for _,c in ipairs(contentHolder:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("ImageLabel") or c:IsA("ScrollingFrame") then c:Destroy() end
    end
end

local function newScroll()
    local s=Instance.new("ScrollingFrame",contentHolder)
    s.Size=UDim2.new(1,0,1,0)
    s.BackgroundTransparency=1
    s.BorderSizePixel=0
    s.ScrollBarThickness=4
    s.ScrollBarImageColor3=Color3.fromRGB(70,70,70)
    s.CanvasSize=UDim2.new(0,0,0,0)
    local lay=Instance.new("UIListLayout",s)
    lay.Padding=UDim.new(0,4)
    lay.SortOrder=Enum.SortOrder.LayoutOrder
    s:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        s.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+10)
    end)
    return s
end

local function addSection(scroll,text)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,-6,0,20)
    f.BackgroundTransparency=1
    f.LayoutOrder=#scroll:GetChildren()
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,1,0)
    l.BackgroundTransparency=1
    l.Text=text
    l.TextColor3=Settings.Theme.Text
    l.Font=Enum.Font.SourceSansBold
    l.TextSize=13
    l.TextXAlignment=Enum.TextXAlignment.Left
end

local function addBlock(scroll,text,opts)
    opts=opts or {}
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,-6,0,0)
    f.AutomaticSize=Enum.AutomaticSize.Y
    f.BackgroundTransparency=1
    f.LayoutOrder=#scroll:GetChildren()
    local l=Instance.new("TextLabel",f)
    l.Size=UDim2.new(1,0,0,0)
    l.AutomaticSize=Enum.AutomaticSize.Y
    l.BackgroundTransparency=1
    l.Text=tostring(text)
    l.TextColor3=opts.color or Settings.Theme.Text
    l.TextTransparency=opts.trans or 0.1
    l.Font=opts.bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
    l.TextSize=opts.size or 13
    l.TextWrapped=true
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextYAlignment=Enum.TextYAlignment.Top
end

local function addLink(scroll,text,cb)
    local b=Lib.Button.new()
    b.Text="  -> "..text
    b.Size=UDim2.new(1,-6,0,22)
    b.TextXAlignment=Enum.TextXAlignment.Left
    b.Parent=scroll
    b.OnClick:Connect(function() if cb then pcall(cb) end end)
end

local function addKV(scroll,key,value)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,-6,0,0)
    f.AutomaticSize=Enum.AutomaticSize.Y
    f.BackgroundTransparency=1
    f.LayoutOrder=#scroll:GetChildren()
    local k=Instance.new("TextLabel",f)
    k.Size=UDim2.new(0,95,0,16)
    k.BackgroundTransparency=1
    k.Text=tostring(key)..":"
    k.TextColor3=Settings.Theme.PlaceholderText
    k.Font=Enum.Font.SourceSansBold
    k.TextSize=12
    k.TextXAlignment=Enum.TextXAlignment.Left
    local v=Instance.new("TextLabel",f)
    v.Size=UDim2.new(1,-100,0,0)
    v.Position=UDim2.new(0,100,0,0)
    v.AutomaticSize=Enum.AutomaticSize.Y
    v.BackgroundTransparency=1
    v.Text=tostring(value)
    v.TextColor3=Settings.Theme.Text
    v.TextTransparency=0.1
    v.Font=Enum.Font.SourceSans
    v.TextSize=12
    v.TextWrapped=true
    v.TextXAlignment=Enum.TextXAlignment.Left
    v.TextYAlignment=Enum.TextYAlignment.Top
end

local VT={AvatarHeadShot=1,AvatarBust=1,Avatar=1,GameIcon=1,GroupIcon=1,BadgeIcon=1,Outfit=1}
local function addThumb(scroll,kind,id,sizeY)
    if not VT[kind] then kind="AvatarHeadShot" end
    local s=sizeY or 110
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(0,s,0,s)
    f.BackgroundColor3=Color3.fromRGB(240,240,240)
    f.BorderSizePixel=0
    f.LayoutOrder=#scroll:GetChildren()
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
    local img=Instance.new("ImageLabel",f)
    img.Size=UDim2.new(1,0,1,0)
    img.BackgroundTransparency=1
    img.Image="rbxthumb://type="..kind.."&id="..tostring(id).."&w=420&h=420"
    img.ScaleType=Enum.ScaleType.Crop
    Instance.new("UICorner",img).CornerRadius=UDim.new(0,6)
end

local function getCookie()
    local c
    if getcookie then pcall(function() c=getcookie() end) end
    if not c and syn and syn.getcookie then pcall(function() c=syn.getcookie() end) end
    return c
end

local function realTryOn(assetId,cb)
    local cookie=getCookie()
    if not cookie then cb(false,"no-cookie") return end
    local uid=service.Players.LocalPlayer.UserId
    task.spawn(function()
        local cur=fetchJson("https://avatar.roblox.com/v1/users/"..uid.."/currently-wearing")
        if not cur or not cur.assetIds then cb(false,"fetch fail") return end
        local ids={}
        local found=false
        for _,id in ipairs(cur.assetIds) do
            table.insert(ids,id)
            if id==assetId then found=true end
        end
        if not found then table.insert(ids,assetId) end
        local ok,res=httpPost("https://avatar.roblox.com/v1/avatar/set-wearing-assets",
            {assetIds=ids},{["Cookie"]=".ROBLOSECURITY="..cookie},12)
        if not ok or not res then cb(false,"request fail") return end
        if res.StatusCode==200 then cb(true,"real") else cb(false,"API "..tostring(res.StatusCode)) end
    end)
end

local function localTryOn(assetId,cb)
    task.spawn(function()
        local char=service.Players.LocalPlayer.Character
        if not char then cb(false,"no char") return end
        local ok,objs=pcall(function() return game:GetObjects("rbxassetid://"..assetId) end)
        if not ok or not objs or not objs[1] then cb(false,"GetObjects fail") return end
        local added=0
        for _,c in ipairs(objs[1]:GetDescendants()) do
            if c:IsA("Accessory") or c:IsA("Hat") then
                local cl=c:Clone()
                cl.Parent=char
                added=added+1
            end
        end
        if added>0 then cb(true,"local") else cb(false,"not wearable") end
    end)
end

local function tryOn(assetId,statusLbl)
    local function setS(t,c)
        if statusLbl then statusLbl.Text=t statusLbl.TextColor3=c end
    end
    setS("Applying...",Settings.Theme.PlaceholderText)
    realTryOn(assetId,function(ok,reason)
        if ok then
            setS("OK - visible to all",Color3.fromRGB(100,220,130))
        elseif reason=="no-cookie" then
            setS("No cookie - local...",Color3.fromRGB(220,180,100))
            localTryOn(assetId,function(lok,lr)
                if lok then setS("OK - local only",Color3.fromRGB(220,180,100))
                else setS("FAIL: "..tostring(lr),Color3.fromRGB(255,100,110)) end
            end)
        else
            setS("FAIL: "..tostring(reason),Color3.fromRGB(255,100,110))
        end
    end)
end

local function addCatalogRow(scroll,name,price,creator,assetId,cb)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(1,-6,0,58)
    f.BackgroundColor3=Settings.Theme.Main2
    f.BorderSizePixel=0
    f.LayoutOrder=#scroll:GetChildren()
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,5)
    local fl=(tostring(name):sub(1,1) or "?"):upper()
    local hue=(tostring(name):byte(1) or 65)/255
    local ph=Instance.new("Frame",f)
    ph.Size=UDim2.new(0,44,0,44)
    ph.Position=UDim2.new(0,6,0,7)
    ph.BackgroundColor3=Color3.fromHSV(hue,0.35,0.75)
    ph.BorderSizePixel=0
    Instance.new("UICorner",ph).CornerRadius=UDim.new(0,5)
    local pl=Instance.new("TextLabel",ph)
    pl.Size=UDim2.new(1,0,1,0)
    pl.BackgroundTransparency=1
    pl.Text=fl
    pl.TextColor3=Color3.fromRGB(255,255,255)
    pl.Font=Enum.Font.SourceSansBold
    pl.TextSize=18
    local txt=Instance.new("TextLabel",f)
    txt.Size=UDim2.new(1,-130,1,0)
    txt.Position=UDim2.new(0,56,0,0)
    txt.BackgroundTransparency=1
    txt.Text=name.."\n"..price.." R$ - "..creator
    txt.TextColor3=Settings.Theme.Text
    txt.Font=Enum.Font.SourceSans
    txt.TextSize=12
    txt.TextWrapped=true
    txt.TextXAlignment=Enum.TextXAlignment.Left
    txt.TextYAlignment=Enum.TextYAlignment.Center
    local tryBtn=Lib.Button.new()
    tryBtn.Text="TRY"
    tryBtn.Size=UDim2.new(0,36,0,24)
    tryBtn.Position=UDim2.new(1,-42,0,4)
    tryBtn.Parent=f
    local stLbl=Instance.new("TextLabel",f)
    stLbl.Size=UDim2.new(1,-70,0,12)
    stLbl.Position=UDim2.new(0,56,1,-14)
    stLbl.BackgroundTransparency=1
    stLbl.Text=""
    stLbl.TextColor3=Settings.Theme.PlaceholderText
    stLbl.Font=Enum.Font.SourceSans
    stLbl.TextSize=10
    stLbl.TextXAlignment=Enum.TextXAlignment.Left
    tryBtn.OnClick:Connect(function() tryOn(assetId,stLbl) end)
    local openBtn=Instance.new("TextButton",f)
    openBtn.Size=UDim2.new(1,-70,1,0)
    openBtn.BackgroundTransparency=1
    openBtn.Text=""
    openBtn.Parent=f
    openBtn.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
end

local function cmdUser(sc,uid)
    local u=fetchJson("https://users.roblox.com/v1/users/"..tostring(uid))
    if not u then addBlock(sc,"User not found",{color=Color3.fromRGB(255,100,110)}) return end
    addSection(sc,"USER")
    addThumb(sc,"AvatarHeadShot",uid,110)
    addBlock(sc,"@"..tostring(u.name or "?"),{bold=true,size=17})
    if u.displayName and u.displayName~=u.name then addBlock(sc,u.displayName,{size=12,trans=0.4}) end
    addKV(sc,"ID",u.id)
    addKV(sc,"Created",tostring(u.created or ""):sub(1,10))
    if u.description and u.description~="" then
        addSection(sc,"BIO")
        addBlock(sc,u.description,{size=12})
    end
    addSection(sc,"STATS")
    local fr=fetchJson("https://friends.roblox.com/v1/users/"..uid.."/friends/count")
    if fr then addKV(sc,"Friends",fmt(fr.count)) end
    local fo=fetchJson("https://friends.roblox.com/v1/users/"..uid.."/followers/count")
    if fo then addKV(sc,"Followers",fmt(fo.count)) end
    local b=fetchJson("https://badges.roblox.com/v1/users/"..uid.."/badges?limit=10&sortOrder=Desc")
    if b and b.data and #b.data>0 then
        addSection(sc,"BADGES ("..#b.data..")")
        for _,x in ipairs(b.data) do addBlock(sc,"- "..tostring(x.name),{size=12}) end
    end
    local g=fetchJson("https://games.roblox.com/v2/users/"..uid.."/games?accessFilter=Public&limit=10&sortOrder=Asc")
    if g and g.data and #g.data>0 then
        addSection(sc,"GAMES ("..#g.data..")")
        for _,x in ipairs(g.data) do
            addLink(sc,tostring(x.name).." - "..fmt(x.placeVisits),function() navigate("game:"..tostring(x.id)) end)
        end
    end
end

local function cmdGame(sc,pid)
    local g=fetchJson("https://games.roblox.com/v1/games?universeIds=0&placeIds="..tostring(pid))
    if not g or not g.data or not g.data[1] then addBlock(sc,"Game not found",{color=Color3.fromRGB(255,100,110)}) return end
    local gm=g.data[1]
    addSection(sc,"GAME")
    addThumb(sc,"GameIcon",pid,110)
    addBlock(sc,tostring(gm.name or "?"),{bold=true,size=16})
    if gm.creator then addBlock(sc,"by "..tostring(gm.creator.name),{size=12,trans=0.4}) end
    addSection(sc,"STATS")
    addKV(sc,"PlaceID",pid)
    addKV(sc,"Playing",fmt(gm.playing))
    addKV(sc,"Visits",fmt(gm.visits))
    addKV(sc,"Favorites",fmt(gm.favoritedCount))
    addKV(sc,"Max Players",gm.maxPlayers or 0)
    if gm.genre then addKV(sc,"Genre",gm.genre) end
    if gm.description and gm.description~="" then
        addSection(sc,"DESCRIPTION")
        addBlock(sc,gm.description,{size=12})
    end
end

local function cmdGroup(sc,gid)
    local g=fetchJson("https://groups.roblox.com/v1/groups/"..tostring(gid))
    if not g then addBlock(sc,"Group not found",{color=Color3.fromRGB(255,100,110)}) return end
    addSection(sc,"GROUP")
    addThumb(sc,"GroupIcon",gid,110)
    addBlock(sc,tostring(g.name or "?"),{bold=true,size=16})
    addKV(sc,"ID",g.id)
    if g.owner then addKV(sc,"Owner",tostring(g.owner.username)) end
    addKV(sc,"Members",fmt(g.memberCount))
    if g.description and g.description~="" then
        addSection(sc,"DESCRIPTION")
        addBlock(sc,g.description,{size=12})
    end
    local r=fetchJson("https://groups.roblox.com/v1/groups/"..gid.."/roles")
    if r and r.roles then
        addSection(sc,"ROLES")
        for _,x in ipairs(r.roles) do addBlock(sc,"- "..tostring(x.name).." (rank "..tostring(x.rank)..")",{size=12}) end
    end
end

local function cmdCatalog(sc,kw)
    addSection(sc,"CATALOG: "..kw)
    local url="https://catalog.roblox.com/v1/search/items/details?Keyword="..HttpSvc:UrlEncode(kw).."&Limit=30&SortType=0"
    local d=fetchJson(url)
    if not d or not d.data then addBlock(sc,"No results",{color=Color3.fromRGB(255,100,110)}) return end
    for _,it in ipairs(d.data) do
        addCatalogRow(sc,it.name or "?",it.price or 0,it.creatorName or "?",it.id,function() navigate("asset:"..tostring(it.id)) end)
    end
end

local function cmdAsset(sc,aid)
    addSection(sc,"ASSET")
    local a=fetchJson("https://economy.roblox.com/v2/assets/"..tostring(aid).."/details")
    if not a then addBlock(sc,"Not found",{color=Color3.fromRGB(255,100,110)}) return end
    addBlock(sc,tostring(a.Name or "?"),{bold=true,size=16})
    addKV(sc,"AssetID",aid)
    addKV(sc,"Type",tostring(a.AssetTypeId or "?"))
    addKV(sc,"Creator",tostring(a.Creator and a.Creator.Name or "?"))
    if a.PriceInRobux then addKV(sc,"Price",a.PriceInRobux.." R$") end
    if a.Description and a.Description~="" then
        addSection(sc,"DESCRIPTION")
        addBlock(sc,a.Description,{size=12})
    end
    addSection(sc,"TRY ON")
    local btn=Lib.Button.new()
    btn.Text="TRY ON NOW"
    btn.Size=UDim2.new(1,-6,0,28)
    btn.Parent=sc
    local stLbl=Instance.new("TextLabel",sc)
    stLbl.Size=UDim2.new(1,-6,0,14)
    stLbl.BackgroundTransparency=1
    stLbl.Text=""
    stLbl.TextColor3=Settings.Theme.PlaceholderText
    stLbl.Font=Enum.Font.SourceSans
    stLbl.TextSize=11
    stLbl.TextXAlignment=Enum.TextXAlignment.Left
    btn.OnClick:Connect(function() tryOn(aid,stLbl) end)
end

local function cmdSearch(sc,q)
    addSection(sc,"SEARCH: "..q)
    local d=fetchJson("https://apis.roblox.com/search-api/omni-search?searchQuery="..HttpSvc:UrlEncode(q).."&pageType=all")
    if not d or not d.searchResults then addBlock(sc,"Search failed",{color=Color3.fromRGB(255,100,110)}) return end
    local users,games,groups={},{},{}
    for _,g in ipairs(d.searchResults) do
        if g.contents then
            for _,it in ipairs(g.contents) do
                if it.name and it.id then
                    local c=it.category
                    if c=="User" then table.insert(users,it)
                    elseif c=="Group" then table.insert(groups,it)
                    else table.insert(games,it) end
                end
            end
        end
    end
    if #users>0 then
        addSection(sc,"USERS ("..#users..")")
        for i=1,math.min(#users,8) do
            local it=users[i]
            addLink(sc,tostring(it.name),function() navigate("user:"..tostring(it.id)) end)
        end
    end
    if #games>0 then
        addSection(sc,"GAMES ("..#games..")")
        for i=1,math.min(#games,8) do
            local it=games[i]
            addLink(sc,tostring(it.name),function() navigate("game:"..tostring(it.id)) end)
        end
    end
    if #groups>0 then
        addSection(sc,"GROUPS ("..#groups..")")
        for i=1,math.min(#groups,8) do
            local it=groups[i]
            addLink(sc,tostring(it.name),function() navigate("group:"..tostring(it.id)) end)
        end
    end
end

local function doRbx(q)
    clearContent()
    local sc=newScroll()
    local low=q:lower()
    if low:match("^user:") then cmdUser(sc,q:sub(6))
    elseif low:match("^game:") then cmdGame(sc,q:sub(6))
    elseif low:match("^group:") then cmdGroup(sc,q:sub(7))
    elseif low:match("^cat:") then cmdCatalog(sc,q:sub(5))
    elseif low:match("^asset:") then cmdAsset(sc,q:sub(7))
    elseif q:match("^%d+$") then cmdUser(sc,q)
    else
        local uid=nil
        local ok,res=httpPost("https://users.roblox.com/v1/usernames/users",{usernames={q},excludeBannedUsers=false},nil,10)
        if ok and res and res.Body then
            local s,dd=pcall(function() return HttpSvc:JSONDecode(res.Body) end)
            if s and dd and dd.data and dd.data[1] then uid=dd.data[1].id end
        end
        if uid then cmdUser(sc,tostring(uid)) else cmdSearch(sc,q) end
    end
end

local function doWeb(q)
    local url=q
    if not url:match("^https?://") then url="https://"..url end
    clearContent()
    local sc=newScroll()
    addBlock(sc,"Loading "..url:sub(1,60).."...",{size=12,trans=0.4})
    local data,source
    local ok1,d1=httpGet("https://r.jina.ai/"..url,10)
    if ok1 and d1 and #d1>100 then data,source=d1,"JINA" end
    if not data then
        local ok2,d2=httpGet("https://api.allorigins.win/raw?url="..url,10)
        if ok2 and d2 and #d2>100 then data,source=d2,"ORIGIN" end
    end
    if not data then
        local ok3,d3=httpGet(url,8)
        if ok3 and d3 and #d3>100 then data,source=d3,"DIRECT" end
    end
    clearContent()
    if not data then
        local sc2=newScroll()
        addBlock(sc2,"Failed: "..url,{color=Color3.fromRGB(255,100,110)})
        return
    end
    local sc2=newScroll()
    if source=="JINA" then
        for line in data:gmatch("[^\n]+") do
            local cl=line:gsub("^%s+",""):gsub("%s+$","")
            if #cl>0 then
                local h=cl:match("^(#+)%s")
                if h then
                    cl=cl:gsub("^#+%s+","")
                    addBlock(sc2,cl,{size=math.max(14,22-#h*2),bold=true})
                else
                    cl=cl:gsub("%*%*(.-)%*%*","%1"):gsub("%[(.-)%]%b()","%1")
                    addBlock(sc2,cl,{size=13})
                end
            end
        end
    else
        local s=data
        s=s:gsub("<script[^>]*>.-</script>"," "):gsub("<style[^>]*>.-</style>"," "):gsub("<head[^>]*>.-</head>"," ")
        s=s:gsub("<[^>]+>"," "):gsub("&nbsp;"," "):gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
        s=s:gsub("%s+"," ")
        for line in s:gmatch("[^\n]+") do
            if #line>20 then addBlock(sc2,line,{size=13}) end
        end
    end
end

navigate=function(q)
    q=(q or ""):gsub("^%s+",""):gsub("%s+$","")
    if q=="" then return end
    if activeTab=="RBX" then
        local ok,err=pcall(doRbx,q)
        if not ok then clearContent() local sc=newScroll() addBlock(sc,"RBX err: "..tostring(err):sub(1,100),{color=Color3.fromRGB(255,100,110)}) end
    else
        local ok,err=pcall(doWeb,q)
        if not ok then clearContent() local sc=newScroll() addBlock(sc,"WEB err: "..tostring(err):sub(1,100),{color=Color3.fromRGB(255,100,110)}) end
    end
end

Browser.Init=function()
    window=Lib.Window.new()
    window:SetTitle("Browser")
    local _vp=workspace.CurrentCamera.ViewportSize
    local _mobile=game:GetService("UserInputService").TouchEnabled
    local _W=_mobile and math.clamp(math.floor(_vp.X*0.92),240,380) or 460
    local _H=_mobile and math.clamp(math.floor(_vp.Y*0.52),240,360) or 480
    window:Resize(_W,_H)
    Browser.Window=window
    local content=window.GuiElems.Content

    local tabRow=Instance.new("Frame",content)
    tabRow.Size=UDim2.new(1,0,0,26)
    tabRow.Position=UDim2.new(0,0,0,0)
    tabRow.BackgroundTransparency=1

    local webBtn=Lib.Button.new()
    webBtn.Text="Web"
    webBtn.Size=UDim2.new(0,80,1,0)
    webBtn.Parent=tabRow

    local rbxBtn=Lib.Button.new()
    rbxBtn.Text="Roblox"
    rbxBtn.Size=UDim2.new(0,80,1,0)
    rbxBtn.Position=UDim2.new(0,86,0,0)
    rbxBtn.Parent=tabRow

    local function updateTabs()
        if activeTab=="WEB" then
            webBtn.Gui.BackgroundColor3=Settings.Theme.ListSelection
            rbxBtn.Gui.BackgroundColor3=Settings.Theme.Button
            if urlBox then urlBox.TextBox.PlaceholderText="example.com" end
        else
            rbxBtn.Gui.BackgroundColor3=Settings.Theme.ListSelection
            webBtn.Gui.BackgroundColor3=Settings.Theme.Button
            if urlBox then urlBox.TextBox.PlaceholderText="user:1 | game:ID | cat:hat" end
        end
    end

    webBtn.OnClick:Connect(function()
        if activeTab=="WEB" then return end
        activeTab="WEB" updateTabs() navigate("wikipedia.org")
    end)
    rbxBtn.OnClick:Connect(function()
        if activeTab=="RBX" then return end
        activeTab="RBX" updateTabs() navigate("1")
    end)

    local toolbar=Instance.new("Frame",content)
    toolbar.Size=UDim2.new(1,0,0,26)
    toolbar.Position=UDim2.new(0,0,0,30)
    toolbar.BackgroundTransparency=1

    local homeBtn=Lib.Button.new()
    homeBtn.Text="H"
    homeBtn.Size=UDim2.new(0,26,1,0)
    homeBtn.Parent=toolbar
    homeBtn.OnClick:Connect(function()
        if activeTab=="WEB" then navigate("wikipedia.org") else navigate("1") end
    end)

    local clrBtn=Lib.Button.new()
    clrBtn.Text="C"
    clrBtn.Size=UDim2.new(0,26,1,0)
    clrBtn.Position=UDim2.new(0,32,0,0)
    clrBtn.Parent=toolbar
    clrBtn.OnClick:Connect(function()
        clearContent()
        local sc=newScroll()
        addBlock(sc,"Type above and press Go",{size=13,trans=0.4})
    end)

    urlBox=Lib.ViewportTextBox.new()
    urlBox.Size=UDim2.new(1,-140,1,0)
    urlBox.Position=UDim2.new(0,64,0,0)
    urlBox.Parent=toolbar
    urlBox.TextBox.PlaceholderText="example.com"
    urlBox.TextBox.FocusLost:Connect(function(enter)
        if enter then
            local t=urlBox:GetText()
            if t and t~="" then navigate(t) end
        end
    end)

    local goBtn=Lib.Button.new()
    goBtn.Text="Go"
    goBtn.Size=UDim2.new(0,60,1,0)
    goBtn.Position=UDim2.new(1,-66,0,0)
    goBtn.Parent=toolbar
    goBtn.OnClick:Connect(function()
        local t=urlBox:GetText()
        if t and t~="" then navigate(t) end
    end)

    contentHolder=Instance.new("Frame",content)
    contentHolder.Size=UDim2.new(1,0,1,-62)
    contentHolder.Position=UDim2.new(0,0,0,60)
    contentHolder.BackgroundTransparency=1

    updateTabs()
    task.delay(0.3,function()
        pcall(function() navigate("wikipedia.org") end)
    end)
end

return Browser
end

return {InitDeps=initDeps, InitAfterMain=initAfterMain, Main=main}
end,

