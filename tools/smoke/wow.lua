-- WarLegend RaidTool - a small simulated WoW client for tools/smoke.js (not shipped, runs in fengari = Lua 5.3).
-- It is NOT the game: frames draw nothing, the API answers with neutral values of the right type (read from
-- Blizzard's API documentation, tools/wow-api.js), a few functions are modelled by hand below. What it proves:
-- the files load, the handlers / commands / windows / tests run without a Lua error with those answers.
local API = ...
local M = { errors = {}, chat = {}, addon = {}, prints = {}, blocked = {}, sensitive = {}, now = 1000, combat = false }
SMOKE = M

---------------------------------------------------------------------------
-- API answers from Blizzard's documentation: typed neutral values
---------------------------------------------------------------------------
local function Answer(spec)
    if not spec or spec == "" then return nil end
    local out, n = {}, 0
    for c, opt in spec:gmatch("(%a)(%??)") do
        n = n + 1
        if opt == "?" then out[n] = nil
        elseif c == "b" then out[n] = false
        elseif c == "n" then out[n] = 0
        elseif c == "s" then out[n] = ""
        elseif c == "t" then out[n] = {}
        else out[n] = nil end
    end
    return table.unpack(out, 1, n)
end
M.Answer = Answer
M.calls = {}
local function Stub(name, spec)
    return function() M.calls[name] = (M.calls[name] or 0) + 1; return Answer(spec) end
end
Enum = {}
for name, fields in pairs(API.enums) do Enum[name] = fields end
Constants = {}
for name, values in pairs(API.consts) do Constants[name] = values end
for full, spec in pairs(API.fn) do
    local ns, fname = full:match("^([%w_]+)%.([%w_]+)$")
    if ns then
        _G[ns] = _G[ns] or {}
        _G[ns][fname] = Stub(full, spec)
    else
        _G[full] = Stub(full, spec)
    end
end

---------------------------------------------------------------------------
-- Lua 5.1 as WoW has it
---------------------------------------------------------------------------
unpack = table.unpack
loadstring = load
table.getn = function(t) return #t end
math.mod = math.fmod
do
    local fmt = string.format
    local INT = { d = true, i = true, x = true, X = true, o = true, c = true }
    -- WoW (5.1) accepts 2.5 for %d (cut to 2); 5.3 raises an error
    string.format = function(f, ...)
        local args = table.pack(...)
        local i = 0
        for flags, conv in tostring(f):gmatch("%%([-+ #0]*%d*%.?%d*)([%a%%])") do
            if conv ~= "%" then
                i = i + 1
                local v = args[i]
                if INT[conv] and type(v) == "number" and math.type(v) == "float" then
                    if v ~= v or v == math.huge or v == -math.huge then args[i] = 0 else args[i] = math.tointeger(v < 0 and math.ceil(v) or math.floor(v)) or 0 end
                end
            end
            local _ = flags
        end
        return fmt(f, table.unpack(args, 1, args.n))
    end
end
format = string.format
strfind, strsub, strlower, strupper, strlen, strrep, strbyte, strchar, strmatch, gsub, gmatch, strrev =
    string.find, string.sub, string.lower, string.upper, string.len, string.rep, string.byte, string.char, string.match,
    string.gsub, string.gmatch, string.reverse
floor, ceil, abs, max, min, sqrt, random, fmod, mod = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.random, math.fmod, math.fmod
tinsert, tremove, sort, getn = table.insert, table.remove, table.sort, table.getn
date, time, difftime = os.date, os.time, os.difftime
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tContains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function strtrim(s, chars)
    chars = chars and ("[" .. chars:gsub("[%]%^%-%%]", "%%%0") .. "]") or "%s"
    return (s:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", ""))
end
function strjoin(d, ...) return table.concat({ ... }, d) end
function strconcat(...) return table.concat({ ... }) end
function strsplit(d, s, n)
    s = tostring(s)
    local out, pos = {}, 1
    local pat = "[" .. d:gsub("[%]%^%-%%]", "%%%0") .. "]"
    while true do
        if n and #out == n - 1 then out[#out + 1] = s:sub(pos); break end
        local a, b = s:find(pat, pos)
        if not a then out[#out + 1] = s:sub(pos); break end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return table.unpack(out)
end
function strsplittable(d, s, n) return { strsplit(d, s, n) } end
function strlenutf8(s) local n = 0; for _ in tostring(s):gmatch("[^\128-\191]") do n = n + 1 end return n end
function tostringall(...) local t = table.pack(...); for i = 1, t.n do t[i] = tostring(t[i]) end return table.unpack(t, 1, t.n) end
function scrub(...) return ... end
bit = {
    band = function(a, b) return math.tointeger(a) & math.tointeger(b) end,
    bor = function(a, b) return math.tointeger(a) | math.tointeger(b) end,
    bxor = function(a, b) return math.tointeger(a) ~ math.tointeger(b) end,
    bnot = function(a) return ~math.tointeger(a) & 0xffffffff end,
    lshift = function(a, n) return (math.tointeger(a) << n) & 0xffffffff end,
    rshift = function(a, n) return (math.tointeger(a) & 0xffffffff) >> n end,
}
function debugprofilestop() return os.clock() * 1000 end
function debugprofilestart() end
-- debugstack(level): level 1 = the function calling debugstack, as in the game
function debugstack(level, top)
    local out = {}
    level = (level or 1) + 1
    for i = level, level + (top or 12) - 1 do
        local info = debug.getinfo(i, "Sl")
        if not info then break end
        local src = info.source:sub(1, 1) == "@" and info.source:sub(2) or info.short_src
        out[#out + 1] = src .. ":" .. (info.currentline or 0) .. ": in function"
    end
    return table.concat(out, "\n") .. "\n"
end
function geterrorhandler() return M.Error end
function seterrorhandler() end
function issecure() return false end
function issecurevariable() return false, nil end
function securecall(fn, ...) if type(fn) == "string" then fn = _G[fn] end return fn(...) end
function securecallfunction(fn, ...) return fn(...) end
function issecretvalue() return false end
function issecrettable() return false end
function canaccessvalue() return true end
function canaccesstable() return true end
function hasanysecretvalues() return false end
function forceinsecure() end
-- the hook runs after the original, its returns are dropped; the original must exist (the game raises an error)
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    if type(orig) ~= "function" then error("hooksecurefunc: " .. tostring(name) .. " is not a function", 2) end
    t[name] = function(...)
        local r = table.pack(orig(...))
        fn(...)
        return table.unpack(r, 1, r.n)
    end
end

function M.Error(err)
    local msg = tostring(err)
    for _, e in ipairs(M.errors) do if e.msg == msg then e.count = e.count + 1; return end end
    M.errors[#M.errors + 1] = { msg = msg, count = 1, phase = M.phase, trace = debug.traceback("", 2) }
end
-- every call into the addon goes through here: an error is recorded, as the game shows it
function M.Call(fn, ...)
    local ok, err = xpcall(fn, function(e) M.Error(e); return e end, ...)
    return ok, err
end

---------------------------------------------------------------------------
-- Widgets: every frame / region is a table with the documented methods (typed neutral answers),
-- the usual ones modelled: points, size, text, shown, scripts, events, attributes, children.
---------------------------------------------------------------------------
local Widget = {}
local frames, byEvent, allObjects = {}, {}, {}
M.frames = frames
local PROTECTED_CHANGE = { SetAttribute = true, SetPoint = true, ClearAllPoints = true, Show = true, Hide = true, SetParent = true,
    SetSize = true, SetWidth = true, SetHeight = true, SetScale = true, EnableMouse = true, SetAllPoints = true }
local WidgetMT = {
    __index = function(obj, k)
        local m = Widget[k]
        if m then
            if PROTECTED_CHANGE[k] and (rawget(obj, "__protected") or rawget(obj, "__implicit")) and M.combat then
                return function(...)
                    local how = rawget(obj, "__protected") and "" or ", implicitly protected (" .. tostring(rawget(obj, "__where") or "?") .. ")"
                    M.blocked[#M.blocked + 1] = k .. " on " .. tostring(obj:GetName() or obj.__type) .. how .. " (" .. (M.phase or "?") .. ")"
                    return m(...)
                end
            end
            return m
        end
        local spec = API.widget[k]
        if spec then return function() return Answer(spec) end end
        return nil
    end,
}

-- a protected frame makes its parents and the frames it is anchored to protected too (moving them would move it):
-- the game blocks their changes in combat as well
local function Restrict(o)
    while type(o) == "table" and o.__children and not rawget(o, "__implicit") and o ~= UIParent do
        rawset(o, "__implicit", true)
        o = o.__parent
    end
end

local function New(kind, name, parent, template)
    local o = setmetatable({ __type = kind, __name = name, __parent = parent, __shown = true, __points = {}, __children = {},
        __regions = {}, __scripts = {}, __attr = {}, __w = 0, __h = 0, __text = nil, __value = 0, __min = 0, __max = 1,
        __checked = false, __alpha = 1, __scale = 1, __level = 1, __strata = "MEDIUM", __template = template }, WidgetMT)
    if template and tostring(template):find("Secure") then o.__protected = true; Restrict(parent) end
    if parent and type(parent) == "table" and parent.__children then
        if kind == "FontString" or kind == "Texture" or kind == "Line" or kind == "MaskTexture" then
            parent.__regions[#parent.__regions + 1] = o
        else
            parent.__children[#parent.__children + 1] = o
        end
    end
    if type(name) == "string" then
        if parent and type(parent) == "table" and name:find("$parent", 1, true) then name = name:gsub("%$parent", parent:GetName() or "") end
        o.__name = name
        _G[name] = o
    end
    allObjects[#allObjects + 1] = o
    return o
end
M.New = New

local function Fire(o, script, ...)
    local fn = o.__scripts[script]
    if fn then return M.Call(fn, o, ...) end
end
M.Script = Fire

function Widget:GetName() return self.__name end
function Widget:GetDebugName() return self.__name or self.__type end
function Widget:GetObjectType() return self.__type end
function Widget:IsObjectType(t) return self.__type == t or t == "Frame" or t == "Region" or t == "ScriptObject" end
function Widget:IsForbidden() return false end
function Widget:IsProtected() return self.__protected or false, self.__protected or false end
function Widget:GetParent() return self.__parent end
function Widget:SetParent(p)
    if type(p) == "string" then p = _G[p] end
    self.__parent = p
    if p and p.__children then p.__children[#p.__children + 1] = self end
    if rawget(self, "__protected") or rawget(self, "__implicit") then Restrict(p) end
end
function Widget:GetChildren() return table.unpack(self.__children) end
function Widget:GetNumChildren() return #self.__children end
function Widget:GetRegions() return table.unpack(self.__regions) end
function Widget:GetNumRegions() return #self.__regions end
function Widget:Show()
    if self.__shown then return end
    self.__shown = true
    if self:IsVisible() then Fire(self, "OnShow") end
end
function Widget:Hide()
    if not self.__shown then return end
    local was = self:IsVisible()
    self.__shown = false
    if was then Fire(self, "OnHide") end
end
function Widget:SetShown(on) if on then self:Show() else self:Hide() end end
function Widget:IsShown() return self.__shown end
function Widget:IsVisible()
    local o = self
    while o do
        if not o.__shown then return false end
        o = o.__parent
    end
    return true
end
function Widget:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    if type(rel) == "string" then rel = _G[rel] end
    self.__points[#self.__points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
    if rel and (rawget(self, "__protected") or rawget(self, "__implicit")) then Restrict(rel) end
end
function Widget:ClearAllPoints() self.__points = {} end
function Widget:SetAllPoints(rel) self.__points = { { "TOPLEFT", rel }, { "BOTTOMRIGHT", rel } } end
function Widget:GetNumPoints() return #self.__points end
function Widget:GetPoint(i) local p = self.__points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Widget:GetPointByName(name) for _, p in ipairs(self.__points) do if p[1] == name then return table.unpack(p) end end end
function Widget:SetWidth(w) self.__w = tonumber(w) or 0 end
function Widget:SetHeight(h) self.__h = tonumber(h) or 0 end
function Widget:SetSize(w, h) self.__w, self.__h = tonumber(w) or 0, tonumber(h or w) or 0 end
function Widget:GetWidth() return self.__w end
function Widget:GetHeight() return self.__h end
function Widget:GetSize() return self.__w, self.__h end
function Widget:GetRect() return 0, 0, self.__w, self.__h end
function Widget:GetScaledRect() return 0, 0, self.__w, self.__h end
function Widget:GetLeft() return 100 end
function Widget:GetRight() return 100 + self.__w end
function Widget:GetTop() return 500 end
function Widget:GetBottom() return 500 - self.__h end
function Widget:GetCenter() return 100 + self.__w / 2, 500 - self.__h / 2 end
function Widget:SetScale(s) self.__scale = tonumber(s) or 1 end
function Widget:GetScale() return self.__scale end
function Widget:GetEffectiveScale() return self.__scale end
function Widget:SetAlpha(a) self.__alpha = tonumber(a) or 1 end
function Widget:GetAlpha() return self.__alpha end
function Widget:GetEffectiveAlpha() return self.__alpha end
function Widget:SetFrameLevel(l) self.__level = tonumber(l) or 1 end
function Widget:GetFrameLevel() return self.__level end
function Widget:SetFrameStrata(s) self.__strata = s end
function Widget:GetFrameStrata() return self.__strata end
function Widget:SetID(id) self.__id = id end
function Widget:GetID() return self.__id or 0 end
function Widget:SetScript(name, fn) self.__scripts[name] = fn end
function Widget:GetScript(name) return self.__scripts[name] end
function Widget:HasScript() return true end
function Widget:HookScript(name, fn)
    local old = self.__scripts[name]
    self.__scripts[name] = old and function(...) old(...); fn(...) end or fn
end
function Widget:RegisterEvent(ev)
    self.__events = self.__events or {}
    if not self.__events[ev] then
        self.__events[ev] = true
        local l = byEvent[ev] or {}
        byEvent[ev] = l
        l[#l + 1] = self
    end
    return true
end
function Widget:RegisterUnitEvent(ev) return Widget.RegisterEvent(self, ev) end
function Widget:UnregisterEvent(ev) if self.__events then self.__events[ev] = nil end end
function Widget:UnregisterAllEvents() self.__events = {} end
function Widget:IsEventRegistered(ev) return self.__events and self.__events[ev] or false end
function Widget:RegisterAllEvents() self.__allEvents = true; byEvent["*"] = byEvent["*"] or {}; table.insert(byEvent["*"], self) end
function Widget:SetAttribute(k, v) self.__attr[k] = v end
function Widget:GetAttribute(k) return self.__attr[k] end
function Widget:SetText(t) self.__text = t ~= nil and tostring(t) or nil end
function Widget:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function Widget:GetText() return self.__text end
function Widget:GetStringWidth() return #(self.__text or "") * 6 end
function Widget:GetUnboundedStringWidth() return #(self.__text or "") * 6 end
function Widget:GetStringHeight() return 12 end
function Widget:GetNumLines() return 1 end
function Widget:SetFont(f, s, fl) self.__font = { f, s, fl }; return true end
function Widget:GetFont() local f = self.__font or { "Fonts\\FRIZQT__.TTF", 12, "" }; return f[1], f[2], f[3] end
function Widget:SetFontObject(o) self.__fontObject = o end
function Widget:GetFontObject() return self.__fontObject or GameFontNormal end
function Widget:GetTextColor() return 1, 1, 1, 1 end
function Widget:SetChecked(c) self.__checked = c and true or false end
function Widget:GetChecked() return self.__checked end
function Widget:SetValue(v) self.__value = tonumber(v) or 0; Fire(self, "OnValueChanged", self.__value, false) end
function Widget:GetValue() return self.__value end
function Widget:SetMinMaxValues(a, b) self.__min, self.__max = tonumber(a) or 0, tonumber(b) or 1 end
function Widget:GetMinMaxValues() return self.__min, self.__max end
function Widget:GetNumber() return tonumber(self.__text or "") or 0 end
function Widget:SetNumber(n) self.__text = tostring(n) end
function Widget:HasFocus() return false end
function Widget:IsMouseOver() return false end
function Widget:IsMouseEnabled() return true end
function Widget:IsMovable() return true end
function Widget:IsResizable() return true end
function Widget:IsUserPlaced() return false end
function Widget:GetVerticalScroll() return 0 end
function Widget:GetVerticalScrollRange() return 0 end
function Widget:GetHorizontalScroll() return 0 end
function Widget:SetScrollChild(c) self.__scrollChild = c end
function Widget:GetScrollChild() return self.__scrollChild end
function Widget:SetTexture(t) self.__texture = t; return true end
function Widget:GetTexture() return self.__texture end
function Widget:GetTextureFilePath() return self.__texture end
function Widget:SetAtlas(a) self.__atlas = a; return true end
function Widget:GetAtlas() return self.__atlas end
function Widget:GetVertexColor() return 1, 1, 1, 1 end
function Widget:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
local function Child(self, key, kind)
    if not rawget(self, key) then rawset(self, key, New(kind, nil, self)) end
    return rawget(self, key)
end
function Widget:CreateFontString(name) return New("FontString", name, self) end
function Widget:CreateTexture(name) return New("Texture", name, self) end
function Widget:CreateMaskTexture(name) return New("MaskTexture", name, self) end
function Widget:CreateLine(name) return New("Line", name, self) end
function Widget:CreateAnimationGroup(name) return New("AnimationGroup", name, self) end
function Widget:CreateAnimation(kind, name) return New(kind or "Animation", name, self) end
function Widget:GetStatusBarTexture() return Child(self, "__sbt", "Texture") end
function Widget:GetFontString() return Child(self, "__fs", "FontString") end
function Widget:GetNormalTexture() return Child(self, "__nt", "Texture") end
function Widget:GetHighlightTexture() return Child(self, "__ht", "Texture") end
function Widget:GetPushedTexture() return Child(self, "__pt", "Texture") end
function Widget:GetDisabledTexture() return Child(self, "__dt", "Texture") end
function Widget:GetCheckedTexture() return Child(self, "__ct", "Texture") end
function Widget:GetThumbTexture() return Child(self, "__tt", "Texture") end
function Widget:GetNormalFontObject() return GameFontNormal end
function Widget:GetHighlightFontObject() return GameFontHighlight end
function Widget:GetCursorPosition() return 0 end
function Widget:GetMaxLetters() return 255 end
function Widget:IsPlaying() return false end
function Widget:GetDuration() return 0 end
function Widget:Play() end
function Widget:Stop() end
-- tooltip
function Widget:NumLines() return 0 end
function Widget:GetUnit() return nil end
function Widget:GetItem() return nil end
function Widget:GetSpell() return nil end
function Widget:IsOwned() return false end
function Widget:GetOwner() return self.__owner end
function Widget:SetOwner(o) self.__owner = o end
-- chat frame
function Widget:AddMessage(msg) M.prints[#M.prints + 1] = tostring(msg) end
-- backdrop (BackdropTemplate)
function Widget:SetBackdrop(b) self.__backdrop = b end
function Widget:GetBackdrop() return self.__backdrop end
function Widget:SetBackdropColor() end
function Widget:SetBackdropBorderColor() end
function Widget:GetBackdropColor() return 0, 0, 0, 1 end
function Widget:GetBackdropBorderColor() return 0, 0, 0, 1 end
function Widget:ApplyBackdrop() end
-- a template's parts the addon reads
local TEMPLATE_PARTS = {
    UIPanelScrollFrameTemplate = { ScrollBar = "Slider" },
    ScrollFrameTemplate = { ScrollBar = "Slider" },
    UICheckButtonTemplate = { Text = "FontString", text = "FontString" },
    ChatConfigCheckButtonTemplate = { Text = "FontString" },
    UIPanelButtonTemplate = { Text = "FontString" },
    InputBoxTemplate = {},
    UIPanelCloseButton = {},
    OptionsSliderTemplate = { Text = "FontString", Low = "FontString", High = "FontString" },
    MinimalSliderWithSteppersTemplate = { Slider = "Slider", LeftText = "FontString", RightText = "FontString" },
    BasicFrameTemplateWithInset = { TitleText = "FontString", CloseButton = "Button", Inset = "Frame" },
    PortraitFrameTemplate = { TitleContainer = "Frame", CloseButton = "Button" },
    ButtonFrameTemplate = { TitleContainer = "Frame", CloseButton = "Button", Inset = "Frame" },
    TooltipBackdropTemplate = {},
}

function CreateFrame(kind, name, parent, template, id)
    local o = New(kind or "Frame", name, parent or nil, template)
    if template then
        for t in tostring(template):gmatch("[^,%s]+") do
            for key, k in pairs(TEMPLATE_PARTS[t] or {}) do rawset(o, key, New(k, nil, o)) end
        end
        if o.ScrollBar then rawset(o.ScrollBar, "ScrollUpButton", New("Button", nil, o.ScrollBar)); rawset(o.ScrollBar, "ScrollDownButton", New("Button", nil, o.ScrollBar)) end
        if o.TitleContainer then rawset(o.TitleContainer, "TitleText", New("FontString", nil, o.TitleContainer)) end
    end
    if id then o.__id = id end
    for i = 2, 6 do
        local info = debug.getinfo(i, "Sl")
        if not info then break end
        if info.source:find("Interface/AddOns/", 1, true) then o.__where = info.source:match("([^/]+%.lua)$") .. ":" .. info.currentline; break end
    end
    frames[#frames + 1] = o
    return o
end
-- FrameXML pools, as Blizzard_SharedXMLBase/Pools.lua: a released object is reused, createFunc / resetFunc are read when
-- needed (HereBeDragons-Pins sets them after making its pool), the reset runs on a new object too
local Pool = {}
Pool.__index = Pool
function Pool:Acquire()
    local o = table.remove(self.inactiveObjects)
    local new = o == nil
    if new then
        o = self.createFunc(self)
        self.resetFunc(self, o, true)
    end
    self.activeObjects[o] = true
    self.activeObjectCount = self.activeObjectCount + 1
    return o, new
end
function Pool:Release(o)
    if not self.activeObjects[o] then return false end
    self.resetFunc(self, o)
    self.inactiveObjects[#self.inactiveObjects + 1] = o
    self.activeObjects[o] = nil
    self.activeObjectCount = self.activeObjectCount - 1
    return true
end
function Pool:ReleaseAll() for o in pairs(self.activeObjects) do self:Release(o) end end
function Pool:EnumerateActive() return pairs(self.activeObjects) end
function Pool:GetNextActive(o) return next(self.activeObjects, o) end
function Pool:IsActive(o) return self.activeObjects[o] ~= nil end
function Pool:GetNumActive() return self.activeObjectCount end
local function NewPool(create, reset)
    return setmetatable({ createFunc = create, resetFunc = reset or function() end, activeObjects = {}, inactiveObjects = {}, activeObjectCount = 0 }, Pool)
end
local function HideAndClear(_, r) r:Hide(); r:ClearAllPoints() end
function CreateFramePool(kind, parent, template, reset)
    return NewPool(function() return CreateFrame(kind or "Frame", nil, parent, template) end, reset or HideAndClear)
end
function CreateObjectPool(create, reset) return NewPool(create, reset) end
function CreateUnsecuredRegionPoolInstance(template, create, reset)
    local p = NewPool(create, reset or HideAndClear)
    p.GetTemplate = function() return template end
    return p
end
local SLOTS = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8,
    WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15,
    MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19 }
function GetInventorySlotInfo(name) local id = SLOTS[name]; if id then return id, "" end end
function CreateFont(name) local f = New("Font", name); return f end
function CreateFontFamily(name) return New("Font", name) end

---------------------------------------------------------------------------
-- The world: one player, an optional raid, a guild of 30, a virtual clock
---------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
M.player = { name = "Smoketest", realm = "Forever", class = "MAGE", level = 60 }
M.group = {} -- { name, class } (raid1..raidN, the player first)
M.guild = {}
function M.SetGuild(n)
    M.guild = {}
    for i = 1, n do M.guild[i] = { name = "Guildie" .. i .. "-Forever", class = CLASSES[(i % #CLASSES) + 1], online = i % 3 ~= 0, rank = i % 5, level = 60 - (i % 4) } end
end
M.SetGuild(30)

local function UnitIndex(unit)
    if type(unit) ~= "string" then return nil end
    unit = unit:lower()
    if unit == "player" then return 1 end
    local n = unit:match("^raid(%d+)$") or unit:match("^party(%d+)$")
    if n then
        n = tonumber(n)
        if unit:find("^party") then n = n + 1 end
        if M.group[n] then return n end
    end
    -- the other unit tokens (raid5target, nameplate3, mouseover...) are no names: the group is not searched (the game
    -- does this in C; a search here made the roster code of the PvP addon look slower than it is)
    if unit:find("^raid%d") or unit:find("^party%d") or unit:find("^nameplate%d") or unit:find("target$")
        or unit == "focus" or unit == "mouseover" or unit == "pet" then return nil end
    for i, p in ipairs(M.group) do if p.name == unit or p.name:lower() == unit then return i end end
    return nil
end
-- other units (nameplateN, target, focus, mouseover...): M.units[token] = { name, class, guid, enemy, pvp, npc, hp, hpMax,
-- level, classification }; the same table under two tokens is the same unit
M.units = {}
local function Who(unit)
    local i = UnitIndex(unit)
    if i == 1 or (i == nil and type(unit) == "string" and unit:lower() == "player") then return M.player end
    if i then return M.group[i] end
    return type(unit) == "string" and M.units[unit:lower()] or nil
end
M.Who = Who

function GetTime() return M.now end
function GetServerTime() return 1792000000 + math.floor(M.now) end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, 20, 20 end
function GetBuildInfo() return "1.60.1", "70450", "Oct 16 2026", 16001, "", "", 16001 end
function GetLocale() return M.locale or "enUS" end
function GetCurrentRegion() return 3 end
function GetCurrentRegionName() return "EU" end
function GetRealmName() return M.player.realm end
function GetNormalizedRealmName() return M.player.realm end
function IsLoggedIn() return M.loggedIn end
function InCombatLockdown() return M.combat end
function UnitAffectingCombat(u) return M.combat and Who(u) ~= nil end
function IsInInstance() return M.instance ~= nil, M.instance or "none" end
function GetInstanceInfo() return M.instance and (M.instanceName or "Molten Core") or "Kalimdor", M.instance or "none", 0, "", 40, 0, false, M.instance and (M.instanceID or 409) or 1 end
function IsInGuild() return true end
function GetGuildInfo(u) if Who(u) == M.player then return "War Legend", "Officier", 1, M.player.realm end end
function GetNumGuildMembers() return #M.guild, #M.guild, #M.guild end
function GetGuildRosterInfo(i)
    local g = M.guild[i]
    if not g then return nil end
    return g.name, "Rank" .. g.rank, g.rank, g.level, g.class:sub(1, 1) .. g.class:sub(2):lower(), "Orgrimmar", "", "", g.online, 0, g.class, 0, 0, false, false, 0, "Player-1-" .. i
end
function GetGuildRosterLastOnline() return 0, 1, 2, 3 end
function GuildControlGetNumRanks() return 5 end
function GuildControlGetRankName(i) return "Rank" .. tostring(i) end
function CanEditOfficerNote() return true end
function IsInRaid() return #M.group > 5 end
function IsInGroup() return #M.group > 1 end
function GetNumGroupMembers() return #M.group > 1 and #M.group or 0 end
function GetNumSubgroupMembers() return #M.group > 1 and math.min(#M.group - 1, 4) or 0 end
function UnitInRaid(u) local i = UnitIndex(u); return IsInRaid() and i and i - 1 or nil end
function UnitInParty(u) return IsInGroup() and UnitIndex(u) ~= nil end
function GetRaidRosterInfo(i)
    local p = M.group[i]
    if not p then return nil end
    return p.name, i == 1 and 2 or 0, math.floor((i - 1) / 5) + 1, 60, p.class, p.class, "Molten Core", true, false, nil, false, "DAMAGER"
end
function UnitIsGroupLeader(u) return UnitIndex(u) == 1 end
function UnitIsGroupAssistant(u) return UnitIndex(u) == 1 end
function UnitIsRaidOfficer(u) return UnitIndex(u) == 1 end
function UnitExists(u) return Who(u) ~= nil end
function UnitIsPlayer(u) local p = Who(u); return p ~= nil and not p.npc end
function UnitIsUnit(a, b) local x, y = Who(a), Who(b); return x ~= nil and x == y end
function UnitIsConnected(u) return Who(u) ~= nil end
function UnitIsVisible(u) return Who(u) ~= nil end
function UnitIsDeadOrGhost() return false end
function UnitIsDead() return false end
function UnitIsGhost() return false end
function UnitIsAFK() return false end
local function Hostile(a, b)
    local x, y = Who(a), Who(b)
    return x ~= nil and y ~= nil and ((x.enemy or false) ~= (y.enemy or false))
end
function UnitIsEnemy(a, b) return Hostile(a, b) end
function UnitIsFriend(a, b) local x = Who(a); if b == nil then return x ~= nil and not x.enemy end return Who(b) ~= nil and x ~= nil and not Hostile(a, b) end
function UnitCanAttack(a, b) return Hostile(a, b) end
function UnitIsPVP(u) local p = Who(u); return p ~= nil and p.pvp or false end
function UnitOnTaxi() return false end
function UnitInRange(u) return Who(u) ~= nil, true end
function CheckInteractDistance(u) return Who(u) ~= nil end
function UnitName(u)
    local p = Who(u)
    if not p then return nil end
    local n, r = p.name:match("^(.-)%-(.+)$")
    if n then return n, r end
    return p.name, nil
end
function GetUnitName(u, withRealm) local n, r = UnitName(u); if withRealm and r then return n .. "-" .. r end return n end
function UnitFullName(u) local n, r = UnitName(u); return n, r or (n and M.player.realm) end
function UnitGUID(u)
    local i = UnitIndex(u)
    if i then return "Player-1-" .. string.format("%08X", i) end
    local p = Who(u)
    return p and p.guid or nil
end
function UnitClass(u)
    local p = Who(u)
    if not p then return nil end
    return p.class:sub(1, 1) .. p.class:sub(2):lower(), p.class, 1
end
function UnitClassBase(u) local _, c = UnitClass(u); return c end
function UnitRace(u) local p = Who(u); if p then local r = p.race or "Human"; return r, r, 1 end end
function UnitSex() return 2 end
function UnitLevel(u) local p = Who(u); return p and (p.level or 60) or 0 end
function UnitFactionGroup(u) local p = Who(u); if p then local f = p.enemy and "Horde" or "Alliance"; return f, f end end
function UnitHealth(u) local p = Who(u); return p and (p.hp or 1000) or 0 end
function UnitHealthMax(u) local p = Who(u); return p and (p.hpMax or 1000) or 0 end
function UnitPower(u) return Who(u) and 500 or 0 end
function UnitPowerMax(u) return Who(u) and 1000 or 0 end
function UnitPowerType() return 0, "MANA" end
function UnitGroupRolesAssigned() return "DAMAGER" end
function UnitClassification(u) local p = Who(u); return p and p.classification or "normal" end
function UnitCreatureType() return nil end
function UnitReaction(a, b) return Hostile(a, b) and 2 or 5 end
function UnitXP() return 0 end
function UnitXPMax() return 1000 end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
function UnitRealmRelationship() return 1 end
function UnitIsTapDenied() return false end
function GetRaidTargetIndex() return nil end
function GetMaxPlayerLevel() return 60 end
function GetMoney() return 1234567 end
function GetCVar(k) return M.cvars[k] end
function GetCVarBool(k) return M.cvars[k] == "1" end
function SetCVar(k, v) M.cvars[k] = tostring(v); M.Sensitive("SetCVar " .. tostring(k)) ; return true end
function GetCVarDefault() return "0" end
M.cvars = { nameplateMaxDistance = "41", loadDeprecationFallbacks = "0", minimapZoom = "0", minimapInsideZoom = "0", rotateMinimap = "0" }
function GetAddOnMemoryUsage() return 1000 end
function UpdateAddOnMemoryUsage() end
function GetCursorPosition() return 500, 400 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsModifiedClick() return false end
function GetMinimapShape() return "ROUND" end
function PlaySound() end
function PlaySoundFile() end
function GetItemInfo() return nil end
function GetItemInfoInstant() return nil end
function GetItemQualityColor() return 1, 1, 1, "ffffffff" end
function GetInventoryItemLink() return nil end
function GetInventoryItemDurability() return 50, 100 end
function GetNumLootItems() return 0 end
function GetLootSlotLink() return nil end
function GetNumMacros() return 0, 0 end
function GetMacroInfo() return nil end
function GetMacroIndexByName() return 0 end
function GetChannelName() return 0 end
function GetChannelList() return end
function GetClassInfo(i) local c = CLASSES[i]; if c then return c, c, i end end
function GetNumClasses() return #CLASSES end
function GetRepairAllCost() return 0, false end
function GetNumActiveQuests() return 0 end
function GetNumAvailableQuests() return 0 end
function GetNumQuestChoices() return 0 end
function GetInboxHeaderInfo() return nil end
function GetRealZoneText() return "Orgrimmar" end
function GetZoneText() return "Orgrimmar" end
function GetSubZoneText() return "" end
function GetPlayerFacing() return 0 end
function IsSwimming() return false end
function GetXPExhaustion() return nil end
function RequestTimePlayed() end
-- a battleground (tools/smoke/battleground.lua): M.instance = "pvp", M.scores = the scoreboard, a list of PVPScoreInfo
-- tables (C_PvP.GetScoreInfo, PvpInfoDocumentation.lua: name, faction 0 Horde / 1 Alliance, classToken... never
-- secret), M.bgFaction = my side; the server answers RequestBattlefieldScoreData with UPDATE_BATTLEFIELD_SCORE
local function InBG() return M.instance == "pvp" and M.scores ~= nil end
function GetBattlefieldStatus(i) if InBG() and i == 1 then return "active", M.instanceName or "Alterac Valley" end return "none" end
function GetMaxBattlefieldID() return 2 end
function GetNumBattlefieldScores() return InBG() and #M.scores or 0 end
function GetBattlefieldTeamInfo() return nil end
function GetBattlefieldArenaFaction() return InBG() and (M.bgFaction or 0) or 0 end
function GetBattlefieldWinner() return nil end
function GetBattlefieldInstanceRunTime() return InBG() and math.floor((M.now - (M.bgStart or M.now)) * 1000) or 0 end
C_PvP = C_PvP or {}
C_PvP.GetScoreInfo = function(i) return InBG() and M.scores[i] or nil end
function RequestBattlefieldScoreData()
    if InBG() and not M.scoreAsked then
        M.scoreAsked = true
        C_Timer.After(0.15, function() M.scoreAsked = nil; if InBG() then M.Fire("UPDATE_BATTLEFIELD_SCORE") end end)
    end
end
function SetBattlefieldScoreFaction() end
function GetNumSavedInstances() return 0 end
function RequestRaidInfo() end
function CanInspect() return false end
function NotifyInspect() end
function ClearInspectPlayer() end
function Ambiguate(name) return (tostring(name):gsub("%-.*$", "")) end
function GetPlayerInfoByGUID() return nil end
function GetAverageItemLevel() return 60, 60 end

-- The open world, for tools/smoke/openworld.lua (M.SetupWorld before the addons load: HereBeDragons reads the maps
-- then). Two continents, a few zones (a box on their continent); positions: M.world.player / a unit's map, x, y
-- (0-1 on that map). World coordinates in yards as the game gives them: UnitPosition = y, x (x = left - width * mapX).
local worldStub = UnitPosition
function UnitPosition(u)
    if not M.world then return worldStub(u) end
    local p = Who(u)
    p = p == M.player and M.world.player or p
    local r = p and p.map and M.world.maps[p.map]
    if not r or not r.w then return nil end
    return r.top - r.h * p.y, r.left - r.w * p.x, 0, r.instance
end
function M.SetupWorld()
    local T = Enum.UIMapType
    local maps = {
        [946] = { "Cosmic", T.Cosmic },
        [947] = { "Azeroth", T.World, 946 },
        [1414] = { "Kalimdor", T.Continent, 947, 1, left = 12000, top = 11000, w = 36000, h = 24000 },
        [1415] = { "Eastern Kingdoms", T.Continent, 947, 0, left = 16000, top = 5000, w = 34000, h = 22000 },
        [1411] = { "Durotar", T.Zone, 1414, box = { 0.56, 0.50, 0.66, 0.66 } },
        [1454] = { "Orgrimmar", T.Zone, 1414, box = { 0.56, 0.44, 0.60, 0.50 } },
        [1413] = { "The Barrens", T.Zone, 1414, box = { 0.46, 0.50, 0.58, 0.80 } },
        [1440] = { "Ashenvale", T.Zone, 1414, box = { 0.38, 0.28, 0.56, 0.44 } },
        [1429] = { "Elwynn Forest", T.Zone, 1415, box = { 0.40, 0.76, 0.52, 0.84 } },
        [1453] = { "Stormwind City", T.Zone, 1415, box = { 0.38, 0.70, 0.44, 0.76 } },
    }
    for id, m in pairs(maps) do
        m.id, m.name, m.mapType, m.parent, m.instance = id, m[1], m[2], m[3], m[4]
        local c = m.box and maps[m.parent]
        if c then
            m.instance = c.instance
            m.left, m.top = c.left - c.w * m.box[1], c.top - c.h * m.box[2]
            m.w, m.h = c.w * (m.box[3] - m.box[1]), c.h * (m.box[4] - m.box[2])
        end
    end
    M.world = { maps = maps, player = { map = 1411, x = 0.52, y = 0.44 } }
    local function Info(m) return { mapID = m.id, name = m.name, mapType = m.mapType, parentMapID = m.parent or 0, flags = 0 } end
    C_Map.GetMapInfo = function(id) local m = maps[id]; return m and Info(m) or nil end
    C_Map.GetMapChildrenInfo = function(id, mapType, all)
        local out = {}
        for _, m in pairs(maps) do
            local p, under = m.parent, false
            while p do if p == id then under = true; break end p = all and maps[p] and maps[p].parent or nil end
            if under and (not mapType or m.mapType == mapType) then out[#out + 1] = Info(m) end
        end
        table.sort(out, function(a, b) return a.mapID < b.mapID end)
        return out
    end
    C_Map.GetMapGroupID = function() return nil end
    C_Map.GetMapGroupMembersInfo = function() return nil end
    C_Map.GetMapArtID = function(id) return id end
    C_Map.GetMapWorldSize = function(id) local m = maps[id]; if m and m.w then return m.w, m.h end return 0, 0 end
    C_Map.GetWorldPosFromMapPos = function(id, pos)
        local m = maps[id]
        if not (m and m.w and pos) then return nil, nil end
        local x, y = pos:GetXY()
        return m.instance, CreateVector2D(m.top - m.h * y, m.left - m.w * x)
    end
    C_Map.GetMapPosFromWorldPos = function(instance, pos, override)
        local wy, wx = pos:GetXY()
        local m = maps[override or 0]
        if not (m and m.w and m.instance == instance) then return nil, nil end
        return m.id, CreateVector2D((m.left - wx) / m.w, (m.top - wy) / m.h)
    end
    C_Map.GetMapRectOnMap = function(id, parent)
        local m = maps[id]
        if not (m and m.box and m.parent == parent) then return 0, 0, 0, 0 end
        return m.box[1], m.box[3], m.box[2], m.box[4]
    end
    C_Map.GetBestMapForUnit = function(u) if UnitIsUnit(u, "player") then return M.world.player.map end return nil end
    -- the player's position on a map: through the world, as the game does (nil off that map)
    C_Map.GetPlayerMapPosition = function(id, u)
        local wy, wx, _, instance = UnitPosition(u)
        local m = maps[id]
        if not (wy and m and m.w and m.instance == instance) then return nil end
        local x, y = (m.left - wx) / m.w, (m.top - wy) / m.h
        if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
        return CreateVector2D(x, y)
    end
    C_Minimap = C_Minimap or {}
    C_Minimap.GetViewRadius = function() return 233 end -- yards, outdoor zoom 0
    Minimap.__w, Minimap.__h = 140, 140
end

-- what the addon sends: kept, and counted as "sensitive" when it acts for the player
function M.Sensitive(what) M.sensitive[#M.sensitive + 1] = what .. " (" .. (M.phase or "?") .. ")" end
C_ChatInfo = C_ChatInfo or {}
local prefixes = {}
M.prefixes = prefixes
C_ChatInfo.RegisterAddonMessagePrefix = function(p) prefixes[p] = true; return true end
C_ChatInfo.IsAddonMessagePrefixRegistered = function(p) return prefixes[p] or false end
C_ChatInfo.SendAddonMessage = function(prefix, msg, channel, target)
    M.addon[#M.addon + 1] = { prefix = prefix, msg = msg, channel = channel, target = target, phase = M.phase }
    return 0
end
C_ChatInfo.SendAddonMessageLogged = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendChatMessage = function(msg, channel, lang, target)
    M.chat[#M.chat + 1] = { msg = msg, channel = channel, target = target, phase = M.phase }
    return 0
end
C_ChatInfo.InChatMessagingLockdown = function() return false end
C_ChatInfo.GetNumActiveChannels = function() return 0 end
function JoinTemporaryChannel() M.Sensitive("JoinTemporaryChannel"); return 0 end
function LeaveChannelByName() end
function InviteUnit(n) M.Sensitive("InviteUnit " .. tostring(n)) end
C_PartyInfo = C_PartyInfo or {}
C_PartyInfo.InviteUnit = function(n) M.Sensitive("InviteUnit " .. tostring(n)) end
C_PartyInfo.ConvertToRaid = function() M.Sensitive("ConvertToRaid") end
C_PartyInfo.DoReadyCheck = function() M.Sensitive("DoReadyCheck") end
C_PartyInfo.LeaveParty = function() M.Sensitive("LeaveParty") end
function SetRaidSubgroup() M.Sensitive("SetRaidSubgroup") end
function SwapRaidSubgroup() M.Sensitive("SwapRaidSubgroup") end
function SetRaidTarget() M.Sensitive("SetRaidTarget") end
function CreateMacro() M.Sensitive("CreateMacro"); return 1 end
function EditMacro() M.Sensitive("EditMacro"); return 1 end
function SetOverrideBindingClick() if M.combat then M.blocked[#M.blocked + 1] = "SetOverrideBindingClick (" .. M.phase .. ")" end end
function ClearOverrideBindings() if M.combat then M.blocked[#M.blocked + 1] = "ClearOverrideBindings (" .. M.phase .. ")" end end
function RepairAllItems() M.Sensitive("RepairAllItems") end
function LoggingCombat(on) if on ~= nil then M.Sensitive("LoggingCombat") end return false end

-- addons: the four of the repo, loaded by smoke.js (LoadAddOn calls back into it)
C_AddOns = C_AddOns or {}
M.loaded = {}
C_AddOns.IsAddOnLoaded = function(n) return M.loaded[n] or false, M.loaded[n] or false end
C_AddOns.LoadAddOn = function(n)
    if M.loaded[n] then return true end
    if not M.LoadAddOn then return false, "MISSING" end
    local ok = M.LoadAddOn(n)
    return ok, ok and nil or "MISSING"
end
C_AddOns.GetAddOnMetadata = function(n, key) if key == "Version" then return M.version end return nil end
C_AddOns.GetAddOnEnableState = function() return 2 end
C_AddOns.IsAddOnLoadOnDemand = function(n) return n ~= "WarLegendRaidTool" end
C_AddOns.GetNumAddOns = function() return 4 end
C_AddOns.GetAddOnInfo = function(i) return "WarLegendRaidTool", "WarLegendRaidTool", "", true, "INSECURE", false end
C_AddOns.DoesAddOnExist = function(n) return (tostring(n):find("^WarLegendRaidTool")) ~= nil end

-- timers on the virtual clock
C_Timer = {}
local timers = {}
local function Add(t) timers[#timers + 1] = t; return t end
local Timer = {}
Timer.__index = Timer
function Timer:Cancel() self.cancelled = true end
function Timer:IsCancelled() return self.cancelled or false end
C_Timer.After = function(d, fn) Add({ at = M.now + math.max(tonumber(d) or 0, 0.001), fn = fn, where = M.phase }) end
C_Timer.NewTimer = function(d, fn) return Add(setmetatable({ at = M.now + math.max(tonumber(d) or 0, 0.001), fn = fn }, Timer)) end
C_Timer.NewTicker = function(d, fn, n)
    d = math.max(tonumber(d) or 0, 0.01)
    local t = setmetatable({ at = M.now + d, every = d, left = n, fn = fn }, Timer)
    return Add(t)
end

-- runs the clock: timers in order, then OnUpdate of every visible frame, step by step (default 1/20 s)
-- M.frameStats = { list = {} } before: the cost of each step (one frame of the game) goes into list, the worst one into
-- max / maxAt (phase) / maxWhat (its costliest handlers when M.costs is on too). Only the time spent in the addons'
-- code counts (timers, the scenario's events, OnUpdate scripts), not this loop over every frame
function M.Advance(seconds, step)
    step = step or 0.05
    local stop = M.now + seconds
    while M.now < stop - 1e-9 do
        local fs = M.frameStats
        -- the events the scenario fired since the last step belong to this frame (M.Fire)
        local spent = fs and M.frameCarry or 0
        M.frameCarry = 0
        local before = fs and M.costs and (fs.mark or {})
        if before and not fs.mark then for k, v in pairs(M.costs) do before[k] = v end end
        M.inStep = true
        M.now = M.now + step
        local due = {}
        local keep = {}
        for _, t in ipairs(timers) do
            if t.cancelled then -- dropped
            elseif t.at <= M.now then due[#due + 1] = t
            else keep[#keep + 1] = t end
        end
        timers = keep
        table.sort(due, function(a, b) return a.at < b.at end)
        for _, t in ipairs(due) do
            if not t.cancelled then
                local t0 = (fs or M.costs) and os.clock()
                M.Call(t.fn, t)
                if t0 then
                    local ms = os.clock() - t0
                    if fs then spent = spent + ms end
                    local info = M.costs and type(t.fn) == "function" and debug.getinfo(t.fn, "S")
                    -- by the file:line where the callback is written; not this file's (the server answering: its
                    -- event is counted by handler)
                    if info and not info.source:find("wow%.lua$") then
                        local k = "timer " .. (info.source:match("([^/]+%.lua)$") or "?") .. ":" .. info.linedefined
                        M.costs[k] = (M.costs[k] or 0) + ms * 1000
                    end
                end
                if t.every and not t.cancelled then
                    if t.left then t.left = t.left - 1 end
                    if not t.left or t.left > 0 then t.at = M.now + t.every; timers[#timers + 1] = t end
                end
            end
        end
        if M.onStep then -- the scenario's world: other players moving, sending
            local t0 = fs and os.clock()
            M.Call(M.onStep, M.now)
            if t0 then spent = spent + os.clock() - t0 end
        end
        for _, f in ipairs(frames) do
            local fn = f.__scripts.OnUpdate
            if fn and f:IsVisible() then
                M.updates = (M.updates or 0) + 1
                if M.costs or fs then
                    local t0 = os.clock()
                    M.Call(fn, f, step)
                    local ms = os.clock() - t0
                    spent = spent + ms
                    if M.costs then
                        local k = "OnUpdate " .. (f.__where or f:GetName() or "?")
                        M.costs[k] = (M.costs[k] or 0) + ms * 1000
                    end
                else
                    M.Call(fn, f, step)
                end
            end
        end
        M.inStep = false
        if fs then
            local ms = spent * 1000
            fs.list[#fs.list + 1] = ms
            if ms > (fs.max or 0) then
                fs.max, fs.maxAt, fs.maxWhat = ms, M.phase, nil
                if before then -- what that frame did, costliest first (M.costs on)
                    local what = {}
                    for k, v in pairs(M.costs) do if v - (before[k] or 0) > 0.05 then what[#what + 1] = { k, v - (before[k] or 0) } end end
                    table.sort(what, function(a, b) return a[2] > b[2] end)
                    for i = 1, #what do what[i] = string.format("%s %.1f", what[i][1], what[i][2]) end
                    fs.maxWhat = table.concat(what, ", ", 1, math.min(#what, 3))
                end
            end
            if M.costs then fs.mark = {}; for k, v in pairs(M.costs) do fs.mark[k] = v end end
        end
    end
end
function M.PendingTimers() local n = 0; for _, t in ipairs(timers) do if not t.cancelled then n = n + 1 end end return n end

-- an event to every frame that registered it (creation order). Fired by the scenario between two steps (M.frameStats
-- on), its cost goes to the next frame (M.frameCarry), as the game runs it in a frame
local fireDepth = 0
function M.Fire(event, ...)
    local t0 = M.frameStats and not M.inStep and fireDepth == 0 and os.clock()
    fireDepth = fireDepth + 1
    for _, list in ipairs({ byEvent[event] or {}, byEvent["*"] or {} }) do
        local copy = { table.unpack(list) }
        for _, f in ipairs(copy) do
            if f.__events and (f.__events[event] or f.__allEvents) then
                local fn = f.__scripts.OnEvent
                if fn then
                    if M.costs then
                        local t0 = os.clock()
                        M.Call(fn, f, event, ...)
                        local k = event .. " " .. (f.__where or f:GetName() or "?")
                        M.costs[k] = (M.costs[k] or 0) + (os.clock() - t0) * 1000
                    else
                        M.Call(fn, f, event, ...)
                    end
                end
            end
        end
    end
    fireDepth = fireDepth - 1
    if t0 then M.frameCarry = (M.frameCarry or 0) + os.clock() - t0 end
end

-- frames the game has
UIParent = New("Frame", "UIParent")
WorldFrame = New("Frame", "WorldFrame")
UIParent.__w, UIParent.__h = 1920, 1080
for _, n in ipairs({ "Minimap", "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "DEFAULT_CHAT_FRAME", "ChatFrame1",
    "WorldMapFrame", "LootFrame", "InspectFrame", "InspectPaperDollFrame", "CharacterFrame", "PaperDollFrame", "MovieFrame",
    "ColorPickerFrame", "TimerTracker", "PVPMatchScoreboard", "CommunitiesFrame", "ContainerFrameCombinedBags", "ContainerFrameContainer",
    "GameMenuFrame", "ReadyCheckFrame", "SettingsPanel", "QuestLogFrame", "QuestFrame", "GossipFrame", "MerchantFrame", "MailFrame",
    "BankFrame", "FriendsFrame", "SpellBookFrame", "PlayerTalentFrame", "TradeFrame", "ChatConfigFrame", "StaticPopup1", "StaticPopup2",
    "MinimapCluster", "ObjectiveTrackerFrame", "PlayerFrame", "TargetFrame", "CompactRaidFrameContainer", "ChatFrame1EditBox" }) do
    local f = New("Frame", n, UIParent)
    if n:find("Frame$") or n:find("^StaticPopup") or n:find("Tooltip") then f.__shown = false end
    frames[#frames + 1] = f
end
ChatFrame1.__shown = true
DEFAULT_CHAT_FRAME = ChatFrame1
SELECTED_CHAT_FRAME = ChatFrame1
-- the world map is a MapCanvas (Blizzard_MapCanvas.lua, Blizzard_WorldMap.lua): no map until its first opening, then
-- the player's map on each opening; data providers refreshed on show and on a map change; pins from pools: a pin
-- acquired while the map is closed stays active until the next refresh, as in the game
WorldMapFrame.ScrollContainer = New("Frame", nil, WorldMapFrame)
WorldMapFrame.pinPools = {}
WorldMapFrame.dataProviders = {}
WorldMapFrame.BorderFrame = New("Frame", nil, WorldMapFrame)
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:RefreshAllDataProviders(fromOnShow)
    for dp in pairs(self.dataProviders) do if dp.RefreshAllData then M.Call(dp.RefreshAllData, dp, fromOnShow) end end
end
function WorldMapFrame:SetMapID(id)
    if id == self.mapID then return end
    self.mapID = id
    self:RefreshAllDataProviders(false)
end
function WorldMapFrame:AddDataProvider(dp) self.dataProviders[dp] = true; if dp.OnAdded then dp:OnAdded(self) end end
function WorldMapFrame:RemoveDataProvider(dp)
    if dp.RemoveAllData then dp:RemoveAllData() end
    self.dataProviders[dp] = nil
    if dp.OnRemoved then dp:OnRemoved(self) end
end
function WorldMapFrame:AcquirePin(template, ...)
    local pool = self.pinPools[template]
    if not pool then pool = CreateFramePool("Frame", self:GetCanvas(), template); self.pinPools[template] = pool end
    local pin, new = pool:Acquire()
    pin.pinTemplate = template
    pin.owningMap = self
    if new and pin.OnLoad then pin:OnLoad() end
    pin:Show()
    if pin.OnAcquired then pin:OnAcquired(...) end
    return pin
end
function WorldMapFrame:RemovePin(pin) local pool = self.pinPools[pin.pinTemplate]; if pool then pool:Release(pin) end end
function WorldMapFrame:RemoveAllPinsByTemplate(t) if self.pinPools[t] then self.pinPools[t]:ReleaseAll() end end
function WorldMapFrame:EnumeratePinsByTemplate(t) if self.pinPools[t] then return self.pinPools[t]:EnumerateActive() end return function() end end
function WorldMapFrame:GetNumActivePinsByTemplate(t) return self.pinPools[t] and self.pinPools[t]:GetNumActive() or 0 end
function WorldMapFrame:GetCanvas() return WorldMapFrame.ScrollContainer end
function WorldMapFrame:RegisterCallback() end
WorldMapFrame.__scripts.OnShow = function(self)
    self:SetMapID(C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or self.mapID)
    self:RefreshAllDataProviders(true)
end
function WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition() return 0.5, 0.5 end
function WorldMapFrame.ScrollContainer:GetCanvasScale() return 1 end
function GameTooltip_SetDefaultAnchor(t) t:SetOwner(UIParent) end
for _, n in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge", "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontHighlightLarge", "GameFontDisable", "GameFontDisableSmall", "GameFontGreen", "GameFontRed", "ChatFontNormal", "NumberFontNormal",
    "SystemFont_Shadow_Med1", "GameFontNormalHuge", "GameFontWhite", "GameTooltipText", "GameFontHighlightMedium", "GameFontNormalMed3" }) do
    _G[n] = New("Font", n)
end

-- FrameXML helpers the addon uses (the shapes it reads)
RAID_CLASS_COLORS = {}
LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE, CLASS_ICON_TCOORDS = {}, {}, {}
CLASS_SORT_ORDER = {}
for i, c in ipairs(CLASSES) do
    RAID_CLASS_COLORS[c] = { r = 1, g = 1, b = 1, colorStr = "ffffffff", GetRGB = function() return 1, 1, 1 end,
        GenerateHexColor = function() return "ffffffff" end, WrapTextInColorCode = function(_, t) return "|cffffffff" .. t .. "|r" end }
    LOCALIZED_CLASS_NAMES_MALE[c] = c:sub(1, 1) .. c:sub(2):lower()
    LOCALIZED_CLASS_NAMES_FEMALE[c] = LOCALIZED_CLASS_NAMES_MALE[c]
    CLASS_ICON_TCOORDS[c] = { 0, 0.25, 0, 0.25 }
    CLASS_SORT_ORDER[i] = c
end
ITEM_QUALITY_COLORS = {}
for i = 0, 8 do ITEM_QUALITY_COLORS[i] = { r = 1, g = 1, b = 1, hex = "|cffffffff", color = { GetRGB = function() return 1, 1, 1 end } } end
PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 }, ENERGY = { r = 1, g = 1, b = 0 } }
for i = 0, 3 do PowerBarColor[i] = PowerBarColor.MANA end
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
StaticPopupDialogs = {}
STATICPOPUP_NUMDIALOGS = 4
function StaticPopup_Show(which) local d = StaticPopupDialogs[which]; M.popups = (M.popups or 0) + 1; if not d then return nil end return StaticPopup1 end
function StaticPopup_Hide() end
function StaticPopup_FindVisible() return nil end
UISpecialFrames = {}
SlashCmdList = {}
hash_SlashCmdList = {}
NUM_CHAT_WINDOWS = 10
NUM_BAG_SLOTS = 4
NUM_BANKBAGSLOTS = 7
BANK_CONTAINER = -1
MAX_ACCOUNT_MACROS = 120
MAX_CHARACTER_MACROS = 18
MAX_PARTY_MEMBERS = 4
MAX_RAID_MEMBERS = 40
ATTACHMENTS_MAX_RECEIVE = 16
LE_REALM_RELATION_VIRTUAL = 3
WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC, WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_WRATH_CLASSIC, WOW_PROJECT_CAMELOT = 1, 2, 5, 11, 20
WOW_PROJECT_ID = WOW_PROJECT_CAMELOT
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function Mixin(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function CopyTable(t, shallow)
    local c = {}
    for k, v in pairs(t) do c[k] = (type(v) == "table" and not shallow) and CopyTable(v) or v end
    return c
end
function tAppendAll(a, b) for _, v in ipairs(b) do a[#a + 1] = v end return a end
function tInvert(t) local o = {}; for k, v in pairs(t) do o[v] = k end return o end
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a, GetRGB = function(s) return s.r, s.g, s.b end, GetRGBA = function(s) return s.r, s.g, s.b, s.a end,
        GenerateHexColor = function() return "ffffffff" end, WrapTextInColorCode = function(_, t) return "|cffffffff" .. tostring(t) .. "|r" end }
end
function CreateVector2D(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = CreateVector2D(x, y) } end }
BackdropTemplateMixin = { SetBackdrop = Widget.SetBackdrop }
MapCanvasDataProviderMixin = { GetMap = function() return WorldMapFrame end, OnAdded = function(self, map) self.owningMap = map end,
    OnRemoved = function() end, RemoveAllData = function() end, RefreshAllData = function() end }
MapCanvasPinMixin = { OnLoad = function() end, SetPosition = function() end, UseFrameLevelType = function() end,
    SetScalingLimits = function() end, OnAcquired = function() end, OnReleased = function() end,
    SetOwningMap = function(self, map) self.owningMap = map end, GetMap = function(self) return self.owningMap end }
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = 1 }, Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }
-- the rest of FrameXML the addon touches: tables whose functions do nothing and return nothing
local function Inert(name)
    return setmetatable({}, { __index = function(t, k)
        if type(k) == "string" and k:match("^[A-Z]") then local f = function() return nil end; rawset(t, k, f); return f end
    end })
end
for _, n in ipairs({ "Settings", "MenuUtil", "EventRegistry", "TooltipDataProcessor", "AnchorUtil", "InputUtil", "CurveConstants",
    "AuraContainerSortDirection", "AuraContainerSortMethod", "ScrollUtil", "SecureHandlerWrapScript_", "Item", "SoftCursor" }) do
    _G[n] = Inert(n)
end
-- the options window (Settings): objects whose methods do nothing, chainable
local function Chain()
    return setmetatable({}, { __index = function(t, k) local f = function() return Chain() end; rawset(t, k, f); return f end })
end
Settings.VarType = { Boolean = "boolean", Number = "number", String = "string" }
Settings.Default = { True = true, False = false }
for _, n in ipairs({ "RegisterAddOnSetting", "RegisterProxySetting", "CreateCheckbox", "CreateSlider", "CreateDropdown", "CreateSliderOptions",
    "CreateControlTextContainer", "CreateElementInitializer", "RegisterInitializer", "GetCategory", "OpenToCategory", "CreateSettingInitializer" }) do
    Settings[n] = function() return Chain() end
end
function Settings.RegisterCanvasLayoutCategory(frame, name) return { GetID = function() return name end, ID = name } end
function Settings.RegisterVerticalLayoutCategory(name) return { GetID = function() return name end, ID = name }, Inert("layout") end
function Item:CreateFromItemLink()
    return { ContinueOnItemLoad = function(_, fn) fn() end, IsItemEmpty = function() return true end, IsItemDataCached = function() return true end,
        GetItemID = function() return 0 end, GetItemName = function() return nil end, GetItemLink = function() return nil end, GetItemIcon = function() return nil end }
end
function Item:CreateFromItemID() return Item:CreateFromItemLink() end
for _, n in ipairs({ "SetItemRef", "ChatFrame_RemoveChannel", "ChatFrame_AddMessageEventFilter",
    "ChatFrame_RemoveMessageEventFilter", "PaperDollItemSlotButton_Update", "InspectPaperDollItemSlotButton_Update", "BankFrameItemButton_Update",
    "UpdateUIPanelPositions", "SecureHandlerWrapScript", "SetRaidTargetIconTexture", "StopCinematic", "ShowUIPanel", "HideUIPanel",
    "ToggleFrame", "CloseDropDownMenus", "PlaceRaidMarker", "ClearCursor", "FocusUnit", "GetTexCoordsForRoleSmallCircle",
    "ConsoleGetAllCommands", "CursorHasItem", "GetClassAtlas", "GetSpecializationInfoForClassID",
    "GetAreaSpiritHealerTime", "GetPVPSessionStats", "DoReadyCheck",
    "GetReadyCheckStatus", "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "IsSpellInRange", "GetItemCount", "GetItemCooldown",
    "GetItemIcon", "GetItemStats", "GetDetailedItemLevelInfo", "GetContainerNumSlots", "GetContainerItemLink", "GetContainerItemInfo",
    "PickupContainerItem", "UseContainerItem", "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
    "IsQuestFlaggedCompleted", "GetFactionInfoByID", "GetCoinTextureString", "BreakUpLargeNumbers", "AbbreviateLargeNumbers",
    "AbbreviateNumbers", "GetNumTalentTabs", "GetNumTalents", "GetSpecialization",
    "GetSpecializationInfo", "GetSpecializationInfoByID", "GetSpecializationRole", "GetNumSpecGroups", "GetNumSpecializationsForClassID",
    "GetLootMethod", "GetLootSourceInfo", "GetMasterLootCandidate", "GiveMasterLoot", "LootSlot", "IsFishingLoot", "GetInviteConfirmationInfo",
    "GetNextPendingInviteConfirmation", "RespondToInviteConfirmation", "IsGuildMember", "GuildRoster", "GetGuildRosterShowOffline",
    "SelectActiveQuest", "SelectAvailableQuest", "GetActiveTitle", "GetAvailableQuestInfo", "AcceptQuest", "CompleteQuest", "GetQuestReward",
    "AcknowledgeAutoAcceptQuest", "IsQuestCompletable", "QuestGetAutoAccept", "CanMerchantRepair", "CanGuildBankRepair", "GetInboxNumItems",
    "GetInboxItem", "ClickTradeButton", "GetChatWindowChannels", "GetNumDisplayChannels", "GetChannelDisplayInfo", "BNGetNumFriends",
    "SetPartyAssignment", "ConvertToRaid", "IsRaidLeader", "IsRaidOfficer", "GetNumPartyMembers", "GetNumRaidMembers", "GetPOITextureCoords",
    "IsItemInRange", "GameMovieFinished", "UnitResistance", "UnitHealthMissing", "UnitHealthPercent",
    "UnitCastingDuration", "UnitChannelDuration", "ContainerFrame_Update", "LootFrame_UpdateButton",
    "InspectPaperDollFrame_UpdateButtons", "GetBattlefieldEstimatedWaitTime", "GetBattlefieldPortExpiration", "GetBattlefieldTimeWaited",
    "GetNumClasses_", "GetAddOnInfo", "RegisterAddonMessagePrefix", "SendAddonMessage" }) do
    if _G[n] == nil then _G[n] = Stub(n, "") end
end
function GetCoinTextureString(c) return tostring(c) end
function BreakUpLargeNumbers(n) return tostring(n) end
function AbbreviateLargeNumbers(n) return tostring(n) end
function AbbreviateNumbers(n) return tostring(n) end
function GetProfessions() return nil end
function GetNumTalentTabs() return 0 end
function GetLootMethod() return "group" end
function GetReadyCheckStatus() return nil end
function GetItemCount() return 0 end
function GetGuildRosterShowOffline() return true end
function GetNumSkillLines() return 0 end
function GetChatWindowChannels() return end
function GetNumDisplayChannels() return 0 end
function BNGetNumFriends() return 0, 0 end
function GetNumPartyMembers() return 0 end
function GetNumRaidMembers() return 0 end
-- the deprecation shims (Blizzard_Deprecated*): off here, as the CVar allows; the chat one too (CVar loadDeprecationFallbacks = 0), so SendChatMessage does not exist, as the game can do
SendChatMessage = nil

-- GlobalStrings (not in the UI source): unknown ALL_CAPS globals read as their own name, the rest is nil
local NOT_STRINGS = { CUSTOM_CLASS_COLORS = true, HBD_PINS_WORLDMAP_SHOW_CONTINENT = true }
M.unknownReads = {}
setmetatable(_G, { __index = function(_, k)
    if type(k) ~= "string" then return nil end
    if k:match("^[A-Z][A-Z0-9_]+$") and not NOT_STRINGS[k] and not k:find("^WLRT") and not k:find("^SLASH_") and not k:find("^BINDING_") then
        return k
    end
    if k:match("^[A-Z]") or k:match("^C_") then M.unknownReads[k] = (M.unknownReads[k] or 0) + 1 end
    return nil
end })

return M
