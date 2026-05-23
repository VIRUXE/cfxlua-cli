local _convarRegistry = {}

local function _parseCfg(filePath)
    print("[DEBUG] Opening: " .. filePath)
    local f = io.open(filePath, "r")
    if not f then return end
    
    local dir = filePath:match("(.*[\\/])") or ""
    
    for line in f:lines() do
        local key, value = line:match("^%s*set[rs]?%s+([^%s]+)%s+(.-)%s*$")
        if key and value then
            value = value:gsub("%s*#.*$", ""):gsub('^"(.-)"$', "%1"):gsub("^'(.-)'$", "%1"):gsub("^%s*(.-)%s*$", "%1")
            _convarRegistry[key] = value
        end
        local execFile = line:match("^%s*exec%s+[\"']?(.-)['\"]?%s*$")
        if execFile then
            _parseCfg(dir .. execFile)
        end
    end
    f:close()
end

local function _discoverConfigs(scriptPath)
    local searchPaths = { ".", "..", "../..", "../../..", "../../../..", "../../../../.." }
    if scriptPath then
        print("[DEBUG] Script path: " .. scriptPath)
        local current = scriptPath
        for i = 1, 10 do
            local parent = current:match("(.*)[/\\/]")
            if parent then
                print("[DEBUG]   Adding parent: " .. parent)
                table.insert(searchPaths, parent)
                current = parent
            else break end
        end
    end

    for _, base in ipairs(searchPaths) do
        local cfgPath = base .. "/server.cfg"
        print("[DEBUG] Trying: " .. cfgPath)
        local f = io.open(cfgPath, "r")
        if f then
            f:close()
            _parseCfg(cfgPath)
            print("[DEBUG] Found at: " .. cfgPath)
            return
        end
    end
end

_discoverConfigs("/gta/v/sindicatorp/server-data/resources/[qbx]/qbx_core/server/main.lua")
print("[DEBUG] inventory:framework = " .. tostring(_convarRegistry["inventory:framework"]))
