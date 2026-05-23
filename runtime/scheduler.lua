-- =============================================================================
-- scheduler.lua  —  CfxLua Standalone Runtime
-- =============================================================================
Citizen = Citizen or {}

-- ---------------------------------------------------------------------------
-- GetGameTimer shim
-- ---------------------------------------------------------------------------
local _clockOffset = 0
local _t0 = os.clock()

function GetGameTimer()
    return math.floor((os.clock() + _clockOffset - _t0) * 1000)
end

-- Internal helper for bootstrap.lua to compensate for sleep time
function __cfx_add_clock_offset(sec)
    _clockOffset = _clockOffset + sec
end

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local _threads = {}
local _current  = nil
local _frame    = 0
local _awaitYield = {}

local function _heapPush(t, entry)
    t[#t + 1] = entry
    local i = #t
    while i > 1 do
        local parent = math.floor(i / 2)
        if t[parent].wakeTime > t[i].wakeTime then
            t[parent], t[i] = t[i], t[parent]
            i = parent
        else break end
    end
end

local function _heapPop(t)
    if #t == 0 then return nil end
    local top = t[1]
    local last = table.remove(t)
    if #t > 0 then
        t[1] = last
        local i, n = 1, #t
        while true do
            local l, r = 2 * i, 2 * i + 1
            local smallest = i
            if l <= n and t[l].wakeTime < t[smallest].wakeTime then smallest = l end
            if r <= n and t[r].wakeTime < t[smallest].wakeTime then smallest = r end
            if smallest == i then break end
            t[i], t[smallest] = t[smallest], t[i]
            i = smallest
        end
    end
    return top
end

local function _heapPeek(t) return t[1] end

function CreateThread(fn)
    local co = coroutine.create(function()
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then print("[cfxlua] thread error: " .. tostring(err)) end
    end)
    _heapPush(_threads, { wakeTime = GetGameTimer(), co = co })
    return co
end
Citizen.CreateThread = CreateThread

function Wait(ms)
    assert(_current, "Wait() called outside of a CreateThread context")
    local wakeAt = GetGameTimer() + (ms or 0)
    coroutine.yield(wakeAt)
end
Citizen.Wait = Wait

function Citizen.SetTimeout(ms, fn)
    local handle = { _cancelled = false }
    CreateThread(function()
        Wait(ms)
        if not handle._cancelled then fn() end
    end)
    return handle
end

function Citizen.ClearTimeout(handle)
    if type(handle) == "table" then handle._cancelled = true; return true end
    return false
end
SetTimeout = Citizen.SetTimeout
ClearTimeout = Citizen.ClearTimeout

-- ---------------------------------------------------------------------------
-- Promise / Await
-- ---------------------------------------------------------------------------
local Promise = {}
Promise.__index = Promise
function Promise.new()
    return setmetatable({ _state = "pending", _value = nil, _err = nil, _waiters = {} }, Promise)
end
function Promise:resolve(v)
    if self._state ~= "pending" then return end
    self._state, self._value = "resolved", v
    for _, co in ipairs(self._waiters) do _heapPush(_threads, { wakeTime = GetGameTimer(), co = co }) end
    self._waiters = {}
end
function Promise:reject(e)
    if self._state ~= "pending" then return end
    self._state, self._err = "rejected", e
    for _, co in ipairs(self._waiters) do _heapPush(_threads, { wakeTime = GetGameTimer(), co = co }) end
    self._waiters = {}
end
function Citizen.Await(p)
    assert(_current, "Citizen.Await() called outside of a CreateThread context")
    if p._state == "resolved" then return p._value end
    if p._state == "rejected" then error(p._err, 0) end
    table.insert(p._waiters, _current)
    coroutine.yield(_awaitYield)
    if p._state == "resolved" then return p._value end
    error(p._err, 0)
end
_G.Promise = Promise

-- ---------------------------------------------------------------------------
-- Tick Loop
-- ---------------------------------------------------------------------------
function ScheduleResourceTick()
    _frame = _frame + 1
    local now = GetGameTimer()
    while true do
        local top = _heapPeek(_threads)
        if not top or top.wakeTime > now then break end
        _heapPop(_threads)
        local co = top.co
        _current = co
        if coroutine.status(co) ~= "dead" then
            local ok, yieldValue = coroutine.resume(co)
            _current = nil
            if not ok then
                print("[cfxlua] coroutine error: " .. tostring(yieldValue))
            elseif coroutine.status(co) ~= "dead" and yieldValue ~= _awaitYield then
                local wakeAt = (type(yieldValue) == "number") and yieldValue or (now + 0)
                _heapPush(_threads, { wakeTime = wakeAt, co = co })
            end
        else _current = nil end
    end
    local next = _heapPeek(_threads)
    return next and next.wakeTime or nil
end

function HasPendingThreads() return #_threads > 0 end
