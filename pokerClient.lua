local pokerRender = require("pokerRender")
local pokerProtocol = require("pokerProtocol")
local player = {name="Tom", cards={{number="5", suit="H"}, {number="Q", suit="D"}}, chips = 20, bettingChips=0}
local frm = 1
assert(peripheral.getType("back") == "modem", "Personal computer must have a modem attached!")
rednet.open("back")
rednet.host(pokerProtocol.POKER_PROTOCOL, "pokerClient")
local serverReceiverId = nil

io.output("/pokerClient.log")
function print(text)
	io.write(text .. "\n")
    io.flush()
end


function drawString(to, str, maxLength, pos, backColor, textColor)
	for i = 1, math.min(string.len(str), maxLength) do
		to:drawPixel(math.floor(pos.x) + i - 1, math.floor(pos.y), backColor, textColor, string.sub(str, i, i) .. "")
	end
end

local currentBet = 32
local raiseable = true
local raiseAmount = ""
local isActive = false
-- lobby -> viewCards 
--  -> exit
--  -> fold
--  -> bet

local uiState = "lobby"
-- Connecting -> Waiting to Start
local lobbyStatus = "Connecting"

local buttons = {}
local buttonVisibilityGroups = {lobby = {}, viewCards = {}, exit = {}, raise = {}, call = {}, fold = {}}

function createButton(text, x, y, width, height, backColors, textColors, align)
	local innerX = x + 1
	local innerY = y
	local innerWidth = width - 1
	local innerHeight = height - 1

	if (align == "left") then
		innerX = x
	elseif (align == "center") then
		innerY = y + 1
		innerWidth = width - 2
		innerHeight = height - 2
	elseif (align == "bottom") then
		innerY = y + 1
		innerWidth = width - 2
	end

	local button = {
		text = text,
		x = x,
		innerX = innerX,
		innerY = innerY,
		innerWidth = innerWidth,
		innerHeight = innerHeight,
		y = y,
		width = width,
		height = height,
		backColors = {active = backColors[1], inActive = backColors[2] or backColors[1]},
		textColors = {active = textColors[1], inActive = textColors[2] or textColors[1]},
		visible = true
	}
	function button:isInside(x, y)
		if (x <= self.x) then
			return false
		end
		if (y <= self.y) then
			return false
		end
		if (x > self.x + self.width) then
			return false
		end
		if (y > self.y + self.height) then
			return false
		end
		return true
	end
	return button
end

function changeState(state)
	--print(string.format("Changing state from %s to %s", uiState, state))
	uiState = state
	if (state == "viewCards") then
		viewCards()
	elseif (state == "bet") then
		bet()
	elseif (state == "fold") then
		fold()
	end
end

function changeVisibilityGroup(group)
	for _, button in ipairs(buttons) do
		button.visible = false
	end
	for _, button in ipairs(buttonVisibilityGroups[group]) do
		button.visible = true
	end
end

function viewCards()
	changeVisibilityGroup("viewCards")
end

function bet()
	raiseAmount = ""
	if (raiseable) then
		changeVisibilityGroup("raise")
	else
		changeVisibilityGroup("call")
	end
end

function fold()
	sendFoldMessage()
	changeVisibilityGroup("fold")
end

function onBet(totalRaised)
	--print(totalRaised + currentBet)
	raiseable = false
	local amountBet = math.min(player.chips, totalRaised + currentBet)
	player.chips = player.chips - amountBet
	player.bettingChips = player.bettingChips + amountBet
	sendBetMessage(amountBet)
	isActive = false
	changeState("viewCards")
end

function onFold()
	isActive = false
	player.cards = {}
	changeState("viewCards")
end

function onQuit()
	
end

function onJoined()
	print ("Game joined")
	lobbyStatus = "Waiting to Start"
end

function onJoinError(error)
	assert(error == "Timed out", "Unknown network error: " .. error)
	print ("Failed to join after timeout, retrying...")
	sendJoinMessage()
end

function sendJoinMessage()
	pokerProtocol.sendMessage(serverReceiverId, {action="join", player=player}, onJoined)
end

function sendFoldMessage()
	pokerProtocol.sendMessage(serverReceiverId, {action="fold"})
end

function sendBetMessage(betAmount)
	pokerProtocol.sendMessage(serverReceiverId, {action="bet", betAmount=betAmount})
end

function onGameStarted(senderId, message)
	print("Game starting")
	changeState("viewCards")
end

function onPlayerStateChanged(senderId, message)
	print (string.format("Got state change from server: %s", textutils.serialize(message)))
	if (not message.state) then
		print("WARNING: Server sent nil state, ignoring")
		return
	end
	for k, v in pairs(message.state) do
		player[k] = v
	end
end

function onIsActivePlayer(senderId, message)
	print (string.format("Server informed us we are active: %s", textutils.serialize(message)))
	isActive = true
	currentBet = message.currentBet
end

pokerProtocol.addActionHandler("start", onGameStarted)
pokerProtocol.addActionHandler("playerState", onPlayerStateChanged)
pokerProtocol.addActionHandler("activePlayer", onIsActivePlayer)

