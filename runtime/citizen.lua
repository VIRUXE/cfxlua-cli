-- =============================================================================
-- citizen.lua  —  CfxLua Standalone Runtime
-- =============================================================================
Citizen = Citizen or {}

-- ---------------------------------------------------------------------------
-- Magic Mock system
-- ---------------------------------------------------------------------------
local function createMagicMock(name)
    local mock = {}
    local mt = {
        __index = function(self, key) return self end,
        __call = function(self, ...) return self end,
        __tostring = function() return "" end,
        __concat = function(a, b) return tostring(a) .. tostring(b) end,
        __len = function() return 0 end,
    }
    return setmetatable(mock, mt)
end

setmetatable(_G, {
    __index = function(_, key) return createMagicMock(key) end
})

local _originalRequire = require
function require(moduleName)
    local ok, result = pcall(_originalRequire, moduleName)
    if ok then return result end
    return createMagicMock(moduleName)
end

-- ---------------------------------------------------------------------------
-- Resource identity & Path discovery
-- ---------------------------------------------------------------------------
local function _basename(path) return (path or ""):match("[^/\\\\]+$") or "standalone" end
local _scriptPath = arg and arg[1]
local _resourceName = os.getenv("CFXLUA_RESOURCE_NAME") or _basename(_scriptPath or "standalone")

function GetCurrentResourceName() return _resourceName end
function GetInvokingResource() return nil end
function GetResourceState(name) return "started" end

local _projectRoot = "."
if _scriptPath then
    local current = _scriptPath
    for i = 1, 15 do
        local parent = current:match("(.*)[/\\/]")
        if not parent then break end
        local f = io.open(parent .. "/server.cfg", "r")
        if f then
            f:close()
            _projectRoot = parent
            break
        end
        current = parent
    end
end

-- ---------------------------------------------------------------------------
-- Native Invoke shims
-- ---------------------------------------------------------------------------
function Citizen.InvokeNative(hash, ...) return nil end
Citizen.InvokeNativeByHash = Citizen.InvokeNative
function Citizen.Trace(msg) io.write(tostring(msg):gsub("%%^(%%d)", "")) io.flush() end
Citizen.Log = print
function Citizen.GetTickCount() return GetGameTimer() end
function Citizen.SubmitBoundaryStart(a, b) end
function Citizen.SubmitBoundaryEnd(a, b) end
function Citizen.RegisterResourceAsEventHandler(name) end
function Citizen.TriggerEventInternal(name, data, len) end

-- ---------------------------------------------------------------------------
-- Config Discovery System
-- ---------------------------------------------------------------------------
local _convarRegistry = {
    ["onesync_enableInfinity"] = "1",
    ["gamename"] = "fivem",
    ["inventory:framework"] = "qbx"
}

local function _parseCfg(filePath)
    local f = io.open(filePath, "r")
    if not f then return end
    local dir = filePath:match("(.*[\\/])") or ""
    for line in f:lines() do
        local key, value = line:match("^%%s*set[rs]?%%s+([^%%s]+)%%s+(.-)%%s*$")
        if key and value then
            value = value:gsub("%%s*#.*$", ""):match("^%%s*(.-)%%s*$") or value
            if (value:sub(1,1) == '"' and value:sub(-1) == '"') or (value:sub(1,1) == "'" and value:sub(-1) == "'") then
                value = value:sub(2, -2)
            end
            _convarRegistry[key] = value
        end
        local execFile = line:match("^%%s*exec%%s+[\"']?(.-)['\"]?%%s*$")
        if execFile then _parseCfg(dir .. execFile) end
    end
    f:close()
end

if _projectRoot ~= "." then
    _parseCfg(_projectRoot .. "/server.cfg")
end

function GetConvar(name, default)
    local key = tostring(name)
    return _convarRegistry[key] or os.getenv(key) or default
end

function GetConvarInt(name, default)
    local v = GetConvar(name, nil)
    return v and tonumber(v) or default
end
function SetConvar(name, value) end

-- ---------------------------------------------------------------------------
-- exports proxy
-- ---------------------------------------------------------------------------
local _exportRegistry = {}
local _resourcePathCache = {}

local function _findResourcePath(name)
    if _resourcePathCache[name] then return _resourcePathCache[name] end
    local searchRoots = { _projectRoot .. "/resources" }
    for _, root in ipairs(searchRoots) do
        local cmd = string.format("find %%q -maxdepth 4 -type d -name %%q 2>/dev/null", root, name)
        local handle = io.popen(cmd)
        if handle then
            local path = handle:read("*l")
            handle:close()
            if path and path ~= "" then 
                _resourcePathCache[name] = path
                return path 
            end
        end
    end
    return nil
end

