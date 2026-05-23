local _convarRegistry = {}

local function _parseCfg(filePath)
    local f = io.open(filePath, "r")
    if not f then return end
    
    local dir = filePath:match("(.*[\\\\/])") or ""
    
    for line in f:lines() do
        local key, value = line:match("^%s*setr?%s+([^%s]+)%s+(.-)%s*$")
        if key and value then
            -- Strip trailing comments
            value = value:gsub("%s*#.*$", "")
            -- Strip surrounding quotes (carefully)
            value = value:gsub("^\"(.-)\"$", "%1"):gsub("^'(.-)'$", "%1")
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

_parseCfg("/gta/v/sindicatorp/server-data/server.cfg")
print("[DEBUG] inventory:framework = [" .. tostring(_convarRegistry["inventory:framework"]) .. "]")
print("[DEBUG] qbx:enableBridge = [" .. tostring(_convarRegistry["qbx:enableBridge"]) .. "]")
