import sys

# 1. Patch citizen.lua
path_citizen = "runtime/citizen.lua"
with open(path_citizen, "r") as f:
    content = f.read()

config_discovery_lua = r"""
-- ---------------------------------------------------------------------------
-- Config Discovery System (Convars)
-- ---------------------------------------------------------------------------
__cfx_convar_registry = __cfx_convar_registry or {}

local function _parseCfg(filePath)
    local f = io.open(filePath, "r")
    if not f then return end
    
    local dir = filePath:match("(.*[\\/])") or ""
    
    for line in f:lines() do
        local key, value = line:match("^%s*setr?%s+([^%s]+)%s+(.-)%s*$")
        if not key then
             key, value = line:match("^%s*set[rs]?%s+([^%s]+)%s+(.-)%s*$")
        end
        
        if key and value then
            value = value:gsub("%%s*#.*$", "")
            value = value:gsub('^"(.-)"$', "%%1"):gsub("^'(.-)'$", "%%1")
            value = value:gsub("^%%s*(.-)%%s*$", "%%1")
            __cfx_convar_registry[key] = value
        end
        
        local execFile = line:match("^%s*exec%s+[\"']?(.-)['\"]?%s*$")
        if execFile then
            _parseCfg(dir .. execFile)
        end
    end
    f:close()
end

local function _discoverConfigs()
    local searchPaths = { ".", "..", "../..", "../../..", "../../../..", "../../../../.." }
    local scriptPath = arg and arg[1]
    if scriptPath then
        local current = scriptPath
        for i = 1, 6 do
            local parent = current:match("(.*)[/\\/]")
            if parent then
                table.insert(searchPaths, parent)
                current = parent
            else break end
        end
    end

    for _, base in ipairs(searchPaths) do
        local cfgPath = base .. "/server.cfg"
        local f = io.open(cfgPath, "r")
        if f then
            f:close()
            _parseCfg(cfgPath)
            break
        end
    end
end

_discoverConfigs()

-- Standard production defaults if not found in cfg
if not __cfx_convar_registry['onesync_enableInfinity'] then
    __cfx_convar_registry['onesync_enableInfinity'] = '1'
end
if not __cfx_convar_registry['gamename'] then
    __cfx_convar_registry['gamename'] = 'fivem'
end

function GetConvar(name, default)
    local key = tostring(name)
    return __cfx_convar_registry[key] or os.getenv(key) or default
end

function GetConvarInt(name, default)
    local v = GetConvar(name, nil)
    return v and tonumber(v) or default
end
"""

# Surgical string replacement
import re

# Replace StateBag function
old_bag = r"local function _makeBag\(bagId\).*?end"
new_bag = """local function _makeBag(bagId)
    if not _bagStore[bagId] then _bagStore[bagId] = {} end
    local bag = {
        set = function(self, key, value, replicated) _bagStore[bagId][key] = value end,
        get = function(self, key) return _bagStore[bagId][key] end
    }
    return setmetatable(bag, {
        __index = function(t, key)
            if key == "set" or key == "get" then return bag[key] end
            return _bagStore[bagId][key]
        end,
        __newindex = function(_, key, value) _bagStore[bagId][key] = value end,
        __tostring = function(_) return string.format("StateBag(%s)", bagId) end
    })
end"""

content = re.sub(old_bag, new_bag, content, flags=re.DOTALL)

# Replace Convar functions
old_convars = r"function GetConvar\(name, default\).*?end\n\nfunction GetConvarInt\(name, default\).*?end"
content = re.sub(old_convars, config_discovery_lua, content, flags=re.DOTALL)

with open(path_citizen, "w") as f:
    f.write(content)

# 2. Patch fxserver.lua
path_fx = "runtime/fxserver.lua"
with open(path_fx, "r") as f:
    content_fx = f.read()

content_fx = re.sub(r"function GetConvar\(name, default\).*?end", "-- (using citizen.lua GetConvar)", content_fx, flags=re.DOTALL)
content_fx = re.sub(r"function GetConvarInt\(name, default\).*?end", "-- (using citizen.lua GetConvarInt)", content_fx, flags=re.DOTALL)

with open(path_fx, "w") as f:
    f.write(content_fx)

print("Citizen.lua and FxServer.lua patched surgically.")
