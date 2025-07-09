-- Alternative _G table, syncs across all scripts (local and server if you put in ReplicatedStorage).
-- I've also added more functionality that the _G table otherwise doesn't have.
-- Stuff like:
-- Mutex/lock thread synchronization
-- Easy to use read-only controls
-- ..and more coming soon!

local CORE_LOCKED = {
	YZ_DEBUG_ = false,
}

local _SYNC_DATA = {
	YZ_SHOW_SPEED_ = true,
	YZ_LOADED_FINISH_ = false,
	YZ_INTRO_FINISH_ = false,
}

local events = {}
local locked_indexes = {} -- key = true if locked
local locked_by = {} -- key = script that locked it
local lock_queue = {}
local locked = false

local function AcquireLock()
	while locked do
		local thread = coroutine.running()
		table.insert(lock_queue, thread)
		coroutine.yield()
	end
	locked = true
end

local function ReleaseLock()
	locked = false
	if #lock_queue > 0 then
		local next_thread = table.remove(lock_queue, 1)
		coroutine.resume(next_thread)
	end
end

local _SYNC = setmetatable({}, {
	__index = function(_, k)
		return _SYNC_DATA[k]
	end,
	__newindex = function(_, k, v)
		if CORE_LOCKED[k] then
			warn("[_SYNC] Attempt to modify CoreLocked (read-only) key: " .. tostring(k))
			return
		end
		if locked_indexes[k] then
			warn("[_SYNC] Attempt to modify Locked (read-only) key: " .. tostring(k))
			return
		end
		AcquireLock()
		local old = _SYNC_DATA[k]
		_SYNC_DATA[k] = v
		if events[k] then
			events[k]:Fire(v, old)
		end
		ReleaseLock()
	end,
})

function _SYNC:LockIndex(key, lock_key)
	if CORE_LOCKED[key] then
		warn("[_SYNC] Cannot lock a CoreLocked key: " .. tostring(key))
		return
	end
	if locked_indexes[key] then
		warn("[_SYNC] Key already locked: " .. tostring(key))
		return
	end
	locked_indexes[key] = true
	locked_by[key] = lock_key
end

function _SYNC:UnlockIndex(key, lock_key)
	if CORE_LOCKED[key] then
		warn("[_SYNC] Cannot unlock a CoreLocked key: " .. tostring(key))
		return
	end
	if not locked_indexes[key] then
		warn("[_SYNC] Key is not locked: " .. tostring(key))
		return
	end
	if locked_by[key] ~= lock_key then
		warn("[_SYNC] Only the lock_key that locked this key can unlock it: " .. tostring(key))
		return
	end
	locked_indexes[key] = nil
	locked_by[key] = nil
end

function _SYNC:IsLocked(key)
	return locked_indexes[key] == true
end

function _SYNC:IsCoreLocked(key)
	return CORE_LOCKED[key] == true
end

function _SYNC:OnChanged(key)
	if not events[key] then
		events[key] = Instance.new("BindableEvent")
	end
	return events[key]
end

--[[
	SafeSet is depricated. Use regular table indexing instead.

	SafeSet
	Safely sets an index (key: any) to a value (value: any) inside of the _SYNC_DATA table.
]]
function _SYNC.SafeSet(key, value)
	warn(
		"[_SYNC] SafeSet is depricated. Use regular table indexing instead. - game."
			.. debug.info(2, "s")
			.. " - "
			.. debug.info(2, "l")
	)

	if CORE_LOCKED[key] then
		warn("[_SYNC] Attempt to modify CoreLocked (read-only) key: " .. tostring(key))
		return
	end
	if locked_indexes[key] then
		warn("[_SYNC] Attempt to modify Locked (read-only) key: " .. tostring(key))
		return
	end
	AcquireLock()
	local old = _SYNC_DATA[key]
	_SYNC_DATA[key] = value
	if events[key] then
		events[key]:Fire(value, old)
	end
	ReleaseLock()
end

return _SYNC