local function _scanExports(resourceName)
    local path = _findResourcePath(resourceName)
    if not path then return nil end
    local manifestPath = path .. "/fxmanifest.lua"
    local f = io.open(manifestPath, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    local exports = {}
    for name in content:gmatch("export%%s+[\\\"']([^\\'\\\"]+)[\\'\\\"]") do exports[name] = function() return nil end end
    for names in content:gmatch("exports%%s*{(.-)}") do
        for name in names:gmatch("[\\'\\\"]([^\\'\\\"]+)[\\'\\\"]") do exports[name] = function() return nil end end
    end
    return exports
end

exports = setmetatable({}, {
    __index = function(self, resourceName)
        if resourceName == GetCurrentResourceName() then
            if not _exportRegistry[resourceName] then _exportRegistry[resourceName] = {} end
            return _exportRegistry[resourceName]
        end
        local reg = _exportRegistry[resourceName]
        if not reg then reg = _scanExports(resourceName); if reg then _exportRegistry[resourceName] = reg end end
        if not reg then
            return setmetatable({}, {
                __index = function(_, fnName) return function() return nil end end,
                __newindex = function(_, fnName, fn)
                    if not _exportRegistry[resourceName] then _exportRegistry[resourceName] = {} end
                    _exportRegistry[resourceName][fnName] = fn
                end
            })
        end
        return setmetatable({}, {
            __index = function(_, fnName)
                local fn = reg[fnName]; if not fn then return function() return nil end end; return fn
            end
        })
    end,
    __newindex = function(self, key, value)
        local resourceName = GetCurrentResourceName()
        if not _exportRegistry[resourceName] then _exportRegistry[resourceName] = {} end
        if type(value) == "function" then _exportRegistry[resourceName][key] = value
        elseif type(value) == "table" then _exportRegistry[key] = value end
    end,
    __call = function(_, name, fn)
        local resourceName = GetCurrentResourceName()
        if not _exportRegistry[resourceName] then _exportRegistry[resourceName] = {} end
        if type(name) == "table" then for k, v in pairs(name) do _exportRegistry[resourceName][k] = v end
        else _exportRegistry[resourceName][name] = fn end
    end
})

-- ---------------------------------------------------------------------------
-- StateBags
-- ---------------------------------------------------------------------------
local _bagStore = {}
local function _makeBag(bagId)
    if not _bagStore[bagId] then _bagStore[bagId] = {} end
    local bag = {
        set = function(self, key, value, replicated) _bagStore[bagId][key] = value end,
        get = function(self, key) return _bagStore[bagId][key] end
    }
    return setmetatable(bag, {
        __index = function(t, key) if key == "set" or key == "get" then return bag[key] end return _bagStore[bagId][key] end,
        __newindex = function(_, key, value) _bagStore[bagId][key] = value end,
        __tostring = function(_) return string.format("StateBag(%%s)", bagId) end
    })
end

GlobalState = _makeBag("__global__")
local _playerHandles = {}
function Player(netId)
    if not _playerHandles[netId] then _playerHandles[netId] = { state = _makeBag("player:" .. tostring(netId)) } end
    return _playerHandles[netId]
end
local _entityHandles = {}
function Entity(entityId)
    if not _entityHandles[entityId] then _entityHandles[entityId] = { state = _makeBag("entity:" .. tostring(entityId)) } end
    return _entityHandles[entityId]
end

-- ---------------------------------------------------------------------------
-- KVP
-- ---------------------------------------------------------------------------
local _kvp = {}
function GetResourceKvpString(key) local v = _kvp[key]; return (type(v) == "string") and v or nil end
function GetResourceKvpInt(key) local v = _kvp[key]; return (type(v) == "number") and math.floor(v) or nil end
function GetResourceKvpFloat(key) local v = _kvp[key]; return (type(v) == "number") and v or nil end
function SetResourceKvp(key, value) _kvp[key] = value end
SetResourceKvpInt = SetResourceKvp; SetResourceKvpFloat = SetResourceKvp
function DeleteResourceKvp(key) _kvp[key] = nil end
function StartFindKvp(prefix)
    local keys = {}; for k in pairs(_kvp) do if k:sub(1, #prefix) == prefix then table.insert(keys, k) end end
    table.sort(keys); local i = 0; return function() i = i + 1; return keys[i] end
end

-- ---------------------------------------------------------------------------
-- HTTP
-- ---------------------------------------------------------------------------
function PerformHttpRequest(url, callback, ...) callback(0, nil, {}, "standalone: HTTP unavailable") end
function PerformHttpRequestAwait(url, ...) return 0, nil, {}, "standalone: HTTP unavailable" end

-- ---------------------------------------------------------------------------
-- print override
-- ---------------------------------------------------------------------------
local _rawPrint = print
function print(...)
    local function _render(text)
        return tostring(text):gsub("%^(%d)", "")
    end
    local p = {}; for i = 1, select("#", ...) do p[i] = _render(select(i, ...)) end
    _rawPrint(("[%s] %s"):format(GetCurrentResourceName(), table.concat(p, "\t")))
end
rawprint = _rawPrint
