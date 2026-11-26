local ADDON = ...
local unpack = unpack or table.unpack
local db, guide, menu
local windows = {}
local live, pendingReset, lastZone, resetReason, resetRetry = false, false, nil, nil, 0
local demo = false
local TEX = "Interface\\Buttons\\WHITE8X8"
local ACC = {0.35, 0.86, 0.78}
local MODES = {
    {title="Damage Done", short="DMG / FIGHT", amount="DMG", rate="DPS", session=1, kind=0},
    {title="Damage Done Overall", short="DMG / RUN", amount="DMG", rate="DPS", session=0, kind=0},
    {title="Healing Done", short="HEAL / FIGHT", amount="HEAL", rate="HPS", session=1, kind=2},
    {title="Healing Done Overall", short="HEAL / RUN", amount="HEAL", rate="HPS", session=0, kind=2},
}
local ROW, TOP, FOOT, GAP = 25, 57, 23, 5
local MINW, MAXW, MAXROWS, MAXWINDOWS = 390, 760, 40, 12
local refresh, layout, showMenu, showGuide, makeWindow
local function clamp(n,a,b) return math.max(a,math.min(b,n)) end
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function readable(v) return not secret(v) and v ~= nil end
local function num(v) return readable(v) and type(v)=="number" end
local function msg(s) print("|cff59d8c6R-CombatMeter|r: "..s) end
local function rect(parent, layer, r,g,b,a)
    local t=parent:CreateTexture(nil,layer or "BACKGROUND")
    t:SetColorTexture(r,g,b,a or 1); return t
end
local function label(parent, size, r,g,b, align)
    local l=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    l:SetFont(STANDARD_TEXT_FONT,size or 11,"")
    l:SetTextColor(r or .88,g or .91,b or .95)
    l:SetJustifyH(align or "LEFT")
    l:SetWordWrap(false)
    return l
