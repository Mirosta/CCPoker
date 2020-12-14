local PLINTH_PROTOCOL = "plinth.protocol"
local MAX_SLOTS = 16
local suckFromPlinthSide = "top"
local suckToPlinthSide = "right"
local locationId

function findModem()
	for _, side in ipairs(peripheral.getNames()) do
		if (peripheral.getType(side) == "modem") then
			return side
		end
	end
	error("Must have a modem attached to use this script")
end

function readConfig()
	local f = io.open("/plinth.conf")
	if (f == nil) then
		print("WARNING: Unable to find config file /plinth.conf")
		return nil
	end
	local conf = textutils.unserialize(f:read("*a") or "")
	f:close()
	return conf
end
local config = readConfig()
locationId = config and config.locationId or nil
assert(locationId, "locationId must be configured in /plinth.conf")

function suckUntilEmpty()
	while (turtle.suck()) do
		sleep(0.05)
	end
end


function findItem(name)
	for i = 1, MAX_SLOTS do
		local item = turtle.getItemDetail(i)
		if (item and item.name == name) then
			item.slot = i
			return item
		end
	end
	return nil
end

function findComputer()
	if (fs.exists("/disk")) then
		turtle.suckDown()
	end
	return findItem("computercraft:pocket_computer")
end

function findDisk()
	if (fs.exists("/disk")) then
		turtle.suckDown()
	end
	return findItem("computercraft:disk_expanded")
end

function suckFromPlinth(enabled)
	redstone.setOutput(suckFromPlinthSide, enabled)
end

function suckToPlinth(enabled)
	redstone.setOutput(suckToPlinthSide, enabled)
end

function readDiskState()
	local f = io.open("/disk/player.conf")
	if (f == nil) then
		print("WARNING: Unable to find config file /disk/player.conf")
		return nil
	end
	local conf = textutils.unserialize(f:read("*a") or "")
	f:close()
	return conf
end

function writeDiskState(state)
	local f = io.open("/disk/player.conf", "w")
	if (f == nil) then
		print("WARNING: Unable to find config file /disk/player.conf")
		return false
	end
	f:write(textutils.serialize(state))
	f:close()
	return true
end

function tryMountItem(item, itemType)
	turtle.select(item.slot)
	local attempts = 0
	while (turtle.suckDown() and attempts < 10) do
		print ("Found item in disk drive, removing")
		sleep(0.05)
		attempts = attempts + 1
	end
	if (attempts >= 10 or not turtle.dropDown()) then
		print (string.format("WARNING: Failed to insert %s, will retry", itemType))
		return false
	end
	if (not fs.exists("/disk")) then
		print (string.format("The %s is not readable, will retry", itemType))
		turtle.suckDown()
		return false
	end
	return true
end

function processDisk(diskItem)
	if (not tryMountItem(diskItem, "disk")) then
		return nil
	end

	local state = readDiskState()
	turtle.suckDown()
	if (not state) then
		return nil
	end
	return {
		name = state.name,
		chips = state.chips
	}
end

function setupComputer(computerItem, diskData)
	if (not tryMountItem(diskItem, "disk")) then
		return false
	end
	
	diskData.locationId = locationId
	local success = writeDiskState(diskData)
	turtle.suckDown()
	return success
end

assert(peripheral.getType("bottom") == "drive", "Must have a drive attached below this turtle")

local modemSide = findModem()
local serverReceiverId
local playerName
-- waitingForServer -> waitingForDisk -> waitingForPlayer -> waitingForQuit -> waitingForComputer -> goto waitingForDisk
local mode = "waitingForServer"

rednet.open(modemSide)

suckToPlinth(false)
suckFromPlinth(false)
local sleepTime = 1

while true do
	if (mode == "waitingForServer") then
		serverReceiverId = rednet.lookup(PLINTH_PROTOCOL, "pokerServer")
		sleepTime = 5
		if (serverReceiverId ~= nil) then
			sleepTime = 1
			print(string.format("Got server receiver id of %d", serverReceiverId))
			if (findComputer() == nil) then
				print ("Unable to find computer in inv, waiting for it to be returned")
				mode = "waitingForComputer"
			else
				mode = "waitingForDisk"
			end
		end
	elseif (mode == "waitingForDisk") then
		local diskItem = findDisk()
		sleepTime = 1
		if (diskItem ~= nil) then
			local computerItem = findComputer()
			if (computerItem == nil) then
				print("Got a disk but couldn't find computer, will wait for it to be returned")
				mode = "waitingForComputer"
			else
				print ("Got a disk, will set up computer and give back")
				local diskData = processDisk(diskItem)
				if (diskData) then
					if (setupComputer(computerItem, diskData) and supplyComputer()) then
						mode = "waitingForPlayer"
					else
						print("Unable to setup and supply computer, will retry")
					end
				else
					print("WARNING: Unable to process disk, will retry")
				end
			end
		else
			suckToPlinth(false)
			suckFromPlinth(true)
			suckUntilEmpty()
		end
	elseif (mode == "waitingForPlayer") then
		rednet.send(serverReceiverId, {action = "hasPlayerJoined", name = playerName, locationId = locationId}, PLINTH_PROTOCOL)
		local senderId, message = rednet.receive(PLINTH_PROTOCOL, 5)
		sleepTime = 5
		if (senderId) then
			print(string.format("Got plinth message from %s: %s", senderId, textutils.serialize(message)))
			if (not message or message.playerJoined == nil) then
				print ("WARNING: Message missing playerJoined field, will retry")
			elseif (not message.playerJoined) then
				print ("Player not yet joined, will retry")
			else
				print ("Player has joined, will wait for player to quit")
			end
		else
			print("Timed out waiting for server reply, will retry")
			sleepTime = 0.5
		end
	elseif (mode == "waitingForQuit") then
		rednet.send(serverReceiverId, {action = "hasPlayerQuit"}, PLINTH_PROTOCOL)
		local senderId, message = rednet.receive(PLINTH_PROTOCOL, 5)
		sleepTime = 5
		if (senderId) then
			print(string.format("Got plinth message from %s: %s", senderId, textutils.serialize(message)))
			if (not message or message.playerQuit == nil) then
				print ("WARNING: Message missing playerQuit field, will retry")
			elseif (not message.playerQuit) then
				print ("Player not yet quit, will retry")
			else
				print ("Player has quit, will wait for computer to be retured")
				mode = "waitForComputer"
			end
		else
			print("Timed out waiting for server reply, will retry")
			sleepTime = 0.5
		end
	elseif (mode == "waitingForComputer") then
		local computerItem = findComputer()
		if (computerItem ~= nil) then
			print("Got computer back, will return current disk and wait for a new one")
			returnDisk()
			sleepTime = 30
		else
			sleepTime = 1
			suckToPlinth(false)
			suckFromPlinth(true)
			suckUntilEmpty()
		end
	end
	sleep(sleepTime)
end
