local ADDON, NS = ...
local L = NS.L
local unpack = unpack or table.unpack
local db, guide, menu, detail, profilePanel
local account, characterKey, activeProfile
local overallRun, overallFrozen
local showDetail, refreshDetail, showProfiles, useProfile, applyProfile, captureMob, tickMob
local windows = {}
local live, pendingReset, lastZone, resetReason, resetRetry = false, false, nil, nil, 0
local demo = false
local demoClock=0
local historyPage=1
local TEX = "Interface\\Buttons\\WHITE8X8"
local ACC = {0.35, 0.86, 0.78}
local HEADER = {.075,.105,.13}
local DEFAULT_ACC={.35,.86,.78}; local DEFAULT_HEADER={.075,.105,.13}
local ICONS="Interface\\Icons\\"
local UNKNOWN=134400
local MOB_ICON=ICONS.."INV_Misc_Bone_HumanSkull_01"
local MODES = {
    {title=L.DAMAGE, short=L.DMG_FIGHT, amount=L.DMG, rate="DPS", session=1, kind=0},
    {title=L.DAMAGE_OVERALL, short=L.DMG_RUN, amount=L.DMG, rate="DPS", session=0, kind=0},
    {title=L.HEALING, short=L.HEAL_FIGHT, amount=L.HEAL, rate="HPS", session=1, kind=2},
    {title=L.HEALING_OVERALL, short=L.HEAL_RUN, amount=L.HEAL, rate="HPS", session=0, kind=2},
    {title=L.INTERRUPTS, short=L.INTERRUPTS, amount=L.COUNT, rate="", session=1, kind=5, count=true},
    {title=L.DISPELS, short=L.DISPELS, amount=L.COUNT, rate="", session=1, kind=6, count=true},
    {title=L.DEATHS, short=L.DEATHS, amount=L.COUNT, rate="", session=1, kind=9, count=true},
}
local modeStyle={
    [0]={{1,.48,.32},ICONS.."Ability_Warrior_SavageBlow"},
    [2]={{.40,.93,.55},ICONS.."Spell_Holy_Heal"},
    [5]={{1,.77,.29},ICONS.."Ability_Kick"},
    [6]={{.50,.75,1},ICONS.."Spell_Holy_DispelMagic"},
    [9]={{.79,.57,1},ICONS.."Ability_Rogue_FeignDeath"},
}
for _,m in ipairs(MODES) do
    m.color,m.icon=unpack(modeStyle[m.kind])
end
local function modeSupported(m)
    return m.kind~=9 or not (Enum and Enum.DamageMeterType) or Enum.DamageMeterType.Deaths~=nil
end
local ROW, TOP, FOOT, GAP = 25, 57, 23, 5
local MINW, MAXW, MAXROWS, MAXWINDOWS = 390, 760, 40, 12
local refresh, layout, showMenu, showGuide, makeWindow
local draggingRoot, resizeDrag, dockPreview, dragState
local cursorUI
local layoutPending=false
local lastLayoutWidth,lastLayoutHeight
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
        if tip then
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            -- The Forever client accepts the text-only signature across API versions.
            -- Legacy RGB / wrap parameters are not compatible with its current signature.
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave",function(self) self.bg:SetColorTexture(.13,.17,.20,.95); GameTooltip:Hide() end)
    return b
end
local function decorate(b,icon,color,portrait,selected)
    if not b.modeIcon then
        b.modeIcon=b:CreateTexture(nil,"ARTWORK")
        b.modeIcon:SetSize(18,18); b.modeIcon:SetPoint("LEFT",5,0)
        b.selection=rect(b,"OVERLAY",.8,.9,1,1)
        b.selection:SetSize(2,18); b.selection:SetPoint("LEFT",0,0)
    end
    b.t:ClearAllPoints()
    if icon or portrait then
        b.modeIcon:SetTexture(icon or MOB_ICON); b.modeIcon:SetTexCoord(.07,.93,.07,.93)
        if portrait and SetPortraitTextureFromCreatureDisplayID then
            pcall(SetPortraitTextureFromCreatureDisplayID,b.modeIcon,portrait)
            b.modeIcon:SetTexCoord(0,1,0,1)
        end
        b.modeIcon:Show()
        b.t:SetPoint("LEFT",29,0); b.t:SetPoint("RIGHT",-5,0); b.t:SetJustifyH("LEFT")
    else
        b.modeIcon:Hide(); b.t:SetAllPoints(); b.t:SetJustifyH("CENTER")
    end
    b.t:SetTextColor(unpack(color or {.78,.85,.89}))
    b.selection:SetShown(selected==true)
    if color then b.selection:SetColorTexture(color[1],color[2],color[3],1) end
end
local function createLockIcon(b)
    b.t:Hide()
    local icon=CreateFrame("Frame",nil,b)
    icon:SetSize(16,16); icon:SetPoint("CENTER"); icon:EnableMouse(false)
    local function piece(x,y,w,h)
        local t=rect(icon,"ARTWORK",1,1,1,1)
        t:SetPoint("TOPLEFT",icon,"TOPLEFT",x,-y); t:SetSize(w,h)
        return t
    end
    b.lockIcon={body=piece(2,7,12,8),top=piece(5,1,7,2),
        left=piece(4,2,2,6),right=piece(11,2,2,6),
        openSide=piece(11,2,2,3)}
    local key=rect(icon,"OVERLAY",.075,.105,.13,1)
    key:SetPoint("TOPLEFT",icon,"TOPLEFT",7,-9); key:SetSize(2,4)
end
local function paintLock(b,isLocked)
    local l=b.lockIcon
    local r,g,bl=.82,.87,.91
    if isLocked then r,g,bl=ACC[1],ACC[2],ACC[3] end
    for _,t in pairs(l) do t:SetColorTexture(r,g,bl,1) end
    l.top:Show(); l.left:Show()
    l.right:SetShown(isLocked); l.openSide:SetShown(not isLocked)
end
local function createHistoryIcon(b)
    b.t:Hide()
    local icon=CreateFrame("Frame",nil,b)
    icon:SetSize(16,16); icon:SetPoint("CENTER"); icon:EnableMouse(false)
    local function piece(x,y,w,h,r,g,bl)
        local t=rect(icon,"ARTWORK",r,g,bl,1)
        t:SetPoint("TOPLEFT",icon,"TOPLEFT",x,-y); t:SetSize(w,h)
        return t
    end
    b.paper=piece(3,1,10,14,.73,.83,.88)
    piece(1,1,5,3,.88,.93,.96); piece(10,12,5,3,.88,.93,.96)
    piece(5,5,6,1,.13,.20,.25); piece(5,8,6,1,.13,.20,.25)
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
-- Positions belong exclusively to the addon; never persist a temporary
-- UI screen clamp during startup, reload or a scale change.
local function screenSize()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    if type(w)=="number" and type(h)=="number" and w>=MINW and h>=TOP+ROW+FOOT
        and UIParent:GetLeft() and UIParent:GetTop() then return w,h end
end
local function displayedPos(id)
    local f=windows[id]
    if not f or not f:GetLeft() or not f:GetTop() or not screenSize() then return end
    return f:GetLeft()-UIParent:GetLeft(),f:GetTop()-UIParent:GetTop()
end
local function savePos(id)
    local x,y=displayedPos(id)
    if x then local c=db.windows[id]; c.x=x; c.y=y end
end
local function separate(id)
    if not db.windows[id].parent then return end
    savePos(id); db.windows[id].locked=locked(id); db.windows[id].parent=nil
    layout()
