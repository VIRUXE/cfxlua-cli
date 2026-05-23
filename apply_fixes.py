import sys
import os

path = "runtime/citizen.lua"
if not os.path.exists(path):
    path = "/root/citizen-lua/runtime/citizen.lua"

with open(path, "r") as f:
    content = f.read()

config_discovery_lua = r"""-- ---------------------------------------------------------------------------
-- Config Discovery System (Convars)
-- ---------------------------------------------------------------------------
local _convarRegistry = {}

local function _parseCfg(filePath)
    local f = io.open(filePath, "r")
    if not f then return end
    local dir = filePath:match("(.*[\\/])") or ""
    for line in f:lines() do
        local key, value = line:match("^%s*set[rs]?%s+([^%s]+)%s+(.-)%s*$")
        if key and value then
            value = value:gsub("%s*#.*$", "")
            value = value:gsub('^"(.-)"$', "%1"):gsub("^'(.-)'$", "%1")
            value = value:gsub("^%s*(.-)%s*$", "%1")
            _convarRegistry[key] = value
        end
        local execFile = line:match("^%s*exec%s+[\"']?(.-)['\"]?%s*$")
        if execFile then _parseCfg(dir .. execFile) end
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
            if parent then table.insert(searchPaths, parent); current = parent else break end
        end
    end
    for _, base in ipairs(searchPaths) do
        local cfgPath = base .. "/server.cfg"
        local f = io.open(cfgPath, "r")
        if f then f:close(); _parseCfg(cfgPath); break end
    end
end
_discoverConfigs()

-- Production defaults
if not _convarRegistry["onesync_enableInfinity"] then _convarRegistry["onesync_enableInfinity"] = "1" end
if not _convarRegistry["gamename"] then _convarRegistry["gamename"] = "fivem" end

function GetConvar(name, default)
    local key = tostring(name)
    return _convarRegistry[key] or os.getenv(key) or default
end

function GetConvarInt(name, default)
    local v = GetConvar(name, nil)
    return v and tonumber(v) or default
end"""

old_convars = """function GetConvar(name, default)
    return os.getenv(name) or default
end

function GetConvarInt(name, default)
    local v = os.getenv(name)
    return v and tonumber(v) or default
end"""

content = content.replace(old_convars, config_discovery_lua)

make_bag_lua = """local function _makeBag(bagId)
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

import re
bag_pattern = r"local function _makeBag\(bagId\).*?end"
content = re.sub(bag_pattern, make_bag_lua, content, flags=re.DOTALL)

with open(path, "w") as f:
    f.write(content)
print("Citizen.lua improved successfully.")
