local POKER_PROTOCOL = "poker.protocol"

local DEFAULT_TIMEOUT = 100
local ACK_ACTION = "ack"
local actionHandlers = {}
local callbacks = {}
local tick = 0
local messageId = 0

local function print(text)
    io.write(text .. "\n")
    io.flush()
end

local sendMessage = function(receiverId, message, onAck, onError, timeout)
	timeout = timeout or DEFAULT_TIMEOUT
	assert(receiverId ~= nil, "Receiver ID must not be nil")
	assert(message ~= nil, "Message must not be nil")
	assert(message.action ~= nil, "Message must contain an action")
	message.messageId = messageId
	messageId = messageId + 1 % 65536
	rednet.send(receiverId, message, POKER_PROTOCOL)
	callbacks[messageId] = {
		onAck = onAck,
		onError = onError,
		expiry = tick + timeout
	}
end

local addActionHandler = function(action, handler)
	assert(action ~= nil, "Action must not be nil")
	assert(action ~= ACK_ACTION, "Action must not be ack")
	assert(handler ~= nil, "Handler must not be nil")

	actionHandlers[action] = handler
end

local ack = function(senderId, message)
	if (message.messageId == nil) then
		print(string.format("WARNING: Received message from %d with no messageId: %s", receiverId, textutils.serialize(message)))
		return
	end
	rednet.send(senderId, {action=ACK_ACTION, messageId = message.messageId}, POKER_PROTOCOL)
end

local onPokerMessage = function(senderId, message)
	if (not message or not message.action) then
		print(string.format("Received invalid poker message: %s", textutils.serialize(message)))
		return
	end
	if (message.action == ACK_ACTION) then
		if (not message.messageId) then
			print(string.format("WARNING: Received ack from %d with no messageId: %s", receiverId, textutils.serialize(message)))
			return
		end
		local callback = callbacks[message.messageId]
		if (not callback) then
			print(string.format("WARNING: Received ack from %d with no matching callback %d", receiverId, message.messageId))
			return
		end
		if (callback.onAck) then
			callback.onAck()
		end
		return
	end
	local handler = actionHandlers[message.action]
	if (handler) then
		ack(senderId, message)
		handler(senderId, message)
	else
		print(string.format("Received unknown poker message: %s", textutils.serialize(message)))
	end
end

local onTick = function()
	tick = tick + 1
	for k, callback in pairs(callbacks) do
		if (callback.expiry <= tick) then
			callbacks[k] = nil
			if (callback.onError) then
				callback.onError("Timed out")
			end
		end
	end
end

return {
	POKER_PROTOCOL = POKER_PROTOCOL,
	onPokerMessage = onPokerMessage,
	sendMessage = sendMessage,
	addActionHandler = addActionHandler,
	onTick = onTick
}