function drawButton(to, button, isActive)
	if (not button.visible) then
		return
	end
	to:fillRect(button.x, button.y, button.width, button.height, colors.black)
	to:fillRect(button.innerX, button.innerY, button.innerWidth, button.innerHeight, isActive and button.backColors.active or button.backColors.inActive)
	drawString(to, button.text, button.innerWidth, vector.new(button.innerX, button.innerY), isActive and button.backColors.active or button.backColors.inActive, isActive and button.textColors.active or button.textColors.inActive)
end

table.insert(buttons, createButton("$", 0, 0, 6, 2, {colors.blue}, {colors.white}, "left"))
table.insert(buttons, createButton("Check", 6, 0, 6, 2, {colors.blue, colors.gray}, {colors.white, colors.lightGray}, "left"))
table.insert(buttons, createButton(" Bet ", 12, 0, 6, 2, {colors.lime, colors.gray}, {colors.white, colors.lightGray}, "left"))

table.insert(buttons, createButton("Fold", pokerRender.screen.width - 7, 0, 5, 2, {colors.red, colors.gray}, {colors.white, colors.lightGray}, "right"))
table.insert(buttons, createButton("x", pokerRender.screen.width - 2, 0, 2, 2, {colors.red}, {colors.white, colors.black}, "right"))

table.insert(buttonVisibilityGroups.viewCards, buttons[1])
table.insert(buttonVisibilityGroups.viewCards, buttons[2])
table.insert(buttonVisibilityGroups.viewCards, buttons[3])
table.insert(buttonVisibilityGroups.viewCards, buttons[4])
table.insert(buttonVisibilityGroups.viewCards, buttons[5])

table.insert(buttons, createButton("", 3, 4, pokerRender.screen.width - 6, pokerRender.screen.height - 8, {colors.gray}, {colors.gray}, "center"))
table.insert(buttons, createButton("  Raise  ", 3, pokerRender.screen.height - 7, 11, 2, {colors.blue, colors.gray}, {colors.white, colors.lightGray}, "bottom"))
table.insert(buttons, createButton(" Cancel ", pokerRender.screen.width - 13, pokerRender.screen.height - 7, 10, 2, {colors.red}, {colors.white}, "bottom"))
table.insert(buttons, createButton("$", 5, 8, pokerRender.screen.width - 10, 3, {colors.lightGray}, {colors.white}, "center"))

table.insert(buttonVisibilityGroups.raise, buttons[1])
table.insert(buttonVisibilityGroups.raise, buttons[6])
table.insert(buttonVisibilityGroups.raise, buttons[7])
table.insert(buttonVisibilityGroups.raise, buttons[8])
table.insert(buttonVisibilityGroups.raise, buttons[9])

table.insert(buttonVisibilityGroups.call, buttons[1])
table.insert(buttonVisibilityGroups.call, buttons[6])
table.insert(buttonVisibilityGroups.call, buttons[7])
table.insert(buttonVisibilityGroups.call, buttons[8])

table.insert(buttons, createButton("", 3, 4, pokerRender.screen.width - 6, pokerRender.screen.height - 9, {colors.gray}, {colors.gray}, "center"))
table.insert(buttons, createButton("  Fold  ", 3, pokerRender.screen.height - 8, 10, 2, {colors.red}, {colors.white, colors.lightGray}, "bottom"))
table.insert(buttons, createButton("  Cancel ", pokerRender.screen.width - 14, pokerRender.screen.height - 8, 11, 2, {colors.lightGray}, {colors.white}, "bottom"))

table.insert(buttonVisibilityGroups.fold, buttons[10])
table.insert(buttonVisibilityGroups.fold, buttons[11])
table.insert(buttonVisibilityGroups.fold, buttons[12])

changeVisibilityGroup("lobby")

buttons[2].onClick = function()
	if (uiState == "viewCards" and currentBet < 1) then
		onBet(0)
	end	
end

buttons[3].onClick = function()
	if (uiState == "viewCards") then 
		changeState("bet")
	end
end

buttons[4].onClick = function()
	if (uiState == "viewCards") then 
		changeState("fold")
	end
end

buttons[5].onClick = function()
	if (uiState == "viewCards") then 
		onQuit()
	end
end

buttons[7].onClick = function()
	if (uiState == "bet") then
		onBet(tonumber(raiseAmount) or 0)
	end
end

buttons[8].onClick = function()
	if (uiState == "bet") then
		changeState("viewCards")
	end
end

buttons[11].onClick = function()
	if (uiState == "fold") then 
		onFold()
	end
end

buttons[12].onClick = function()
	if (uiState == "fold") then
		changeState("viewCards")
	end
end