end
local function groupMembers(id)
    local r=root(id); local members={}
    for _,i in ipairs(ids()) do if root(i)==r then members[#members+1]=i end end
    return members
end
local function setGroupSize(id,width,rows,fitScreen)
    local members=groupMembers(id)
    width=clamp(width,MINW,MAXW)
    local limit=MAXROWS
    local _,h=screenSize()
    if fitScreen~=false and h then
        limit=math.max(1,math.min(MAXROWS,math.floor((h-(#members-1)*GAP-#members*(TOP+FOOT))/(#members*ROW))))
    end
    rows=clamp(math.floor(rows+.5),1,limit)
    for _,i in ipairs(members) do
        db.windows[i].width=width
        db.windows[i].rows=rows
    end
    return width,rows
end
local function groupHeight(id)
    local n=#groupMembers(id)
    return n*(TOP+db.windows[root(id)].rows*ROW+FOOT)+(n-1)*GAP
end
local function dock(id,target,side)
    local r,t=root(id),root(target)
    if r==t or locked(r) then return false end
    local tc=db.windows[t]
    local tx,ty=displayedPos(t)
    if not tx then tx,ty=tc.x,tc.y end
    local lock=tc.locked
    local width,rows=tc.width,tc.rows
    local movingCount=#groupMembers(r)
    if side=="above" then
        local last=tail(r)
        db.windows[t].parent=last
        db.windows[r].locked=lock
        setGroupSize(r,width,rows)
        db.windows[r].x=tx
        db.windows[r].y=ty+movingCount*(TOP+db.windows[r].rows*ROW+FOOT+GAP)
    else
        db.windows[r].parent=tail(t)
        setGroupSize(t,width,rows)
    end
    layout(); refresh()
    return true
end
-- Only free ends of distinct vertical groups may join; use the same
-- candidate for the preview and the final drop.
local function findDock(id)
    if locked(id) or db.hidden then return end
    local r=root(id)
    local first,last=windows[r],windows[tail(r)]
    if not first or not last then return end
    local ml,mr,mt,mb=first:GetLeft(),first:GetRight(),first:GetTop(),last:GetBottom()
    if not ml or not mr or not mt or not mb then return end
    local best,side,score
    local function consider(i,d,v)
        if not score or v<score then best,side,score=i,d,v end
    end
    for _,i in ipairs(ids()) do
        if root(i)==i and i~=r then
            local a,b=windows[i],windows[tail(i)]
            if a and b and a:IsShown() and b:IsShown() then
                local al,ar,at,ab=a:GetLeft(),a:GetRight(),a:GetTop(),b:GetBottom()
                if al and ar and at and ab then
                    local overlap=math.min(mr,ar)-math.max(ml,al)
                    local dx=math.abs(ml-al)
                    if overlap>=math.min(mr-ml,ar-al)*.45 then
                        local above=math.abs(mb-at-GAP)
                        local below=math.abs(mt-ab+GAP)
                        if above<=38 then consider(i,"above",above+dx*.15) end
                        if below<=38 then consider(i,"below",below+dx*.15) end
                        -- Deliberate overlap: pick the nearest group end even
                        -- if the moving window is directly on the target.
                        local vertical=math.min(mt,at)-math.max(mb,ab)
                        if vertical>0 then
                            local up=(mt+mb)>=(at+ab)
                            consider(i,up and "above" or "below",100+math.min(above,below)+dx*.15)
                        end
                    end
                end
            end
        end
    end
    return best,side
end
local function hideDockPreview()
    if dockPreview then dockPreview:Hide() end
end
local function showDockPreview(target,side)
    if not target then hideDockPreview(); return end
    local targetFrame=windows[side=="above" and root(target) or tail(target)]
    if not dockPreview then
        dockPreview=CreateFrame("Frame",nil,UIParent)
        dockPreview:SetFrameStrata("HIGH"); dockPreview:EnableMouse(false)
        local halo=rect(dockPreview,"BACKGROUND",ACC[1],ACC[2],ACC[3],.24); dockPreview.halo=halo
        halo:SetAllPoints()
        local inner=rect(dockPreview,"ARTWORK",ACC[1],ACC[2],ACC[3],.55); dockPreview.inner=inner
        inner:SetPoint("LEFT"); inner:SetPoint("RIGHT"); inner:SetHeight(6)
        local core=rect(dockPreview,"OVERLAY",ACC[1],ACC[2],ACC[3],1); dockPreview.core=core
        core:SetPoint("LEFT"); core:SetPoint("RIGHT"); core:SetHeight(2)
    end
    dockPreview.halo:SetColorTexture(ACC[1],ACC[2],ACC[3],.24)
    dockPreview.inner:SetColorTexture(ACC[1],ACC[2],ACC[3],.55)
    dockPreview.core:SetColorTexture(ACC[1],ACC[2],ACC[3],1)
    dockPreview:ClearAllPoints()
    local y=side=="above" and GAP/2 or -GAP/2
    local edge=side=="above" and "TOP" or "BOTTOM"
    dockPreview:SetPoint("LEFT",targetFrame,edge.."LEFT",0,y)
    dockPreview:SetPoint("RIGHT",targetFrame,edge.."RIGHT",0,y)
    dockPreview:SetHeight(12); dockPreview:Show()
end
local function count() local n=0 for _ in pairs(db.windows) do n=n+1 end return n end
local function addWindow(id,mode,attach)
    if count()>=MAXWINDOWS then msg(L.MAX_WINDOWS_PREFIX..MAXWINDOWS..L.MAX_WINDOWS_SUFFIX); return end
    local c=db.windows[id]
    local i
    if attach then
        local r=root(id)
        local rc=db.windows[r]
        local x,y=displayedPos(r)
        if not x then x,y=rc.x,rc.y end
        -- Insert directly above the invoking window, not at the group's tail.
        i=newConfig(mode,x,y,c.parent)
        local new=db.windows[i]
        new.width,new.rows,new.locked=rc.width,rc.rows,rc.locked
        c.parent=i
        local newRoot=root(i)
        setGroupSize(newRoot,new.width,new.rows)
        local top=db.windows[newRoot]
        top.x=x
        -- Grow upwards to retain the invoking window's existing position
        -- and the windows below it when space permits.
        top.y=y+TOP+top.rows*ROW+FOOT+GAP
    else
        local w,h=screenSize()
        i=newConfig(mode,0,0,nil)
        local new=db.windows[i]
        if w then
            new.x=(w-new.width)/2
            new.y=-(h-(TOP+new.rows*ROW+FOOT))/2
        else
            new.centerOnLayout=true
        end
    end
    makeWindow(i); layout(); refresh()
end
local function closeWindow(id)
    if count()==1 then msg(L.LAST_WINDOW); return end
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
    local r=CreateFrame("Button",nil,f); r:SetHeight(ROW-3)
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
    r:EnableMouse(true)
    r:SetScript("OnClick",function()
        if r.source then showDetail(f,r.source) end
    end)
    r:Hide(); return r
end
local function updateWindow(f,data,active)
    local c=db.windows[f.id]; local mode=MODES[c.mode]
    if secret(data) or type(data)~="table" then data=nil end
    local sources=data and data.combatSources
    if secret(sources) or type(sources)~="table" then sources=nil end
    local n=sources and #sources or 0
    f.offset=clamp(f.offset or 0,0,math.max(0,n-c.rows))
    local total=data and data.totalAmount
    local max=data and data.maxAmount
    -- Respect native order: ordering and aggregation of protected combat values is forbidden.
    if not num(total) and not secret(total) and sources then
        total=0
        for _,s in ipairs(sources) do
            if secret(s) or type(s)~="table" or not num(s.totalAmount) then total=nil; break end
            total=total+s.totalAmount
        end
    end
    for i=1,c.rows do
        local r=f.rows[i]; local s=sources and sources[i+f.offset]
        r.source=nil
        if not secret(s) and type(s)=="table" then
            r.source=s
            local rank=i+f.offset
            r.rank:SetText(rank)
            r.name:SetText(s.name)
            valueText(r.amount,s.totalAmount); if mode.count then r.rate:SetText("") else valueText(r.rate,s.amountPerSecond) end
            if num(s.totalAmount) and num(total) and total>0 then
                r.percent:SetFormattedText("%.1f%%",s.totalAmount*100/total)
            else r.percent:SetText("-") end
            local rr,gg,bb=classColor(s.classFilename)
            r.bar:SetStatusBarColor(rr,gg,bb,.52)
            setIcon(r,s)
            if readable(s.isLocalPlayer) and s.isLocalPlayer then r.mark:Show() else r.mark:Hide() end
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
    for i=c.rows+1,#f.rows do f.rows[i].source=nil; f.rows[i]:Hide() end
    f.empty:SetShown(n==0)
    f.empty:SetText(demo and L.NO_DEMO or (not modeSupported(mode) and L.MODE_UNAVAILABLE or (not C_DamageMeter and L.NO_API or L.WAIT_DATA)))
    f.state:SetText(demo and "DEMO" or (active and "LIVE" or L.READY))
    f.state:SetTextColor(active and .40 or .62,active and .92 or .70,active and .79 or .77)
    local shown=n>0 and string.format("%d-%d / %d",f.offset+1,math.min(n,f.offset+c.rows),n) or L.ZERO_PLAYERS
    f.footer:SetText(shown..(active and L.PERCENT_HINT or ""))
    local duration=data and data.durationSeconds
    if num(duration) then f.timer:SetFormattedText("%02d:%02d",math.floor(duration/60),math.floor(duration%60)) else f.timer:SetText(mode.short) end
end
local DEMO_CLASSES={"PALADIN","ROGUE","MAGE","WARRIOR","HUNTER","PRIEST","DRUID","SHAMAN"}
local DEMO_NAMES={"Repact","Fenrir","Wilmer","Eure","Astra","Lunaris","Thorn","Zephyr"}
local mobModel, mobCandidate
local function mobIdentity(unit)
    if not UnitExists or not UnitName or not UnitCanAttack or not UnitGUID then return end
    local ok,name,guid=pcall(function()
        if not UnitExists(unit) then return end
        local attack=UnitCanAttack("player",unit)
        if not readable(attack) or not attack then return end
        return UnitName(unit),UnitGUID(unit)
    end)
    if ok and readable(name) and type(name)=="string" and readable(guid) and type(guid)=="string"
        and (guid:match("^Creature%-") or guid:match("^Vehicle%-")) then return name,guid end
end
captureMob=function(unit)
    if not account or not SetPortraitTextureFromCreatureDisplayID then return end
    local name,guid=mobIdentity(unit)
    if not name or account.portraits[name] then return end
    if mobCandidate then return end
    if not mobModel then
        local ok,model=pcall(CreateFrame,"PlayerModel",nil,UIParent)
        if not ok or not model or not model.GetDisplayInfo or not model.SetUnit then return end
        mobModel=model
        mobModel:SetSize(1,1); mobModel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,0)
        mobModel:SetAlpha(0); mobModel:EnableMouse(false); mobModel:Show()
    end
    if mobModel.ClearModel then pcall(mobModel.ClearModel,mobModel) end
    local ok=pcall(mobModel.SetUnit,mobModel,unit)
    if ok then mobCandidate={unit=unit,name=name,guid=guid,wait=0} end
end
tickMob=function(dt)
    if not mobCandidate then return end
    local c=mobCandidate; c.wait=c.wait+dt
    if c.wait<.20 then return end
    local name,guid=mobIdentity(c.unit)
    if guid~=c.guid or name~=c.name or c.wait>2 then mobCandidate=nil; return end
    local ok,id=pcall(mobModel.GetDisplayInfo,mobModel)
    if ok and num(id) and id>0 then
        local n=0 for _ in pairs(account.portraits) do n=n+1 end
        if n>=1500 then local k=next(account.portraits); if k then account.portraits[k]=nil end end
        account.portraits[c.name]=id; mobCandidate=nil
    end
end
local function availableHistory()
    local entries={}
    if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return entries end
    local ok,list=pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or secret(list) or type(list)~="table" then return entries end
    for _,session in ipairs(list) do
        if not secret(session) and type(session)=="table" then
            local id,name=session.sessionID,session.name
            if num(id) then
                if not readable(name) or type(name)~="string" or name=="" then name=L.FIGHT_NUMBER..id end
                entries[#entries+1]={id=id,name=name,portrait=account and account.portraits[name]}
            end
        end
    end
    table.sort(entries,function(a,b) return a.id>b.id end)
    return entries
end
local function demoData(m)
    local t=demoClock%64+1
    local d={combatSources={},maxAmount=0,totalAmount=0,durationSeconds=t}
    for i=1,8 do
        local phase=i*1.75
        local weight=1+0.05*(9-i)
        local amount=math.floor((t*weight + 5*(math.cos(phase)-math.cos(t*.22+phase)))*1200*(m==2 and 4 or m>=3 and .42 or 1))
        if MODES[m].count then amount=math.floor(amount/12000) end
        amount=math.max(1,amount)
        d.combatSources[i]={name=DEMO_NAMES[i],classFilename=DEMO_CLASSES[i],totalAmount=amount,amountPerSecond=amount/t,isLocalPlayer=i==1}
        d.maxAmount=math.max(d.maxAmount,amount); d.totalAmount=d.totalAmount+amount
    end
    table.sort(d.combatSources,function(a,b) return a.totalAmount>b.totalAmount end)
    return d
end
-- Native sessions are shared. A local overall boundary is a snapshot of
-- PUBLIC values only; never reset the native history for an automatic reset.
local function publicString(v)
    if readable(v) and type(v)=="string" then return v end
end
local function sourceKey(s)
    if secret(s.sourceGUID) or secret(s.sourceCreatureID) or secret(s.name) then return end
    local guid=publicString(s.sourceGUID)
    if guid and guid~="" then return "g:"..guid end
    if num(s.sourceCreatureID) and s.sourceCreatureID>0 then return "c:"..s.sourceCreatureID end
    local name=publicString(s.name)
    if name and name~="" then return "n:"..name end
end
local function nativeOverall()
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionFromType then return end
    local ok,v=pcall(C_DamageMeter.GetCombatSessionFromType,0,0)
    if ok and not secret(v) and type(v)=="table" then return v end
end
local function publicOverall(data)
    if secret(data) or type(data)~="table" then return end
    local sources=data.combatSources
    if secret(sources) or type(sources)~="table" then return end
    local out={combatSources={},byKey={},totalAmount=0,maxAmount=0}
    if num(data.durationSeconds) then
        out.durationSeconds=data.durationSeconds
    elseif C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds then
        local ok,duration=pcall(C_DamageMeter.GetSessionDurationSeconds,0)
        if ok and num(duration) then out.durationSeconds=duration end
    end
    for _,src in ipairs(sources) do
        if secret(src) or type(src)~="table" or not num(src.totalAmount) then return end
        local key=sourceKey(src)
        if not key or out.byKey[key] then return end
        local row={
            name=publicString(src.name) or L.PLAYER,
            sourceGUID=publicString(src.sourceGUID),
            sourceCreatureID=num(src.sourceCreatureID) and src.sourceCreatureID or nil,
            classFilename=publicString(src.classFilename),
            specIconID=num(src.specIconID) and src.specIconID or nil,
            isLocalPlayer=readable(src.isLocalPlayer) and src.isLocalPlayer==true or false,
            totalAmount=src.totalAmount,
            runKey=key,
        }
        out.byKey[key]=row; out.combatSources[#out.combatSources+1]=row
        out.totalAmount=out.totalAmount+row.totalAmount
        out.maxAmount=math.max(out.maxAmount,row.totalAmount)
    end
    -- Native total is preferred only for detecting a reset of the shared source.
    out.nativeTotal=num(data.totalAmount) and data.totalAmount or out.totalAmount
    return out
end
local function publicSpellTotals(data)
    if secret(data) or type(data)~="table" then return end
    local spells=data.combatSpells
    if secret(spells) or type(spells)~="table" then return end
    local totals={}
    for _,sp in ipairs(spells) do
        if secret(sp) or type(sp)~="table" or not num(sp.spellID) or not num(sp.totalAmount) then return end
        totals[sp.spellID]=(totals[sp.spellID] or 0)+sp.totalAmount
    end
    return totals
end
local function baselineSpells(row)
    if not C_DamageMeter or not C_DamageMeter.GetCombatSessionSourceFromType then return end
    if not row.sourceGUID and not row.sourceCreatureID then return end
    local ok,data=pcall(C_DamageMeter.GetCombatSessionSourceFromType,0,0,row.sourceGUID,row.sourceCreatureID)
    if ok then return publicSpellTotals(data) end
end
local function clearOverallRun()
    if not overallRun then return end
    overallRun.baseline=nil; overallRun.last=nil; overallRun.pending=nil
    overallFrozen=false
end
local function localOverall(data)
    overallFrozen=false
    if not overallRun then return data end
    if overallRun.pending then overallFrozen=true; return {combatSources={},maxAmount=0,totalAmount=0} end
    local base=overallRun.baseline
    if not base then return data end
    local current=publicOverall(data)
    if not current then
        overallFrozen=true
        return overallRun.last or {combatSources={},maxAmount=0,totalAmount=0}
    end
    -- The game may start a new native overall automatically (e.g. logout).
    if (num(base.nativeTotal) and current.nativeTotal<base.nativeTotal)
        or (num(base.durationSeconds) and num(current.durationSeconds) and current.durationSeconds<base.durationSeconds) then
        clearOverallRun()
        return data
    end
    local result={combatSources={},totalAmount=0,maxAmount=0}
    if num(current.durationSeconds) and num(base.durationSeconds) then
        result.durationSeconds=math.max(0,current.durationSeconds-base.durationSeconds)
    end
    for _,row in ipairs(current.combatSources) do
        local previous=base.byKey[row.runKey]
        local amount=math.max(0,row.totalAmount-(previous and previous.totalAmount or 0))
        if amount>0 then
            row.totalAmount=amount
            if result.durationSeconds and result.durationSeconds>0 then row.amountPerSecond=amount/result.durationSeconds end
            result.combatSources[#result.combatSources+1]=row
            result.totalAmount=result.totalAmount+amount
            result.maxAmount=math.max(result.maxAmount,amount)
        end
    end
    table.sort(result.combatSources,function(a,b) return a.totalAmount>b.totalAmount end)
    overallRun.last=result
    return result
end
local function localOverallDetails(data,ctx)
    if not ctx.runKey or not overallRun or not overallRun.baseline then return data end
    if overallRun.pending or overallFrozen then return end
    local current=publicSpellTotals(data)
    if not current then return end
    local previous=overallRun.baseline.byKey[ctx.runKey]
    if previous and previous.totalAmount>0 and not previous.spells then return end
    local spells=previous and previous.spells or {}
    local out={combatSpells={},totalAmount=0,maxAmount=0}
    for id,total in pairs(current) do
        local value=math.max(0,total-(spells[id] or 0))
        if value>0 then
            out.combatSpells[#out.combatSpells+1]={spellID=id,totalAmount=value}
            out.totalAmount=out.totalAmount+value; out.maxAmount=math.max(out.maxAmount,value)
        end
    end
    table.sort(out.combatSpells,function(a,b) return a.totalAmount>b.totalAmount end)
    return out
end
local function spellInfo(id)
    if not num(id) then return L.UNKNOWN_SPELL,UNKNOWN end
    if id==0 then return L.MELEE,ICONS.."Ability_MeleeDamage" end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok,info=pcall(C_Spell.GetSpellInfo,id)
        if ok and not secret(info) and type(info)=="table" then
            return readable(info.name) and info.name or L.UNKNOWN_SPELL, readable(info.iconID) and info.iconID or UNKNOWN
        end
    end
    if GetSpellInfo then
        local ok,name,_,icon=pcall(GetSpellInfo,id)
        if ok and readable(name) then return name,readable(icon) and icon or UNKNOWN end
    end
    return L.UNKNOWN_SPELL.." #"..id,UNKNOWN
end
local function fetchDetails(ctx)
    if ctx.demo then
        local total=ctx.amount or 1000
        local spells={}
        for i,id in ipairs({6603,133,116,585,172}) do
            local amount=math.floor(total*({.36,.25,.18,.12,.09})[i])
            spells[i]={spellID=id,totalAmount=amount,amountPerSecond=amount/10}
        end
        return {combatSpells=spells,totalAmount=total,maxAmount=spells[1].totalAmount}
    end
    if not C_DamageMeter or not modeSupported(ctx.mode) then return end
    if not ctx.guid and not ctx.creature then return end
    local fn,session
    if ctx.history then fn=C_DamageMeter.GetCombatSessionSourceFromID; session=ctx.history
    else fn=C_DamageMeter.GetCombatSessionSourceFromType; session=ctx.mode.session end
    if not fn then return end
    local ok,v=pcall(fn,session,ctx.mode.kind,ctx.guid,ctx.creature)
    if not ok and ctx.guid then ok,v=pcall(fn,session,ctx.mode.kind,ctx.guid) end
    if ok and not secret(v) and type(v)=="table" then return localOverallDetails(v,ctx) end
end
local function createSpellRow(p,i)
    local r=CreateFrame("Frame",nil,p); r:SetSize(494,26); r:SetPoint("TOPLEFT",13,-91-(i-1)*29)
    r.back=rect(r,"BACKGROUND",.11,.15,.19,.94); r.back:SetAllPoints()
    r.bar=CreateFrame("StatusBar",nil,r); r.bar:SetAllPoints(); r.bar:SetStatusBarTexture(TEX); r.bar:SetMinMaxValues(0,1)
    local top=CreateFrame("Frame",nil,r); top:SetAllPoints(); top:SetFrameLevel(r.bar:GetFrameLevel()+1)
    r.icon=top:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(24,24); r.icon:SetPoint("LEFT",2,0)
    r.name=label(top,12,1,1,1); r.name:SetPoint("LEFT",32,0); r.name:SetWidth(250); r.name:SetMaxLines(1)
    r.amount=label(top,12,1,1,1,"RIGHT"); r.amount:SetPoint("RIGHT",-83,0); r.amount:SetWidth(115)
    r.share=label(top,11,.84,.90,.95,"RIGHT"); r.share:SetPoint("RIGHT",-8,0); r.share:SetWidth(70)
    return r
end
refreshDetail=function()
    if not detail or not detail:IsShown() or not detail.ctx then return end
    local ctx=detail.ctx
    local data=fetchDetails(ctx)
    local spells=data and data.combatSpells
    if secret(spells) or type(spells)~="table" then spells=nil end
    local n=spells and #spells or 0
    detail.offset=clamp(detail.offset or 0,0,math.max(0,n-10))
    local total=data and data.totalAmount
    if not num(total) and not secret(total) and spells then
        total=0
        for _,sp in ipairs(spells) do
            if secret(sp) or type(sp)~="table" or not num(sp.totalAmount) then total=nil; break end
            total=total+sp.totalAmount
        end
    end
    local max=data and data.maxAmount
    if not num(max) and not secret(max) then max=1 end
    if num(max) and max<=0 then max=1 end
    for i,r in ipairs(detail.rows) do
        local sp=spells and spells[i+detail.offset]
        if not secret(sp) and type(sp)=="table" then
            local name,icon=spellInfo(sp.spellID)
            r.icon:SetTexture(icon); r.icon:SetTexCoord(.07,.93,.07,.93)
            r.name:SetText(name); valueText(r.amount,sp.totalAmount)
            if num(sp.totalAmount) and num(total) and total>0 then r.share:SetFormattedText("%.1f%%",100*sp.totalAmount/total) else r.share:SetText("-") end
            r.bar:SetStatusBarColor(ctx.mode.color[1],ctx.mode.color[2],ctx.mode.color[3],.35)
            r.bar:SetMinMaxValues(0,max)
            local v=sp.totalAmount; if not num(v) and not secret(v) then v=0 end
            r.bar:SetValue(v); r:Show()
        else r:Hide() end
    end
    detail.empty:SetShown(n==0)
    detail.empty:SetText(live and L.DETAIL_COMBAT or L.DETAIL_UNAVAILABLE)
    detail.footer:SetText(n>0 and (string.format("%d–%d / %d",detail.offset+1,math.min(n,detail.offset+10),n).."  •  "..L.SCROLL) or "")
end
showDetail=function(f,source)
    if secret(source) or type(source)~="table" then return end
    if not detail then
        local p=CreateFrame("Frame",nil,UIParent); detail=p
        p:SetSize(520,420); p:SetPoint("CENTER"); p:SetFrameStrata("DIALOG"); p:SetClampedToScreen(true)
        p:EnableMouse(true); p:EnableMouseWheel(true); p:SetMovable(true); p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart",p.StartMoving); p:SetScript("OnDragStop",p.StopMovingOrSizing)
        p:SetScript("OnMouseWheel",function(_,d) p.offset=math.max(0,p.offset-d); refreshDetail() end)
        local back=rect(p,"BACKGROUND",.045,.065,.085,.99); back:SetAllPoints(); border(p,.25,.40,.44,1)
        p.line=rect(p,"ARTWORK",1,1,1,1); p.line:SetPoint("TOPLEFT"); p.line:SetPoint("TOPRIGHT"); p.line:SetHeight(3)
        p.title=label(p,20,1,1,1); p.title:SetPoint("TOPLEFT",15,-14); p.title:SetWidth(450); p.title:SetMaxLines(1)
        p.sub=label(p,12,.72,.83,.88); p.sub:SetPoint("TOPLEFT",15,-44); p.sub:SetWidth(490)
        local close=button(p,"X",26,26,function() p:Hide() end); close:SetPoint("TOPRIGHT",-10,-10)
        local a=label(p,11,.67,.78,.82); a:SetPoint("TOPLEFT",17,-70); a:SetText(L.ABILITY)
        local b=label(p,11,.67,.78,.82,"RIGHT"); b:SetPoint("TOPRIGHT",-94,-70); b:SetText(L.TOTAL)
        local c=label(p,11,.67,.78,.82,"RIGHT"); c:SetPoint("TOPRIGHT",-20,-70); c:SetText(L.SHARE)
        p.rows={}; for i=1,10 do p.rows[i]=createSpellRow(p,i) end
        p.empty=label(p,13,.70,.80,.85,"CENTER"); p.empty:SetPoint("CENTER"); p.empty:SetWidth(470); p.empty:SetWordWrap(true)
        p.footer=label(p,11,.65,.75,.81); p.footer:SetPoint("BOTTOMLEFT",15,11)
    end
    local m=MODES[db.windows[f.id].mode]
    local name=readable(source.name) and source.name or L.PLAYER
    detail.ctx={mode=m,history=f.historyID,demo=demo and not f.historyID,
        guid=readable(source.sourceGUID) and source.sourceGUID or nil,
        creature=num(source.sourceCreatureID) and source.sourceCreatureID or nil,
        amount=num(source.totalAmount) and source.totalAmount or nil,
        runKey=not f.historyID and m.kind==0 and m.session==0 and source.runKey or nil}
    detail.title:SetText(name); detail.sub:SetText(m.title.."  •  "..(f.historyName or L.LIVE_CURRENT))
    detail.line:SetColorTexture(m.color[1],m.color[2],m.color[3],1)
    detail.offset=0; detail:Show(); refreshDetail()
end
refresh=function()
    if not db or db.hidden then return end
    local cache={}
    for id,f in pairs(windows) do
        if f:IsShown() then
            local m=db.windows[id].mode; local key=f.historyID and (m..":"..f.historyID) or m; local data=cache[key]
            if data==nil then
                if not modeSupported(MODES[m]) and not demo then
                    data=nil
                elseif f.historyID then
                    if C_DamageMeter and C_DamageMeter.GetCombatSessionFromID then
                        local ok,v=pcall(C_DamageMeter.GetCombatSessionFromID,f.historyID,MODES[m].kind)
                        if ok and not secret(v) then data=v end
                    end
                elseif demo then data=demoData(m)
                elseif C_DamageMeter and C_DamageMeter.GetCombatSessionFromType then
                    local a=MODES[m]
                    local ok,v=pcall(C_DamageMeter.GetCombatSessionFromType,a.session,a.kind)
                    if ok and not secret(v) then data=v end
                end
                if m==2 and not f.historyID and not demo then data=localOverall(data) end
                cache[key]=data or false
            end
            updateWindow(f,data or nil,live and not demo and not f.historyID)
            if m==2 and not f.historyID and not demo and overallRun and (overallRun.pending or overallFrozen) then
                f.state:SetText(L.OVERALL_PAUSED)
                f.footer:SetText(overallRun.pending and L.OVERALL_PENDING or L.OVERALL_AFTER_COMBAT)
                if not data or not data.combatSources or #data.combatSources==0 then
                    f.empty:SetText(overallRun.pending and L.OVERALL_PENDING or L.OVERALL_AFTER_COMBAT)
                end
            end
            if not f.historyID then f.mode.t:SetText(MODES[m].title.."  v") end
            if f.historyID then
                f.state:SetText("HIST."); f.state:SetTextColor(ACC[1],ACC[2],ACC[3])
                f.mode.t:SetText(MODES[m].title.."  v")
                f.footer:SetText(f.historyName or L.HISTORY)
                if not data then f.empty:SetText(L.FIGHT_UNAVAILABLE) end
            end
        end
    end
    refreshDetail()
end
layout=function()
    if not db then return end
    local w,h=screenSize()
    if not w then layoutPending=true; return end
    layoutPending=false
    lastLayoutWidth,lastLayoutHeight=w,h
    for _,id in ipairs(ids()) do
        if root(id)==id then local c=db.windows[id]; setGroupSize(id,c.width,c.rows,false) end
    end
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
        if not f.moving then f:ClearAllPoints() end
        if c.parent and windows[c.parent] then
            f:SetPoint("TOPLEFT",windows[c.parent],"BOTTOMLEFT",0,-GAP)
        elseif not f.moving then
            if c.centerOnLayout then
                c.x=(w-c.width)/2; c.y=-(h-groupHeight(id))/2
                c.centerOnLayout=nil
            end
            local x=clamp(c.x,0,math.max(0,w-c.width))
            local y=clamp(c.y,-math.max(0,h-groupHeight(id)),0)
            f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",x,y)
        end
        local m=MODES[c.mode]
        f.mode.t:SetText(m.title.."  v"); decorate(f.mode,m.icon,m.color,nil,true); f.amountHead:SetText(m.amount); f.rateHead:SetText(m.rate)
        paintLock(f.lock,locked(id))
        f.accent:SetColorTexture(ACC[1],ACC[2],ACC[3],1)
        f.brand:SetTextColor(ACC[1],ACC[2],ACC[3])
        f.headBg:SetColorTexture(HEADER[1],HEADER[2],HEADER[3],1)
        for _,row in ipairs(f.rows) do row.mark:SetColorTexture(ACC[1],ACC[2],ACC[3],1) end
        f.resize:SetShown(not locked(id))
        f:EnableMouseWheel(true); f:SetShown(not db.hidden)
    end
    local seen={} for _,id in ipairs(ids()) do place(id,seen) end
end
cursorUI=function()
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    return x/scale,y/scale
end
local function startMove(id)
    if locked(id) or draggingRoot or resizeDrag then return end
    local r=root(id); local f=windows[r]
    local x,y=cursorUI()
    savePos(r)
    local cfg=db.windows[r]
    draggingRoot=r; f.moving=true
    dragState={x=x,y=y,left=cfg.x,top=cfg.y}
    hideDockPreview()
end
local function updateDrag()
    local r=draggingRoot
    if not r or not dragState or not windows[r] then return end
    local f,c=windows[r],db.windows[r]
    local x,y=cursorUI()
    c.x=clamp(dragState.left+x-dragState.x,0,math.max(0,UIParent:GetWidth()-c.width))
    c.y=clamp(dragState.top+y-dragState.y,-math.max(0,UIParent:GetHeight()-groupHeight(r)),0)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",c.x,c.y)
    local target,side=findDock(r)
    dragState.target,dragState.side=target,side
    showDockPreview(target,side)
end
local function stopMove(id)
    local r=draggingRoot
    if not r then return end
    local f=windows[r]
    -- Commit exactly the last visibly indicated candidate. Recomputing
    -- after native StopMoving can change frame geometry and lose the dock.
    local target,side=dragState and dragState.target,dragState and dragState.side
    if f then f.moving=false end
    draggingRoot=nil; dragState=nil; hideDockPreview()
    if f and target and windows[target] and dock(r,target,side) then return end
    layout(); refresh()
end
local function tickResize()
    if not resizeDrag then return end
    local d=resizeDrag
    if not windows[d.id] or locked(d.id) or db.hidden then resizeDrag=nil; return end
    local x,y=cursorUI()
    local w,rows=setGroupSize(d.id,d.width+x-d.x,d.rows+(d.y-y)/ROW)
    if w~=d.lastWidth or rows~=d.lastRows then
        d.lastWidth,d.lastRows=w,rows
        layout(); refresh()
    end
end
local function endResize()
    if resizeDrag then tickResize(); resizeDrag=nil end
end
makeWindow=function(id)
    if windows[id] then return end
    -- Anonymous, manually anchored windows are not subject to the game's
    -- named-frame layout cache or independent native screen clamping.
    local f=CreateFrame("Frame",nil,UIParent)
    windows[id]=f; f.id=id; f.rows={}; f.offset=0; f:Hide()
    f:SetFrameStrata("MEDIUM"); f:SetMovable(true); f:SetResizable(true); f:SetClampedToScreen(false)
    if f.SetResizeBounds then f:SetResizeBounds(MINW,TOP+ROW+FOOT,MAXW,TOP+ROW*MAXROWS+FOOT) end
    f:EnableMouse(true)
    local bg=rect(f,"BACKGROUND",.045,.061,.082,.91); bg:SetAllPoints()
    border(f,.25,.35,.40,.85)
    local accent=rect(f,"ARTWORK",ACC[1],ACC[2],ACC[3],1); f.accent=accent; accent:SetPoint("TOPLEFT",1,-1); accent:SetPoint("TOPRIGHT",-1,-1); accent:SetHeight(2)
    local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",2,-3); header:SetPoint("TOPRIGHT",-2,-3); header:SetHeight(33)
    local headBg=rect(header,"BACKGROUND",HEADER[1],HEADER[2],HEADER[3],1); f.headBg=headBg; headBg:SetAllPoints()
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() startMove(id) end); header:SetScript("OnDragStop",function() stopMove(id) end)
    local brand=label(header,11,ACC[1],ACC[2],ACC[3]); f.brand=brand; brand:SetPoint("LEFT",8,0); brand:SetText("RM")
    f.mode=button(header,"",182,25,function(b) showMenu(b,id,"mode") end,L.MODE_TOOLTIP)
    f.mode:SetPoint("LEFT",brand,"RIGHT",8,0)
    f.controls=button(header,"+",26,25,function(b) showMenu(b,id,"windows") end,L.WINDOW_CONTROL)
    f.controls:SetPoint("RIGHT",-5,0)
    f.lock=button(header,"",26,25,function()
        endResize()
        local c=db.windows[root(id)]; c.locked=not c.locked; layout()
    end,L.LOCK_TOOLTIP)
    createLockIcon(f.lock)
    f.lock:SetPoint("RIGHT",f.controls,"LEFT",-4,0)
    f.history=button(header,"",26,25,function(b)
        historyPage=1; showMenu(b,id,"history")
    end,L.HISTORY_TOOLTIP)
    createHistoryIcon(f.history)
    f.history:SetPoint("RIGHT",f.lock,"LEFT",-4,0)
    f.state=label(header,10,.62,.70,.77,"RIGHT"); f.state:SetPoint("RIGHT",f.history,"LEFT",-5,0)
    f.state:SetWidth(42)
    local cols=CreateFrame("Frame",nil,f); cols:SetPoint("TOPLEFT",6,-37); cols:SetPoint("TOPRIGHT",-6,-37); cols:SetHeight(18)
    local line=rect(cols,"ARTWORK",.19,.25,.30,.9); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    local nameHead=label(cols,10,.60,.70,.77); nameHead:SetPoint("LEFT",47,0); nameHead:SetText(L.PLAYER)
    local percentHead=label(cols,10,.60,.70,.77,"RIGHT"); percentHead:SetPoint("RIGHT",-8,0); percentHead:SetWidth(47); percentHead:SetText(L.SHARE)
    f.rateHead=label(cols,10,.60,.70,.77,"RIGHT"); f.rateHead:SetPoint("RIGHT",percentHead,"LEFT",-8,0); f.rateHead:SetWidth(80)
    f.amountHead=label(cols,10,.60,.70,.77,"RIGHT"); f.amountHead:SetPoint("RIGHT",f.rateHead,"LEFT",-10,0); f.amountHead:SetWidth(92)
    f.empty=label(f,12,.55,.65,.73,"CENTER"); f.empty:SetPoint("TOPLEFT",10,-TOP); f.empty:SetPoint("BOTTOMRIGHT",-10,FOOT); f.empty:SetText(L.READY_TEXT)
    local footer=CreateFrame("Frame",nil,f); footer:SetPoint("BOTTOMLEFT",6,2); footer:SetPoint("BOTTOMRIGHT",-6,2); footer:SetHeight(18)
    f.footer=label(footer,10,.59,.69,.76); f.footer:SetPoint("LEFT",3,0); f.footer:SetPoint("RIGHT",footer,"RIGHT",-125,0)
    f.timer=label(footer,10,.72,.82,.87,"RIGHT"); f.timer:SetPoint("RIGHT",-23,0)
    f.resize=button(footer,"/",18,17,function() end,L.RESIZE_TOOLTIP)
    f.resize:SetPoint("RIGHT")
    f.resize:SetScript("OnMouseDown",function(_,btn)
        if btn=="LeftButton" and not locked(id) and not draggingRoot and not resizeDrag then
            local x,y=cursorUI()
            local c=db.windows[root(id)]
            resizeDrag={id=id,x=x,y=y,width=c.width,rows=c.rows,lastWidth=c.width,lastRows=c.rows}
        end
    end)
    f.resize:SetScript("OnMouseUp",function(_,btn)
        if btn=="LeftButton" then endResize() end
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
        pendingReset=false; msg(L.RESET_UNAVAILABLE); return
    end
    local ok=pcall(C_DamageMeter.ResetAllCombatSessions)
    if ok then
        pendingReset=false
        clearOverallRun()
        for _,f in pairs(windows) do f.offset=0; f.historyID=nil; f.historyName=nil end
        msg(L.RESET_PREFIX..(resetReason or L.MANUAL)..")."); refresh()
    else
        resetRetry=resetRetry+1
        if resetRetry>=3 then pendingReset=false; msg(L.RESET_DENIED) end
    end
end
local function requestOverallReset()
    if not overallRun then return end
    overallRun.pending=true
    overallRun.last=nil
    if detail and detail.ctx and detail.ctx.mode.kind==0 and detail.ctx.mode.session==0 and not detail.ctx.history then detail:Hide() end
    for id,f in pairs(windows) do
        if db.windows[id].mode==2 and not f.historyID then f.offset=0 end
    end
end
local function performOverallReset()
    if not overallRun or not overallRun.pending or live or (InCombatLockdown and InCombatLockdown()) then return end
    local snap=publicOverall(nativeOverall())
    if not snap then return end -- wait until the client exposes usable numbers
    for _,row in ipairs(snap.combatSources) do
        if row.totalAmount>0 then row.spells=baselineSpells(row) end
    end
    overallRun.baseline=snap
    overallRun.last={combatSources={},maxAmount=0,totalAmount=0,durationSeconds=0}
    overallRun.pending=nil
    overallFrozen=false
    refresh()
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
        lastZone=key; if account then account.lastZones[characterKey]=key end
        if db.autoReset and ((previous and previous~="world") or key~="world") then
            requestOverallReset()
            performOverallReset()
        end
    end
end
showMenu=function(anchor,id,kind)
    if menu and menu:IsShown() and menu.anchor==anchor and kind~="historyPage" then menu:Hide(); return end
    if not menu then
        menu=CreateFrame("Frame",nil,UIParent)
        menu:SetFrameStrata("DIALOG"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
        local bg=rect(menu,"BACKGROUND",.055,.077,.10,.98); bg:SetAllPoints()
        border(menu,.28,.42,.45,1); menu.items={}
    end
    menu.anchor=anchor
    local opts={}
    local function item(t,fn,icon,color,portrait,selected) opts[#opts+1]={t,fn,icon,color,portrait,selected} end
    if kind=="history" or kind=="historyPage" then
        local f=windows[id]; local entries=availableHistory()
        item((not f.historyID and "> " or "   ")..L.LIVE_CURRENT,function()
            f.historyID=nil; f.historyName=nil; f.offset=0; refresh()
        end,ICONS.."INV_Misc_PocketWatch_01",nil,nil,not f.historyID)
        local pages=math.max(1,math.ceil(#entries/9))
        historyPage=clamp(historyPage,1,pages)
        if #entries==0 then item(L.NO_FIGHTS,function() end) end
        for i=(historyPage-1)*9+1,math.min(#entries,historyPage*9) do
            local e=entries[i]
            item((f.historyID==e.id and "> " or "   ")..e.name,function()
                f.historyID=e.id; f.historyName=e.name; f.offset=0; refresh()
            end,MOB_ICON,nil,e.portrait,f.historyID==e.id)
        end
        if historyPage>1 then item(L.PREV_PAGE,function() historyPage=historyPage-1; showMenu(anchor,id,"historyPage") end) end
        if historyPage<pages then item(L.NEXT_PAGE,function() historyPage=historyPage+1; showMenu(anchor,id,"historyPage") end) end
    elseif kind=="mode" then
        for i,m in ipairs(MODES) do
            local mode=i
            item((db.windows[id].mode==mode and "> " or "   ")..m.title,function()
                db.windows[id].mode=mode; windows[id].offset=0; layout(); refresh()
            end,m.icon,m.color,nil,db.windows[id].mode==mode)
        end
    else
        item(L.ATTACH_WINDOW,function()
            addWindow(id,(db.windows[id].mode%#MODES)+1,true)
        end)
        item(L.FREE_WINDOW,function()
            addWindow(id,(db.windows[id].mode%#MODES)+1,false)
        end)
        if db.windows[id].parent then item(L.DETACH,function() separate(id) end) end
        if not locked(id) then
            for _,target in ipairs(ids()) do
                local other=target
                if root(other)==other and other~=root(id) then
                    item(L.ATTACH_GROUP..other.." "..MODES[db.windows[other].mode].title,function() dock(id,other) end)
                end
            end
        end
        item(L.CLOSE_WINDOW,function() closeWindow(id) end)
        item(L.SETTINGS,showGuide)
        item(L.RESET_ALL,function()
            if StaticPopup_Show then StaticPopup_Show("RCOMBATMETER_RESET") else requestReset(L.MANUAL) end
        end)
    end
    local menuWidth=(kind=="history" or kind=="historyPage") and 320 or 268
    for _,b in ipairs(menu.items) do b:Hide() end
    for i,opt in ipairs(opts) do
        local b=menu.items[i]
        if not b then b=button(menu,"",258,24,function() end); menu.items[i]=b end
        b:SetWidth(menuWidth-10); b:ClearAllPoints(); b:SetPoint("TOPLEFT",5,-5-(i-1)*26); b.t:SetText(opt[1])
        decorate(b,opt[3],opt[4],opt[5],opt[6])
        local action=opt[2]; b:SetScript("OnClick",function() menu:Hide(); action() end); b:Show()
    end
    menu:SetSize(menuWidth,10+#opts*26)
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
    local w,h=screenSize()
    local x=math.max(0,(w or 448)-448)
    local rows=h and clamp(math.floor((h-120-n*(TOP+FOOT+GAP))/(n*ROW)),1,5) or 5
    local y=h and -math.min(140,math.max(0,h-(60+n*(TOP+rows*ROW+FOOT+GAP)))) or -140
    local prev
    for i=1,n do
        local id=newConfig(i,x,y,prev); db.windows[id].rows=rows
        if not w and not prev then db.windows[id].centerOnLayout=true end
        makeWindow(id); prev=id
    end
    layout(); refresh()
end
local function updateTheme()
    layout(); refresh()
    if guide then
        guide.accentLine:SetColorTexture(ACC[1],ACC[2],ACC[3],1)
        for _,t in ipairs(guide.accentLabels) do t:SetTextColor(ACC[1],ACC[2],ACC[3]) end
        guide.accentColor.swatch:SetColorTexture(ACC[1],ACC[2],ACC[3],1)
        guide.headerColor.swatch:SetColorTexture(HEADER[1],HEADER[2],HEADER[3],1)
    end
end
local function chooseColor(key,target)
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        msg(L.COLOR_UNAVAILABLE); return
    end
    local old={target[1],target[2],target[3]}
    local function apply(a,b,c)
        target[1],target[2],target[3]=a,b,c
        db[key]={a,b,c}; updateTheme()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r=old[1],g=old[2],b=old[3],hasOpacity=false,
        swatchFunc=function() apply(ColorPickerFrame:GetColorRGB()) end,
        cancelFunc=function() apply(old[1],old[2],old[3]) end
    })
end
showGuide=function()
    if menu then menu:Hide() end
    if not guide then
        guide=CreateFrame("Frame","RCombatMeterGuide",UIParent)
        guide:SetSize(540,635); guide:SetPoint("CENTER"); guide:SetFrameStrata("DIALOG"); guide:SetClampedToScreen(true)
        guide:EnableMouse(true); guide:SetMovable(true); guide:RegisterForDrag("LeftButton")
        guide:SetScript("OnDragStart",guide.StartMoving); guide:SetScript("OnDragStop",guide.StopMovingOrSizing)
        local bg=rect(guide,"BACKGROUND",.055,.072,.095,.99); bg:SetAllPoints()
        border(guide,.25,.43,.45,1)
        guide.accentLabels={}
        local line=rect(guide,"ARTWORK",ACC[1],ACC[2],ACC[3],1); guide.accentLine=line; line:SetPoint("TOPLEFT",1,-1); line:SetPoint("TOPRIGHT",-1,-1); line:SetHeight(3)
        local kicker=label(guide,11,ACC[1],ACC[2],ACC[3]); kicker:SetPoint("TOPLEFT",22,-19); kicker:SetText("R-COMBATMETER"); table.insert(guide.accentLabels,kicker)
        local title=label(guide,24,1,1,1); title:SetPoint("TOPLEFT",22,-40); title:SetText(L.GUIDE_TITLE)
        local sub=label(guide,12,.64,.74,.80); sub:SetPoint("TOPLEFT",22,-78); sub:SetText(L.GUIDE_SUB)
        local function paragraph(y,titleText,body)
            local t=label(guide,13,ACC[1],ACC[2],ACC[3]); t:SetPoint("TOPLEFT",22,-y); t:SetText(titleText); table.insert(guide.accentLabels,t)
            local p=label(guide,12,.82,.87,.91); p:SetWordWrap(true); p:SetJustifyV("TOP"); p:SetPoint("TOPLEFT",22,-y-22); p:SetWidth(496); p:SetText(body)
        end
        paragraph(112,L.LAYOUT, L.LAYOUT_BODY)
        local single=button(guide,L.PRESET_ONE,152,32,function() preset(1) end); single:SetPoint("TOPLEFT",22,-183)
        local dual=button(guide,L.PRESET_TWO,152,32,function() preset(2) end); dual:SetPoint("LEFT",single,"RIGHT",10,0)
        local triple=button(guide,L.PRESET_THREE,172,32,function() preset(3) end); triple:SetPoint("LEFT",dual,"RIGHT",10,0)
        paragraph(235,L.AUTOMATION, L.AUTOMATION_BODY)
        guide.auto=button(guide,"",246,31,function()
            db.autoReset=not db.autoReset; showGuide()
        end); guide.auto:SetPoint("TOPLEFT",22,-306)
        guide.preview=button(guide,"",242,31,function()
            demo=not demo; if demo then demoClock=0 end; showGuide(); refresh()
        end); guide.preview:SetPoint("LEFT",guide.auto,"RIGHT",8,0)
        paragraph(355,L.LIVE_DATA, L.LIVE_BODY)
        local colorTitle=label(guide,13,ACC[1],ACC[2],ACC[3])
        colorTitle:SetPoint("TOPLEFT",22,-432); colorTitle:SetText(L.COLORS)
        table.insert(guide.accentLabels,colorTitle)
        local function colorButton(title,key,target,w)
            local b=button(guide,title,w,32,function() chooseColor(key,target) end)
            b.swatch=rect(b,"OVERLAY",target[1],target[2],target[3],1)
            b.swatch:SetPoint("LEFT",9,0); b.swatch:SetSize(16,16)
            return b
        end
        guide.accentColor=colorButton(L.ACCENT,"accentColor",ACC,176)
        guide.accentColor:SetPoint("TOPLEFT",22,-457)
        guide.headerColor=colorButton(L.HEADER,"headerColor",HEADER,176)
        guide.headerColor:SetPoint("LEFT",guide.accentColor,"RIGHT",8,0)
        local reset=button(guide,L.DEFAULT,128,32,function()
            for i=1,3 do ACC[i]=DEFAULT_ACC[i]; HEADER[i]=DEFAULT_HEADER[i] end
            db.accentColor=nil; db.headerColor=nil; updateTheme()
        end)
        reset:SetPoint("LEFT",guide.headerColor,"RIGHT",8,0)
        guide.profiles=button(guide,L.PROFILES,496,32,function() showProfiles() end)
        guide.profiles:SetPoint("TOPLEFT",22,-505)
        local finish=button(guide,L.FINISH,496,35,function()
            db.guideDone=true; demo=false; guide:Hide(); refresh()
        end); finish:SetPoint("BOTTOMLEFT",22,19)
        finish.bg:SetColorTexture(.12,.38,.36,1)
        local x=button(guide,"X",25,25,function() db.guideDone=true; demo=false; guide:Hide(); refresh() end); x:SetPoint("TOPRIGHT",-10,-10)
    end
    guide.profiles.t:SetText(L.PROFILES.."  •  "..(activeProfile or ""))
    guide.auto.t:SetText(L.AUTO_RESET..(db.autoReset and L.ON or L.OFF))
    guide.preview.t:SetText(L.DEMO_PREVIEW..(demo and L.ON or L.OFF))
    guide:Show()
end
local function clone(t)
    if type(t)~="table" then return t end
    local r={} for k,v in pairs(t) do r[k]=clone(v) end
    return r
end
applyProfile=function(name)
    if not account or not account.profiles[name] then return end
    if menu then menu:Hide() end
    if detail then detail:Hide() end
    draggingRoot=nil; dragState=nil; resizeDrag=nil; hideDockPreview()
    for _,f in pairs(windows) do f:Hide() end
    windows={}
    activeProfile=name; account.active[characterKey]=name
    db=account.profiles[name]
    local function restore(target,key,defaults)
        local saved=db[key]
        for i=1,3 do target[i]=type(saved)=="table" and type(saved[i])=="number" and clamp(saved[i],0,1) or defaults[i] end
    end
    restore(ACC,"accentColor",DEFAULT_ACC); restore(HEADER,"headerColor",DEFAULT_HEADER)
    db.windows=db.windows or {}; db.nextID=db.nextID or 0
    if db.autoReset==nil then db.autoReset=true end
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
    updateTheme()
    if guide and guide:IsShown() then showGuide() end
    refresh()
end
local function profileNames()
    local a={} for name in pairs(account.profiles) do a[#a+1]=name end
    table.sort(a)
    return a
end
local function confirmProfile(action,name)
    if StaticPopup_Show and StaticPopupDialogs then
        if profilePanel then profilePanel:Hide() end
        StaticPopup_Show(action=="delete" and "RCOMBATMETER_PROFILE_DELETE" or "RCOMBATMETER_PROFILE_RESET",name,nil,name)
    end
end
local function resetProfile(name)
    if not account.profiles[name] then return end
    account.profiles[name]={guideDone=true}
    if name==activeProfile then applyProfile(name) end
    showProfiles()
end
local function deleteProfile(name)
    if not account.profiles[name] then return end
    account.profiles[name]=nil
    for char,selected in pairs(account.active) do if selected==name then account.active[char]=nil end end
    if name==activeProfile then
        local fallback=account.profiles[characterKey] and characterKey or profileNames()[1]
        if not fallback then fallback=characterKey; account.profiles[fallback]={guideDone=true} end
        applyProfile(fallback)
    end
    showProfiles()
end
useProfile=function(name)
    if name==activeProfile then return end
    applyProfile(name); showProfiles()
end
showProfiles=function()
    if not profilePanel then
        local p=CreateFrame("Frame",nil,UIParent); profilePanel=p
        p:SetSize(470,424); p:SetPoint("CENTER"); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetClampedToScreen(true)
        p:EnableMouse(true); p:EnableMouseWheel(true); p:SetMovable(true); p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart",p.StartMoving); p:SetScript("OnDragStop",p.StopMovingOrSizing)
        p:SetScript("OnMouseWheel",function(_,d) p.offset=math.max(0,(p.offset or 0)-d); showProfiles() end)
        local bg=rect(p,"BACKGROUND",.045,.065,.085,.99); bg:SetAllPoints(); border(p,.25,.42,.45,1)
        local title=label(p,20,1,1,1); title:SetPoint("TOPLEFT",15,-14); title:SetText(L.PROFILES)
        local x=button(p,"X",26,26,function() p:Hide() end); x:SetPoint("TOPRIGHT",-10,-10)
        p.desc=label(p,12,.68,.80,.86); p.desc:SetPoint("TOPLEFT",15,-45); p.desc:SetWidth(440); p.desc:SetWordWrap(true); p.desc:SetText(L.PROFILE_DESC)
        p.items={}
        for i=1,7 do
            local b=button(p,"",440,30,function() end); b:SetPoint("TOPLEFT",15,-98-(i-1)*33)
            p.items[i]=b
        end
        p.page=label(p,11,.65,.75,.81); p.page:SetPoint("TOPLEFT",15,-335)
        local new=button(p,L.OWN_PROFILE,440,28,function()
            if not account.profiles[characterKey] then account.profiles[characterKey]={guideDone=true} end
            useProfile(characterKey); showProfiles()
        end); new:SetPoint("BOTTOMLEFT",15,48)
        local reset=button(p,L.RESET_PROFILE,215,30,function() confirmProfile("reset",activeProfile) end); reset:SetPoint("BOTTOMLEFT",15,12)
        local del=button(p,L.DELETE_PROFILE,215,30,function() confirmProfile("delete",activeProfile) end); del:SetPoint("BOTTOMRIGHT",-15,12)
    end
    local p=profilePanel; local names=profileNames()
    p.offset=clamp(p.offset or 0,0,math.max(0,#names-7))
    for i,b in ipairs(p.items) do
        local name=names[i+p.offset]
        if name then
            b.t:SetText((name==activeProfile and "> " or "   ")..name)
            b.t:SetTextColor(name==activeProfile and ACC[1] or .78,name==activeProfile and ACC[2] or .85,name==activeProfile and ACC[3] or .89)
            b:SetScript("OnClick",function() useProfile(name) end); b:Show()
        else b:Hide() end
    end
    p.page:SetText(string.format("%d–%d / %d",p.offset+1,math.min(#names,p.offset+7),#names).."  •  "..L.SCROLL)
    p:Show()
end
local function init()
    RCombatMeterProfiles=RCombatMeterProfiles or {}
    account=RCombatMeterProfiles
    account.profiles=account.profiles or {}; account.active=account.active or {}; account.portraits=account.portraits or {}; account.lastZones=account.lastZones or {}
    account.migrated=account.migrated or {}
    account.overallRuns=account.overallRuns or {}
    local name,realm
    if UnitFullName then name,realm=UnitFullName("player") end
    if not name and UnitName then name=UnitName("player") end
    if (UnitFullName or UnitName) and not name then return end
    if not realm or realm=="" then realm=GetRealmName and GetRealmName() or "Realm" end
    characterKey=(name or "Player").." - "..realm
    account.overallRuns[characterKey]=account.overallRuns[characterKey] or {}
    overallRun=account.overallRuns[characterKey]
    if not account.migrated[characterKey] then
        if not account.profiles[characterKey] then account.profiles[characterKey]=clone(RCombatMeterDB or {}) end
        account.lastZones[characterKey]=(RCombatMeterDB or {}).lastZone
        account.migrated[characterKey]=true
    end
    local selected=account.active[characterKey]
    if not selected or not account.profiles[selected] then
        selected=characterKey
        if not account.profiles[selected] then account.profiles[selected]={} end
    end
    lastZone=account.lastZones[characterKey]
    applyProfile(selected)
    if StaticPopupDialogs then
        StaticPopupDialogs.RCOMBATMETER_PROFILE_DELETE={
            text=L.PROFILE_DELETE_CONFIRM,button1=L.DELETE_PROFILE,button2=L.CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function(_,name) deleteProfile(name) end,
            OnCancel=function() showProfiles() end,
        }
        StaticPopupDialogs.RCOMBATMETER_PROFILE_RESET={
            text=L.PROFILE_RESET_CONFIRM,button1=L.RESET,button2=L.CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function(_,name) resetProfile(name) end,
            OnCancel=function() showProfiles() end,
        }
        StaticPopupDialogs.RCOMBATMETER_RESET={
            text=L.RESET_CONFIRM,
            button1=L.RESET,button2=L.CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function() requestReset(L.MANUAL) end,
        }
    end
    if not db.guideDone then demo=true; showGuide() end
    refresh()
end
SLASH_RCOMBATMETER1="/rcm"
SlashCmdList.RCOMBATMETER=function(command)
    if not db then return end
    local cmd=command:lower():match("^%s*(%S*)") or ""
    if cmd=="hide" then
        db.hidden=not db.hidden
        if db.hidden then if detail then detail:Hide() end; if menu then menu:Hide() end end
        layout(); refresh()
    elseif cmd=="demo" then demo=not demo; if demo then demoClock=0 end; if guide and guide:IsShown() then showGuide() end; refresh()
    elseif cmd=="reset" then if StaticPopup_Show then StaticPopup_Show("RCOMBATMETER_RESET") else requestReset(L.MANUAL) end
    elseif cmd=="lock" then
        local a=ids(); local state=not locked(a[1])
        for _,id in ipairs(a) do if root(id)==id then db.windows[id].locked=state end end
        layout()
    else showGuide() end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","DAMAGE_METER_COMBAT_SESSION_UPDATED","DAMAGE_METER_CURRENT_SESSION_UPDATED","DAMAGE_METER_RESET","LFG_COMPLETION_REWARD","CHALLENGE_MODE_COMPLETED","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED"}) do
    pcall(events.RegisterEvent,events,event)
end
local dirty,zoneAt,elapsed,checkElapsed= true,nil,0,0
events:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" and arg==ADDON then
        init()
    elseif event=="PLAYER_LOGIN" and not db then init()
    elseif not db then return
    elseif event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
        live=UnitAffectingCombat("player") or false
        zoneAt=GetTime()+0.8
        if event=="PLAYER_ENTERING_WORLD" then layout(); dirty=true end
    elseif event=="PLAYER_TARGET_CHANGED" then captureMob("target")
    elseif event=="UPDATE_MOUSEOVER_UNIT" then captureMob("mouseover")
    elseif event=="NAME_PLATE_UNIT_ADDED" and type(arg)=="string" then captureMob(arg)
    elseif event=="PLAYER_REGEN_DISABLED" then
        captureMob("target")
        live=true; dirty=true
        for _,f in pairs(windows) do if not f.historyID and MODES[db.windows[f.id].mode].session==1 then f.offset=0 end end
    elseif event=="PLAYER_REGEN_ENABLED" then live=false; dirty=true; captureMob("target")
    elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then layout(); dirty=true
    elseif event=="LFG_COMPLETION_REWARD" or event=="CHALLENGE_MODE_COMPLETED" then
        -- Keep the final run visible until the player actually leaves the instance.
        dirty=true
    elseif event=="DAMAGE_METER_RESET" then
        clearOverallRun()
        for _,f in pairs(windows) do f.offset=0; f.historyID=nil; f.historyName=nil end
        dirty=true
    else dirty=true end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not db then return end
    tickMob(dt)
    local w,h=screenSize()
    if w and (layoutPending or w~=lastLayoutWidth or h~=lastLayoutHeight) then
        layout(); dirty=true
    end
    if draggingRoot then
        if not windows[draggingRoot] or db.hidden then
            local f=windows[draggingRoot]
            if f then f.moving=false end
            draggingRoot=nil; dragState=nil; hideDockPreview()
        elseif IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            stopMove(draggingRoot)
        else updateDrag() end
    end
    if resizeDrag then
        tickResize()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then endResize() end
    end
    if demo then demoClock=demoClock+dt end
    elapsed=elapsed+dt; checkElapsed=checkElapsed+dt
    if zoneAt and GetTime()>=zoneAt then zoneAt=nil; checkZone(); dirty=true end
    if checkElapsed>=1 then
        checkElapsed=0
        if not mobCandidate then
            captureMob("target")
            if not mobCandidate and live and SetPortraitTextureFromCreatureDisplayID then
                -- Nameplate unit tokens are normal client-provided unit references.
                for i=1,40 do
                    captureMob("nameplate"..i)
                    if mobCandidate then break end
                end
            end
        end
        if pendingReset then performReset() end
        if not zoneAt then checkZone() end
        performOverallReset()
        dirty=true
    end
    if elapsed>=(demo and .12 or .20) and (dirty or live or demo) then
        elapsed=0; dirty=false; refresh()
    end
end)
