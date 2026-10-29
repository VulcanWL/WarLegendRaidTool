-- WarLegend RaidTool - DoesItDie: other addons' target and focus frames
-- The marker and kill icon go on a known replacement target / focus frame (EllesmereUI's) when that addon draws its
-- own, which hides Blizzard's; else on Blizzard's. Found by name, no setting. The marker only needs the health bar's
-- rectangle (it is laid over it, filling left to right on the same max-health scale).
local ns = WLRT.Space("DoesItDie")

-- Blizzard's own frames answer some queries with secret values: anything read from a frame we don't own is
-- checked before use.
local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- A plain value from region:method(), or nil if it errors or is secret.
local function plain(region, method)
    local fn = region[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, region)
    if not ok or isSecret(value) then return nil end
    return value
end

-- "GlobalName.key.key" -> the frame (or texture), or nil if it doesn't exist (yet: some addons build frames late).
local function resolve(path)
    local ok, object = pcall(function()
        local object
        for part in path:gmatch("[^%.]+") do
            if object == nil then
                object = _G[part]
            elseif type(object) == "table" then
                object = object[part]
            else
                return nil
            end
        end
        return object
    end)
    if ok and type(object) == "table" and type(object.GetObjectType) == "function"
        and type(object.GetWidth) == "function" then
        return object
    end
end

-- The top-level frame `region` belongs to (its ancestor just below UIParent), for layering.
function ns.frameRoot(region)
    local current = region
    for _ = 1, 20 do
        local parent = plain(current, "GetParent")
        if not parent or parent == UIParent then return current end
        current = parent
    end
    return current
end

-- Replacement frames: the frame's global name, its health bar and portrait keys, and whose it is. Each only exists
-- while its addon draws its own frame (EllesmereUI creates its frame only when its target frame is enabled).
local KNOWN_TARGET_FRAMES = {
    { frame = "EllesmereUIUnitFrames_Target", bar = "Health", portrait = "Portrait", owner = "EllesmereUI" },
}
-- EllesmereUI's focus path was checked in game by a DoesItDie user (its issue #12).
local KNOWN_FOCUS_FRAMES = {
    { frame = "EllesmereUIUnitFrames_Focus", bar = "Health", owner = "EllesmereUI" },
}

-- A known replacement focus frame that is there: its health bar and whose it is, else nil.
function ns.knownFocusFrame()
    for _, known in ipairs(KNOWN_FOCUS_FRAMES) do
        local bar = resolve(known.frame .. "." .. known.bar)
        if bar then return bar, known.owner end
    end
end

-- Whether `region` and its ancestors below `root` are shown. The root itself is left out: a target frame hides
-- while there's no target.
local function shownBelow(region, root)
    local current = region
    for _ = 1, 20 do
        if current == nil or current == root then return true end
        if plain(current, "IsShown") == false then return false end
        current = plain(current, "GetParent")
    end
    return true
end

-- A known replacement target frame that is there: its health bar, its portrait if it is shown (EllesmereUI hides
-- its portrait when portraits are off), and whose it is. Nil if none is there.
function ns.knownTargetFrame()
    for _, known in ipairs(KNOWN_TARGET_FRAMES) do
        local root = resolve(known.frame)
        local bar = root and resolve(known.frame .. "." .. known.bar)
        if bar then
            local portrait = resolve(known.frame .. "." .. known.portrait)
            if portrait and not shownBelow(portrait, root) then portrait = nil end
            return bar, portrait, known.owner
        end
    end
end