while (true) do
	pokerRender.screen:clear(colors.green)
	if (uiState ~= "lobby") then
		drawSharedCards(pokerRender.screen, vector.new(pokerRender.screen.width / 2 + 1, pokerRender.screen.height / 2 + 2), player.cards, nil, 2)
	else
		local statusStr = lobbyStatus .. "..."
		drawString(pokerRender.screen, statusStr, string.len(lobbyStatus) + math.floor((frm % 20) / 5), vector.new(3, pokerRender.screen.height / 2), colors.green, colors.white)
	end
	local chipStr = string.format("$%d", player.chips)
	buttons[1].text = chipStr
	local raiseChips = (tonumber(raiseAmount) or 0) + currentBet
	if (raiseChips >= player.chips) then
		buttons[7].text = " All  In "
		buttons[7].backColors.active = colors.orange
		buttons[7].backColors.inActive = colors.orange
		buttons[7].textColors.inActive = colors.black
	else
		if(raiseChips == currentBet) then
			buttons[7].text = "  Call   "	
			buttons[7].backColors.active = colors.blue
		else
			buttons[7].text = "  Raise  "
			buttons[7].backColors.active = colors.lime
		end
		buttons[7].backColors.inActive = colors.gray
		buttons[7].textColors.inActive = colors.lightGray
	end
	buttons[9].text = "$" .. raiseAmount

	for i, button in ipairs(buttons) do
		local active = isActive
		if (i == 2) then
			if (currentBet > 0) then
				active = false
			end
		elseif (i == 5) then
			active = frm % 20 < 10
		elseif (i == 7) then
			--active = string.len(raiseAmount) > 0
			if (raiseChips >= player.chips) then
				active = frm % 10 > 4
			end
		end
		drawButton(pokerRender.screen, button, active)
	end

	if (uiState == "bet") then
		local totalStr = string.format("Total: $%d", raiseChips)
		drawString(pokerRender.screen, string.format("To Call: $%d", currentBet), pokerRender.screen.width - 10, vector.new(5, raiseable and 6 or 9), colors.gray, colors.white)
		if (raiseable) then
			drawString(pokerRender.screen, "Raise By:", pokerRender.screen.width - 10, vector.new(5, 7), colors.gray, colors.white)
			drawString(pokerRender.screen, "_", 1, vector.new(7 + #raiseAmount, 9), colors.lightGray, frm % 10 > 4 and colors.white or colors.black)
			drawString(pokerRender.screen, totalStr, pokerRender.screen.width - 10,  vector.new((pokerRender.screen.width - string.len(totalStr)) / 2, 12), colors.gray, colors.white)
		end
	elseif (uiState == "fold") then
		drawString(pokerRender.screen, "Are you sure", 15, vector.new(pokerRender.screen.width / 2 - 6, 7), colors.gray, colors.white)
		drawString(pokerRender.screen, "you want", 18, vector.new(pokerRender.screen.width / 2 - 4, 8), colors.gray, colors.white)
		drawString(pokerRender.screen, "to fold?", 18, vector.new(pokerRender.screen.width / 2 - 4, 9), colors.gray, colors.white)
	elseif (uiState == "viewCards" and isActive) then
		drawString(pokerRender.screen, "Your Turn", 9, vector.new(pokerRender.screen.width / 2 - 4.5, 2), ((frm % 40) < 20) and colors.gray or colors.black, ((frm % 40) < 20) and colors.white or colors.yellow)
	end

	pokerRender.screen:output(pokerRender.monitor)

	if (uiState == "lobby") then
		if (serverReceiverId == nil) then
			serverReceiverId = rednet.lookup(pokerProtocol.POKER_PROTOCOL, "pokerServer")
			if (serverReceiverId ~= nil) then
				print(string.format("Got server receiver id of %d", serverReceiverId))
				sendJoinMessage()
			end
		end
	end
	os.startTimer(0.05)
	while (true) do
		local result = table.pack(os.pullEvent())
		local eventName = table.remove(result, 1)
		if (eventName == "timer") then
			pokerProtocol.onTick()
			break
		elseif (eventName == "modem_message") then
			print ("Ignoring modem message")
		elseif (eventName == "mouse_click") then
			local mouseButton, x, y = table.unpack(result)
			for _, button in ipairs(buttons) do
				if (mouseButton == 1 and button.visible and button.onClick and button:isInside(x, y)) then
					button.onClick()
					break
				end
			end
		elseif (eventName == "char") then
			if (uiState == "bet" and raiseable) then
				local char = result[1]
				if (char >= "0" and char <= "9") then
					raiseAmount = raiseAmount .. char
					if ((tonumber(raiseAmount) or 0) + currentBet > player.chips) then
						raiseAmount = tostring(math.max(0, player.chips - currentBet))
					end
				end
			end
		elseif (eventName == "key_up") then
			local keyCode = result[1]
			if (uiState == "bet" and raiseable and keyCode == keys.backspace and string.len(raiseAmount) > 0) then
				raiseAmount = string.sub(raiseAmount, 1, #raiseAmount - 1) .. ""
			end
		elseif (eventName == "rednet_message") then
			senderId, message, protocol = table.unpack(result)
			if (protocol == pokerProtocol.POKER_PROTOCOL) then
				pokerProtocol.onPokerMessage(senderId, message)
			elseif (protocol ~= nil) then
				print(string.format("Received message on unknown protocol %s", protocol))
			end
		else
			--print (textutils.serialize(result))
		end
	end
	frm = frm + 1
end