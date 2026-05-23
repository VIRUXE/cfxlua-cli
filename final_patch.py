import sys
import os
import re

def patch_citizen():
    path = "runtime/citizen.lua"
    if not os.path.exists(path):
        path = "/root/citizen-lua/runtime/citizen.lua"
    
    with open(path, "r") as f:
        content = f.read()

    # 1. Patch MagicMock and require
    magic_mock_lua = r"""local function createMagicMock(name)
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
end"""

    old_magic_pattern = r"local function createMagicMock\(name\).*?function GetInvokingResource\(\).*?end"
    # Actually, let's find the exact markers for MagicMock
    start_marker = "local function createMagicMock"
    end_marker = "-- ---------------------------------------------------------------------------"
    # We want the SECOND occurrence of end_marker after start_marker
    start_idx = content.find(start_marker)
    first_end_idx = content.find(end_marker, start_idx)
    second_end_idx = content.find(end_marker, first_end_idx + 1)
    
    if start_idx != -1 and second_end_idx != -1:
        content = content[:start_idx] + magic_mock_lua + "\n\n" + content[second_end_idx:]

    # 2. Patch Config Discovery and GetConvar
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

    old_convars_pattern = r"function GetConvar\(name, default\).*?end\n\nfunction GetConvarInt\(name, default\).*?end"
    content = re.sub(old_convars_pattern, config_discovery_lua, content, flags=re.DOTALL)

    # 3. Patch StateBags methods
    make_bag_lua = r"""local function _makeBag(bagId)
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

    bag_pattern = r"local function _makeBag\(bagId\).*?end"
    content = re.sub(bag_pattern, make_bag_lua, content, flags=re.DOTALL)

    with open(path, "w") as f:
        f.write(content)

def patch_fxserver():
    path = "runtime/fxserver.lua"
    if not os.path.exists(path):
        path = "/root/citizen-lua/runtime/fxserver.lua"
    
    with open(path, "r") as f:
        lines = f.readlines()
    
    new_lines = []
    skip = False
    for line in lines:
        if "function GetConvar(name, default)" in line or "function GetConvarInt(name, default)" in line:
            new_lines.append("-- (using citizen.lua implementation)\n")
            skip = True
            continue
        if skip and line.strip() == "end":
            skip = False
            continue
        if not skip:
            new_lines.append(line)
            
    with open(path, "w") as f:
        f.writelines(new_lines)

if __name__ == "__main__":
    patch_citizen()
    patch_fxserver()
    print("Mocks improved successfully.")