end
local function border(f,r,g,b,a)
    f.edge={}
    for i=1,4 do f.edge[i]=rect(f,"BORDER",r,g,b,a) end
    local e=f.edge
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
end
local function button(parent, text, w,h, fn, tip)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h)
    b.bg=rect(b,"BACKGROUND",.13,.17,.20,.95); b.bg:SetAllPoints()
    b.t=label(b,11,.78,.85,.89,"CENTER"); b.t:SetAllPoints(); b.t:SetText(text)
    b:SetScript("OnClick",fn)
    b:SetScript("OnEnter",function(self)
        self.bg:SetColorTexture(.20,.33,.35,1)
        if tip then GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(tip,1,1,1,true); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave",function(self) self.bg:SetColorTexture(.13,.17,.20,.95); GameTooltip:Hide() end)
    return b
end
local function newConfig(mode,x,y,parent)
    db.nextID=db.nextID+1
    local id=db.nextID
    db.windows[id]={mode=mode or 1,x=x or 0,y=y or 0,width=420,rows=5,locked=false,parent=parent}
    return id
end
local function ids()
    local t={} for id in pairs(db.windows) do t[#t+1]=id end table.sort(t); return t
end
local function root(id)
    local seen={}
    while db.windows[id] and db.windows[id].parent and db.windows[db.windows[id].parent] and not seen[id] do
        seen[id]=true; id=db.windows[id].parent
    end
    return id
end
local function child(id)
    for _,i in ipairs(ids()) do if db.windows[i].parent==id then return i end end
end
local function tail(id)
    local i=root(id); local seen={}
    while child(i) and not seen[i] do seen[i]=true; i=child(i) end
    return i
end
local function locked(id) return db.windows[root(id)].locked end
local function savePos(id)
    local f=windows[id]
    if not f or not f:GetLeft() or not f:GetTop() then return end
    local c=db.windows[id]
    c.x=f:GetLeft()-UIParent:GetLeft()
    c.y=f:GetTop()-UIParent:GetTop()
end
local function separate(id)
    if not db.windows[id].parent then return end
    savePos(id); db.windows[id].locked=locked(id); db.windows[id].parent=nil
    layout()
end
local function dock(id,target)
    local r=root(id); local t=tail(target)
    if r==root(t) or locked(r) then return end
    db.windows[r].parent=t
    layout()
end
local function snap(id)
    local f=windows[id]
    if locked(id) then return end
    local best, dist
    local top=f:GetTop(); local left=f:GetLeft()
    if not top or not left then return end
    for _,i in ipairs(ids()) do
        if root(i)~=id and not child(i) then
            local a=windows[i]
            if a and a:IsShown() and a:GetBottom() and a:GetLeft() then
                local dx=math.abs(left-a:GetLeft()); local dy=math.abs(top-a:GetBottom()-(-GAP))
                if dx<42 and dy<26 and (not dist or dx+dy<dist) then best,dist=i,dx+dy end
            end
        end
    end
    if best then dock(id,best) end
end
local function count() local n=0 for _ in pairs(db.windows) do n=n+1 end return n end
local function addWindow(id,mode,attach)
    if count()>=MAXWINDOWS then msg("Maximal "..MAXWINDOWS.." Fenster."); return end
    local c=db.windows[id]; local parent=attach and tail(id) or nil
    local i=newConfig(mode,c.x+35,c.y-35,parent)
    if attach then db.windows[i].width=db.windows[parent].width end
    makeWindow(i); layout(); refresh()
end
local function closeWindow(id)
    if count()==1 then msg("Letztes Fenster bleibt erhalten. /rcm hide blendet alle aus."); return end
    local c=db.windows[id]; local nextID=child(id)
    if nextID then
        savePos(nextID); db.windows[nextID].parent=c.parent; db.windows[nextID].locked=locked(id)
    end
    windows[id]:Hide(); windows[id]=nil; db.windows[id]=nil
    layout(); refresh()
end
local function classColor(class)
    local c=readable(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r,c.g,c.b end
    return .56,.65,.74
end
local function setIcon(row,source)
    local class=source.classFilename
    local coords=readable(class) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        row.icon:SetTexCoord(unpack(coords))
    elseif readable(source.specIconID) and source.specIconID~=0 then
        row.icon:SetTexture(source.specIconID); row.icon:SetTexCoord(.08,.92,.08,.92)
    else
        row.icon:SetTexture(134400); row.icon:SetTexCoord(.08,.92,.08,.92)
    end
end
local function valueText(fs,v)
    if secret(v) then
        -- Native rendering only; never inspect, format in Lua or calculate secret numbers.
        fs:SetFormattedText("%.0f",v)
    elseif num(v) then
        if v>=1000000000 then fs:SetFormattedText("%.2fB",v/1000000000)
        elseif v>=1000000 then fs:SetFormattedText("%.2fM",v/1000000)
        elseif v>=1000 then fs:SetFormattedText("%.1fK",v/1000)
        else fs:SetFormattedText("%.0f",v) end
    else fs:SetText("-") end
end
local function createRow(f,i)
    local r=CreateFrame("Frame",nil,f); r:SetHeight(ROW-3)
    r.back=rect(r,"BACKGROUND",.11,.14,.18,.91); r.back:SetAllPoints()
    r.bar=CreateFrame("StatusBar",nil,r)
    r.bar:SetAllPoints(); r.bar:SetStatusBarTexture(TEX); r.bar:SetMinMaxValues(0,1); r.bar:SetValue(0)
    r.bar:SetFrameLevel(r:GetFrameLevel()+1)
    local top=CreateFrame("Frame",nil,r); top:SetAllPoints(); top:SetFrameLevel(r.bar:GetFrameLevel()+1)
    r.icon=top:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(20,20); r.icon:SetPoint("LEFT",1,0)
    r.rank=label(top,10,.76,.82,.85,"CENTER"); r.rank:SetPoint("LEFT",24,0); r.rank:SetWidth(20); r.rank:SetText(i)
    r.name=label(top,12,1,1,1); r.name:SetPoint("LEFT",47,0); r.name:SetMaxLines(1)
    r.amount=label(top,12,.97,.98,1,"RIGHT")
    r.rate=label(top,12,.85,.91,.94,"RIGHT")
    r.percent=label(top,11,.77,.85,.89,"RIGHT")
    r.percent:SetPoint("RIGHT",-8,0); r.percent:SetWidth(47)
    r.rate:SetPoint("RIGHT",r.percent,"LEFT",-8,0); r.rate:SetWidth(80)
    r.amount:SetPoint("RIGHT",r.rate,"LEFT",-10,0); r.amount:SetWidth(92)
    r.name:SetPoint("RIGHT",r.amount,"LEFT",-7,0)
    r.mark=rect(top,"OVERLAY",ACC[1],ACC[2],ACC[3],1); r.mark:SetPoint("TOPLEFT",0,0); r.mark:SetPoint("BOTTOMLEFT",0,0); r.mark:SetWidth(2); r.mark:Hide()
    r:Hide(); return r
end
local function updateWindow(f,data,active)
    local c=db.windows[f.id]; local mode=MODES[c.mode]
    local sources=data and data.combatSources
    local n=sources and #sources or 0
    f.offset=clamp(f.offset or 0,0,math.max(0,n-c.rows))
    local total=data and data.totalAmount
    local max=data and data.maxAmount
    -- Respect native order: ordering and aggregation of protected combat values is forbidden.
    if not num(total) and not secret(total) and sources then
        total=0
        for _,s in ipairs(sources) do
            if not num(s.totalAmount) then total=nil; break end
            total=total+s.totalAmount
        end
    end
    for i=1,c.rows do
        local r=f.rows[i]; local s=sources and sources[i+f.offset]
        if s then
            local rank=i+f.offset
            r.rank:SetText(rank)
            r.name:SetText(s.name)
            valueText(r.amount,s.totalAmount); valueText(r.rate,s.amountPerSecond)
            if num(s.totalAmount) and num(total) and total>0 then
                r.percent:SetFormattedText("%.1f%%",s.totalAmount*100/total)
            else r.percent:SetText("-") end
            local rr,gg,bb=classColor(s.classFilename)
            r.bar:SetStatusBarColor(rr,gg,bb,.52)
            setIcon(r,s)
            if s.isLocalPlayer then r.mark:Show() else r.mark:Hide() end
            local upper=max
            if not secret(upper) and (not num(upper) or upper<=0) then upper=1 end
            local val=s.totalAmount
            if not readable(val) and not secret(val) then val=0 end
            local interp=Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or 1
            r.bar:SetMinMaxValues(0,upper,interp)
            r.bar:SetValue(val,interp)
            r:Show()
        else r:Hide() end
    end
    for i=c.rows+1,#f.rows do f.rows[i]:Hide() end
    f.empty:SetShown(n==0)
    f.empty:SetText(demo and "Keine Beispieldaten" or (not C_DamageMeter and "Damage-Meter-API nicht verfügbar" or "Bereit - warte auf Kampfdaten"))
    f.state:SetText(demo and "DEMO" or (active and "LIVE" or "BEREIT"))
    f.state:SetTextColor(active and .40 or .62,active and .92 or .70,active and .79 or .77)
    local shown=n>0 and string.format("%d-%d / %d",f.offset+1,math.min(n,f.offset+c.rows),n) or "0 Spieler"
    f.footer:SetText(shown..(active and "  |  Prozent ggf. nach Kampf" or ""))
    local duration=data and data.durationSeconds
    if num(duration) then f.timer:SetFormattedText("%02d:%02d",math.floor(duration/60),math.floor(duration%60)) else f.timer:SetText(mode.short) end
end
local DEMO_CLASSES={"PALADIN","ROGUE","MAGE","WARRIOR","HUNTER","PRIEST","DRUID","SHAMAN"}
local DEMO_NAMES={"Repact","Fenrir","Wilmer","Eure","Astra","Lunaris","Thorn","Zephyr"}
local function demoData(m)
    local d={combatSources={},maxAmount=0,totalAmount=0,durationSeconds=92}
    for i=1,8 do
        local amount=math.floor((9-i)^1.4*8100*(m==2 and 4 or m>=3 and .42 or 1))
        d.combatSources[i]={name=DEMO_NAMES[i],classFilename=DEMO_CLASSES[i],totalAmount=amount,amountPerSecond=amount/92,isLocalPlayer=i==1}
        d.maxAmount=math.max(d.maxAmount,amount); d.totalAmount=d.totalAmount+amount
    end
    return d
end
refresh=function()
    if not db or db.hidden then return end
    local cache={}
    for id,f in pairs(windows) do
        if f:IsShown() then
            local m=db.windows[id].mode; local data=cache[m]
            if data==nil then
                if demo then data=demoData(m)
                elseif C_DamageMeter and C_DamageMeter.GetCombatSessionFromType then
                    local a=MODES[m]
                    local ok,v=pcall(C_DamageMeter.GetCombatSessionFromType,a.session,a.kind)
                    if ok then data=v end
                end
                cache[m]=data or false
            end
            updateWindow(f,data or nil,live and not demo)
        end
    end
end
layout=function()
    if not db then return end
    local function place(id,seen)
        if seen[id] then return end
        seen[id]=true
        local c,f=db.windows[id],windows[id]
        c.width=clamp(c.width,MINW,MAXW); c.rows=clamp(math.floor(c.rows),1,MAXROWS)
        if c.parent and windows[c.parent] then place(c.parent,seen) end
        f:SetSize(c.width,TOP+c.rows*ROW+FOOT)
        for i=1,c.rows do
            if not f.rows[i] then f.rows[i]=createRow(f,i) end
            local r=f.rows[i]; r:ClearAllPoints(); r:SetPoint("TOPLEFT",f,"TOPLEFT",6,-TOP-(i-1)*ROW); r:SetPoint("TOPRIGHT",f,"TOPRIGHT",-6,-TOP-(i-1)*ROW)
        end
        f:ClearAllPoints()
        if c.parent and windows[c.parent] then
            f:SetPoint("TOPLEFT",windows[c.parent],"BOTTOMLEFT",0,-GAP)
        else
            c.x=clamp(c.x,0,math.max(0,UIParent:GetWidth()-c.width)); c.y=clamp(c.y,-math.max(0,UIParent:GetHeight()-f:GetHeight()),0)
            f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",c.x,c.y)
        end
        local m=MODES[c.mode]
        f.mode.t:SetText(m.title.."  v"); f.amountHead:SetText(m.amount); f.rateHead:SetText(m.rate)
        f.lock.t:SetText(locked(id) and "L" or "U")
        f.lock.t:SetTextColor(locked(id) and .36 or .85,locked(id) and .86 or .86,locked(id) and .78 or .86)
        f.resize:SetShown(not locked(id))
        f:EnableMouseWheel(true); f:SetShown(not db.hidden)
    end
    local seen={} for _,id in ipairs(ids()) do place(id,seen) end
end
local function startMove(id)
    if locked(id) then return end
    local f=windows[root(id)]; f:StartMoving(); f.moving=true
end
local function stopMove(id)
    local r=root(id); local f=windows[r]
    if f.moving then f:StopMovingOrSizing(); f.moving=false; savePos(r); layout(); snap(r); refresh() end
end
makeWindow=function(id)
    if windows[id] then return end
    local f=CreateFrame("Frame","RCombatMeterWindow"..id,UIParent)
    windows[id]=f; f.id=id; f.rows={}; f.offset=0
    f:SetFrameStrata("MEDIUM"); f:SetMovable(true); f:SetResizable(true); f:SetClampedToScreen(true)
    if f.SetResizeBounds then f:SetResizeBounds(MINW,TOP+ROW+FOOT,MAXW,TOP+ROW*MAXROWS+FOOT) end
    f:EnableMouse(true)
    local bg=rect(f,"BACKGROUND",.045,.061,.082,.91); bg:SetAllPoints()
    border(f,.25,.35,.40,.85)
    local accent=rect(f,"ARTWORK",ACC[1],ACC[2],ACC[3],1); accent:SetPoint("TOPLEFT",1,-1); accent:SetPoint("TOPRIGHT",-1,-1); accent:SetHeight(2)
    local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",2,-3); header:SetPoint("TOPRIGHT",-2,-3); header:SetHeight(33)
    local headBg=rect(header,"BACKGROUND",.075,.105,.13,1); headBg:SetAllPoints()
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() startMove(id) end); header:SetScript("OnDragStop",function() stopMove(id) end)
    local brand=label(header,11,ACC[1],ACC[2],ACC[3]); brand:SetPoint("LEFT",8,0); brand:SetText("RM")
    f.mode=button(header,"",174,25,function(b) showMenu(b,id,"mode") end,"Modus auswählen")
    f.mode:SetPoint("LEFT",brand,"RIGHT",8,0)
    f.controls=button(header,"+",26,25,function(b) showMenu(b,id,"windows") end,"Window Control")
    f.controls:SetPoint("RIGHT",-5,0)
    f.lock=button(header,"U",26,25,function()
        local c=db.windows[root(id)]; c.locked=not c.locked; layout()
    end,"U = beweglich, L = gesperrt. Gilt für die ganze Fenstergruppe.")
    f.lock:SetPoint("RIGHT",f.controls,"LEFT",-4,0)
    f.state=label(header,10,.62,.70,.77,"RIGHT"); f.state:SetPoint("RIGHT",f.lock,"LEFT",-8,0)
    f.state:SetWidth(42)
    local cols=CreateFrame("Frame",nil,f); cols:SetPoint("TOPLEFT",6,-37); cols:SetPoint("TOPRIGHT",-6,-37); cols:SetHeight(18)
    local line=rect(cols,"ARTWORK",.19,.25,.30,.9); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    local nameHead=label(cols,10,.60,.70,.77); nameHead:SetPoint("LEFT",47,0); nameHead:SetText("SPIELER")
    local percentHead=label(cols,10,.60,.70,.77,"RIGHT"); percentHead:SetPoint("RIGHT",-8,0); percentHead:SetWidth(47); percentHead:SetText("ANTEIL")
    f.rateHead=label(cols,10,.60,.70,.77,"RIGHT"); f.rateHead:SetPoint("RIGHT",percentHead,"LEFT",-8,0); f.rateHead:SetWidth(80)
    f.amountHead=label(cols,10,.60,.70,.77,"RIGHT"); f.amountHead:SetPoint("RIGHT",f.rateHead,"LEFT",-10,0); f.amountHead:SetWidth(92)
    f.empty=label(f,12,.55,.65,.73,"CENTER"); f.empty:SetPoint("TOPLEFT",10,-TOP); f.empty:SetPoint("BOTTOMRIGHT",-10,FOOT); f.empty:SetText("Bereit")
    local footer=CreateFrame("Frame",nil,f); footer:SetPoint("BOTTOMLEFT",6,2); footer:SetPoint("BOTTOMRIGHT",-6,2); footer:SetHeight(18)
    f.footer=label(footer,10,.59,.69,.76); f.footer:SetPoint("LEFT",3,0)
    f.timer=label(footer,10,.72,.82,.87,"RIGHT"); f.timer:SetPoint("RIGHT",-23,0)
    f.resize=button(footer,"/",18,17,function() end,"Ziehen: Höhe und Breite ändern")
    f.resize:SetPoint("RIGHT")
    f.resize:SetScript("OnMouseDown",function(_,btn)
        if btn=="LeftButton" and not locked(id) then f:StartSizing("BOTTOMRIGHT"); f.sizing=true end
    end)
    f.resize:SetScript("OnMouseUp",function()
        if f.sizing then
            f:StopMovingOrSizing(); f.sizing=false
            local c=db.windows[id]; c.width=clamp(f:GetWidth(),MINW,MAXW); c.rows=clamp(math.floor((f:GetHeight()-TOP-FOOT)/ROW+.5),1,MAXROWS)
            layout(); refresh()
        end
    end)
    f:SetScript("OnMouseWheel",function(_,delta)
        f.offset=math.max(0,(f.offset or 0)-delta); refresh()
    end)
end
local function requestReset(reason)
    pendingReset=true; resetReason=reason; resetRetry=0
end
local function performReset()
    if not pendingReset or live or (InCombatLockdown and InCombatLockdown()) then return end
    if not C_DamageMeter or not C_DamageMeter.ResetAllCombatSessions then
        pendingReset=false; msg("Reset-API nicht verfügbar."); return
    end
    local ok=pcall(C_DamageMeter.ResetAllCombatSessions)
    if ok then
        pendingReset=false
        for _,f in pairs(windows) do f.offset=0 end
        msg("Kampfdaten zurückgesetzt ("..(resetReason or "manuell")..")."); refresh()
    else
        resetRetry=resetRetry+1
        if resetRetry>=3 then pendingReset=false; msg("Reset vom Client nicht zugelassen.") end
    end
end
local function instanceKey()
    local inInstance, kind=IsInInstance()
    if not inInstance or (kind~="party" and kind~="raid") then return "world" end
    local name, _, difficulty, _, _, _, _, map=GetInstanceInfo()
    return kind..":"..tostring(map or name)..":"..tostring(difficulty or 0)
end
local function checkZone()
    if not db then return end
    local key=instanceKey()
    if lastZone~=key then
        local previous=lastZone
        lastZone=key; db.lastZone=key
        if db.autoReset and ((previous and previous~="world") or key~="world") then
            requestReset(key=="world" and "Instanz verlassen" or "Neue Instanz")
        end
    end
end
showMenu=function(anchor,id,kind)
    if menu and menu:IsShown() and menu.anchor==anchor then menu:Hide(); return end
    if not menu then
        menu=CreateFrame("Frame",nil,UIParent)
        menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
        local bg=rect(menu,"BACKGROUND",.055,.077,.10,.98); bg:SetAllPoints()
        border(menu,.28,.42,.45,1); menu.items={}
    end
    menu.anchor=anchor
    local opts={}
    local function item(t,fn) opts[#opts+1]={t,fn} end
    if kind=="mode" then
        for i,m in ipairs(MODES) do
            local mode=i
            item((db.windows[id].mode==mode and "> " or "   ")..m.title,function()
                db.windows[id].mode=mode; windows[id].offset=0; layout(); refresh()
            end)
        end
    else
        item("Neues Fenster anhängen",function()
            addWindow(id,(db.windows[id].mode%#MODES)+1,true)
        end)
        item("Neues freies Fenster",function()
            addWindow(id,(db.windows[id].mode%#MODES)+1,false)
        end)
        if db.windows[id].parent then item("Hier von Gruppe lösen",function() separate(id) end) end
        if not locked(id) then
            for _,target in ipairs(ids()) do
                local other=target
                if root(other)==other and other~=root(id) then
                    item("Gruppe anhängen: #"..other.." "..MODES[db.windows[other].mode].title,function() dock(id,other) end)
                end
            end
        end
        item("Fenster schließen",function() closeWindow(id) end)
        item("Guide / Einstellungen",showGuide)
        item("Alle Kampfdaten zurücksetzen",function()
            if StaticPopup_Show then StaticPopup_Show("RCOMBATMETER_RESET") else requestReset("manuell") end
        end)
    end
    for _,b in ipairs(menu.items) do b:Hide() end
    for i,opt in ipairs(opts) do
        local b=menu.items[i]
        if not b then b=button(menu,"",258,24,function() end); menu.items[i]=b end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",5,-5-(i-1)*26); b.t:SetText(opt[1])
        local action=opt[2]; b:SetScript("OnClick",function() menu:Hide(); action() end); b:Show()
    end
    menu:SetSize(268,10+#opts*26)
    menu:ClearAllPoints()
    local _,y=anchor:GetCenter()
    if y and y<UIParent:GetHeight()/2 then menu:SetPoint("BOTTOMRIGHT",anchor,"TOPRIGHT",0,3)
    else menu:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-3) end
    menu:Show()
end
local function preset(n)
    if count()>0 then
        for _,f in pairs(windows) do f:Hide() end
    end
    windows={}; db.windows={}; db.hidden=false
    local x=math.max(0,UIParent:GetWidth()-448)
    local rows=clamp(math.floor((UIParent:GetHeight()-120-n*(TOP+FOOT+GAP))/(n*ROW)),1,5)
    local y=-math.min(140,math.max(0,UIParent:GetHeight()-(60+n*(TOP+rows*ROW+FOOT+GAP))))
    local prev
    for i=1,n do
        local id=newConfig(i,x,y,prev); db.windows[id].rows=rows; makeWindow(id); prev=id
    end
    layout(); refresh()
end
showGuide=function()
    if menu then menu:Hide() end
    if not guide then
        guide=CreateFrame("Frame","RCombatMeterGuide",UIParent)
        guide:SetSize(540,492); guide:SetPoint("CENTER"); guide:SetFrameStrata("DIALOG"); guide:SetClampedToScreen(true)
        guide:EnableMouse(true); guide:SetMovable(true); guide:RegisterForDrag("LeftButton")
        guide:SetScript("OnDragStart",guide.StartMoving); guide:SetScript("OnDragStop",guide.StopMovingOrSizing)
        local bg=rect(guide,"BACKGROUND",.055,.072,.095,.99); bg:SetAllPoints()
        border(guide,.25,.43,.45,1)
        local line=rect(guide,"ARTWORK",ACC[1],ACC[2],ACC[3],1); line:SetPoint("TOPLEFT",1,-1); line:SetPoint("TOPRIGHT",-1,-1); line:SetHeight(3)
        local kicker=label(guide,11,ACC[1],ACC[2],ACC[3]); kicker:SetPoint("TOPLEFT",22,-19); kicker:SetText("R-COMBATMETER")
        local title=label(guide,24,1,1,1); title:SetPoint("TOPLEFT",22,-40); title:SetText("Dein Kampf. Dein Layout.")
        local sub=label(guide,12,.64,.74,.80); sub:SetPoint("TOPLEFT",22,-78); sub:SetText("WoW Forever  •  Setup Guide  •  Version 1.0.1")
        local function paragraph(y,titleText,body)
            local t=label(guide,13,ACC[1],ACC[2],ACC[3]); t:SetPoint("TOPLEFT",22,-y); t:SetText(titleText)
            local p=label(guide,12,.82,.87,.91); p:SetWordWrap(true); p:SetJustifyV("TOP"); p:SetPoint("TOPLEFT",22,-y-22); p:SetWidth(496); p:SetText(body)
        end
        paragraph(112,"01   LAYOUT", "Wähle ein Startlayout (ersetzt vorhandene Fenster). Ziehe am Header, passe die Größe unten rechts an und sperre die Gruppe mit L/U. Mit + fügst du Fenster an oder löst sie.")
        local single=button(guide,"1 • Damage",152,32,function() preset(1) end); single:SetPoint("TOPLEFT",22,-183)
        local dual=button(guide,"2 • Fight + Overall",152,32,function() preset(2) end); dual:SetPoint("LEFT",single,"RIGHT",10,0)
        local triple=button(guide,"3 • + Healing",172,32,function() preset(3) end); triple:SetPoint("LEFT",dual,"RIGHT",10,0)
        paragraph(235,"02   AUTOMATIK", "Aktuelle Kämpfe nutzt der Client automatisch. Overall lässt sich bei Instanzwechsel und gemeldeten Dungeon-Abschlüssen zurücksetzen. Das betrifft auch andere Meter mit Blizzards Datenquelle.")
        guide.auto=button(guide,"",246,31,function()
            db.autoReset=not db.autoReset; showGuide()
        end); guide.auto:SetPoint("TOPLEFT",22,-306)
        guide.preview=button(guide,"",242,31,function()
            demo=not demo; showGuide(); refresh()
        end); guide.preview:SetPoint("LEFT",guide.auto,"RIGHT",8,0)
        paragraph(355,"03   LIVE-DATEN", "Bei geschützten Kampfwerten zeigt der Client Zahlen und Balken direkt an. Prozentanteile erscheinen, sobald die Zahlen lesbar sind. Wenn keine Daten erscheinen, aktiviere das Blizzard-Damage-Meter in den Spieloptionen.")
        local finish=button(guide,"FERTIG  /  SPIELEN",496,35,function()
            db.guideDone=true; demo=false; guide:Hide(); refresh()
        end); finish:SetPoint("BOTTOMLEFT",22,19)
        finish.bg:SetColorTexture(.12,.38,.36,1)
        local x=button(guide,"X",25,25,function() db.guideDone=true; demo=false; guide:Hide(); refresh() end); x:SetPoint("TOPRIGHT",-10,-10)
    end
    guide.auto.t:SetText("Auto-Reset: "..(db.autoReset and "AN" or "AUS"))
    guide.preview.t:SetText("Demo-Vorschau: "..(demo and "AN" or "AUS"))
    guide:Show()
end
local function init()
    RCombatMeterDB=RCombatMeterDB or {}
    db=RCombatMeterDB
    db.windows=db.windows or {}; db.nextID=db.nextID or 0
    if db.autoReset==nil then db.autoReset=true end
    lastZone=db.lastZone
    if not next(db.windows) then preset(1) else
        for _,id in ipairs(ids()) do
            local c=db.windows[id]
            c.mode=clamp(tonumber(c.mode) or 1,1,#MODES)
            c.width=tonumber(c.width) or 420; c.rows=tonumber(c.rows) or 5
            c.x=tonumber(c.x) or 0; c.y=tonumber(c.y) or -100
            if c.parent==id or not db.windows[c.parent] then c.parent=nil end
            db.nextID=math.max(db.nextID,id)
            makeWindow(id)
        end
        layout()
    end
    if StaticPopupDialogs then
        StaticPopupDialogs.RCOMBATMETER_RESET={
            text="Alle Kampfdaten zurücksetzen? Dies betrifft auch das eingebaute Damage Meter und andere Addons, die dieselben Daten nutzen.",
            button1="Zurücksetzen",button2="Abbrechen",timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function() requestReset("manuell") end,
        }
    end
    if not db.guideDone then demo=true; showGuide() end
    refresh()
end
SLASH_RCOMBATMETER1="/rcm"
SlashCmdList.RCOMBATMETER=function(command)
    if not db then return end
    local cmd=command:lower():match("^%s*(%S*)") or ""
    if cmd=="hide" then db.hidden=not db.hidden; layout(); refresh()
    elseif cmd=="demo" then demo=not demo; refresh()
    elseif cmd=="reset" then if StaticPopup_Show then StaticPopup_Show("RCOMBATMETER_RESET") else requestReset("manuell") end
    elseif cmd=="lock" then
        local a=ids(); local state=not locked(a[1])
        for _,id in ipairs(a) do if root(id)==id then db.windows[id].locked=state end end
        layout()
    else showGuide() end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","DAMAGE_METER_COMBAT_SESSION_UPDATED","DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET","LFG_COMPLETION_REWARD","CHALLENGE_MODE_COMPLETED"}) do
    pcall(events.RegisterEvent,events,event)
end
local dirty,zoneAt,elapsed,checkElapsed= true,nil,0,0
events:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" and arg==ADDON then
        init()
    elseif not db then return
    elseif event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
        live=UnitAffectingCombat("player") or false
        zoneAt=GetTime()+0.8
    elseif event=="PLAYER_REGEN_DISABLED" then
        live=true; dirty=true
        for _,f in pairs(windows) do if MODES[db.windows[f.id].mode].session==1 then f.offset=0 end end
    elseif event=="PLAYER_REGEN_ENABLED" then live=false; dirty=true
    elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then layout(); dirty=true
    elseif event=="LFG_COMPLETION_REWARD" or event=="CHALLENGE_MODE_COMPLETED" then
        if db.autoReset and instanceKey()~="world" then requestReset("Instanz abgeschlossen") end
    elseif event=="DAMAGE_METER_RESET" then
        for _,f in pairs(windows) do f.offset=0 end
        dirty=true
    else dirty=true end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not db then return end
    elapsed=elapsed+dt; checkElapsed=checkElapsed+dt
    if zoneAt and GetTime()>=zoneAt then zoneAt=nil; checkZone(); dirty=true end
    if checkElapsed>=1 then
        checkElapsed=0
        if pendingReset then performReset() end
        if not zoneAt then checkZone() end
        dirty=true
    end
    if elapsed>=.20 and (dirty or live or demo) then
        elapsed=0; dirty=false; refresh()
    end
end)
