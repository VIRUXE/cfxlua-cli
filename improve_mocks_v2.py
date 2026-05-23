import sys
import re

# 1. Patch citizen.lua
path_citizen = "/root/citizen-lua/runtime/citizen.lua"
with open(path_citizen, "r") as f:
    lines = f.readlines()

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
        if key and value then
            -- Strip trailing comments
            value = value:gsub("%s*#.*$", "")
            -- Strip surrounding quotes
            value = value:gsub('^"(.-)"$', "%1"):gsub("^'(.-)'$", "%1")
            -- Trim whitespace
            value = value:gsub("^%s*(.-)%s*$", "%1")
            
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
        for i = 1, 10 do
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

function GetConvar(name, default)
    return __cfx_convar_registry[name] or os.getenv(name) or default
end

function GetConvarInt(name, default)
    local v = __cfx_convar_registry[name] or os.getenv(name)
    return v and tonumber(v) or default
end
"""

make_bag_lua = """
local function _makeBag(bagId)
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
end
"""

new_lines = []
skip = False
for line in lines:
    if "local function _makeBag(bagId)" in line:
        new_lines.append(make_bag_lua + "\n")
        skip = True
        continue
    if skip and "GlobalState =" in line:
        skip = False
        new_lines.append(line)
        continue
    if "function GetConvar(name, default)" in line:
        new_lines.append(config_discovery_lua + "\n")
        skip = True
        continue
    if skip and "PerformHttpRequest" in line:
        skip = False
        new_lines.append(line)
        continue
    if not skip: new_lines.append(line)

with open(path_citizen, "w") as f:
    f.writelines(new_lines)

# 2. Patch fxserver.lua properly
path_fx = "/root/citizen-lua/runtime/fxserver.lua"
with open(path_fx, "r") as f:
    lines_fx = f.readlines()

new_lines_fx = []
skip_fx = False
for line in lines_fx:
    if "function GetConvar(name, default)" in line:
        new_lines_fx.append("-- (using citizen.lua GetConvar)\n")
        skip_fx = True
        continue
    if "function GetConvarInt(name, default)" in line:
        new_lines_fx.append("-- (using citizen.lua GetConvarInt)\n")
        skip_fx = True
        continue
    if skip_fx and line.strip() == "end":
        skip_fx = False
        continue
    if not skip_fx:
        new_lines_fx.append(line)

with open(path_fx, "w") as f:
    f.writelines(new_lines_fx)

print("Citizen.lua and FxServer.lua patched.")
