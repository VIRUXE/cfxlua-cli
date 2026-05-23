import sys

path = "/root/citizen-lua/runtime/citizen.lua"
with open(path, "r") as f:
    lines = f.readlines()

config_discovery_lua = r"""
-- ---------------------------------------------------------------------------
-- Config Discovery System (Convars)
-- ---------------------------------------------------------------------------
local _convarRegistry = {}

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
            
            _convarRegistry[key] = value
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
    
    -- Also add script-relative paths if script path is available
    local scriptPath = arg and arg[1]
    if scriptPath then
        local current = scriptPath
        for i = 1, 6 do
            local parent = current:match("(.*)[/\\/]")
            if parent then
                table.insert(searchPaths, parent)
                current = parent
            else
                break
            end
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

-- Initialize discovery
_discoverConfigs()

function GetConvar(name, default)
    return _convarRegistry[name] or os.getenv(name) or default
end

function GetConvarInt(name, default)
    local v = _convarRegistry[name] or os.getenv(name)
    return v and tonumber(v) or default
end
"""

# Same refactored _makeBag...
make_bag_lua = """
local function _makeBag(bagId)
    if not _bagStore[bagId] then _bagStore[bagId] = {} end
    
    local bag = {
        set = function(self, key, value, replicated)
            _bagStore[bagId][key] = value
        end,
        get = function(self, key)
            return _bagStore[bagId][key]
        end
    }
    
    return setmetatable(bag, {
        __index = function(t, key)
            if key == "set" or key == "get" then return bag[key] end
            return _bagStore[bagId][key]
        end,
        __newindex = function(_, key, value)
            _bagStore[bagId][key] = value
        end,
        __tostring = function(_)
            return string.format("StateBag(%s)", bagId)
        end
    })
end
"""

# Apply improvements using line replacement
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
        
    if not skip:
        new_lines.append(line)

with open(path, "w") as f:
    f.writelines(new_lines)
print("Citizen.lua improved successfully.")
