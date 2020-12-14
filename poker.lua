require("pokerRender")
local PLINTH_PROTOCOL = "plinth.protocol"
local pokerProtocol = require("pokerProtocol")
local hands = require('hands')

local bigBlind = 4
local smallBlind = 2

io.output("/poker.log")
function print(text)
    io.write(text .. "\n")
    io.stdout:write(text .. "\n")
    io.flush()
    io.stdout:flush()
end

local players = {
	{name = "Tom", location=1, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=2, drawChips=2, bettingChips=0},
	{name = "Tom", location=3, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=220, drawChips=220, bettingChips=0, dealer=true},
	{name = "Tom", location=5, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=333, drawChips=333, bettingChips=0},
	{name = "Tom", location=7, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=4444, drawChips=4444, bettingChips=0},
	{name = "Tom", location=6, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=500, drawChips=500, bettingChips=0},
	{name = "Tom", location=4, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=660, drawChips=660, bettingChips=0},
	{name = "Tom", location=2, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=770, drawChips=770, bettingChips=0},
	{name = "Tom", location=8, cards={}, flipped=true, quit=false, folded=false, allIn=false, hasActed = false, chips=888, drawChips=888, bettingChips=0},
}
local playersByReceiverId = {}
local pots = {}

local sharedCards = {}
local deck = hands.shuffledDeck()
local description = hands.describeHand(sharedCards, {})
local result = hands.evaluateHand(description)
local matchedCardsSet = nil
local isDraw = false
local currentPot = 0
local totalPots = 0

-- lobby ->
--   preFlop -> flop -> turn -> river -> revealing -> finish -> >1 players ? goto preFlop : goto lobby
local gameState = ""
local activePlayer = nil
local dealerPlayer = 0
local timer = 0

function changeState(state)
	print (string.format("Changing state from %s to %s", gameState, state))
	gameState = state
	if (state == "preFlop") then
		newRound()
	elseif (state == "flop") then
		flop()
	elseif (state == "turn") then
		turn()
	elseif (state == "river") then
		river()
	elseif (state == "revealing") then
		endBettingRound()
		revealNext()
	elseif (state == "finish") then
		finishRound()
	end
end

function updateActivePlayer()
	for i = 1, #players do
		local index = wrapPlayerIndex(activePlayer + i)
		local player = players[index]
		if (not player.folded and not player.quit and not player.allIn and (player.bettingChips < pots[1].bettingChips or not player.hasActed)) then
			activePlayer = index
			if (player.receiverId) then
				print("Informing actual player")
				sendActivePlayerMessage(player)
			end
			return false
		end
	end
	activePlayer = wrapPlayerIndex(dealerPlayer + 1)
	return true
end

function nextBet()
	if (players[activePlayer].receiverId) then
		print ("Waiting for actual player")
		return
	end
	if (math.random() < 0.3) then
		if (onFold(players[activePlayer])) then
			return false
		end
	else
		onBet(players[activePlayer], pots[1].bettingChips - players[activePlayer].bettingChips)
	end
	return updateActivePlayer()
end

function nextState()
	if (gameState == "preFlop") then
		if (nextBet()) then
			changeState("flop")
		end
	elseif (gameState == "flop") then
		if (nextBet()) then
			changeState("turn")
		end
	elseif (gameState == "turn") then
		if (nextBet()) then
			changeState("river")
		end
	elseif (gameState == "river") then
		if (nextBet()) then
			changeState("revealing")
		end
	elseif (gameState == "revealing") then
		print("Revealing will end automatically")
	elseif (gameState == "finish") then
		-- changeState("preFlop")
		print("Finish will end automatically")
	else
		print("Unknown state " .. gameState)
	end
end

function wrapPlayerIndex(playerIndex)
	return ((playerIndex - 1) % #players) + 1
end

function newRound()
	deck = hands.shuffledDeck()
	matchedCardsSet = nil
	isDraw = false
	sharedCards = {}
	local toRemove = {}

	for i, player in ipairs(players) do
		player.cards = {}
		player.bettingChips = 0
		player.flipped, player.folded = false, false
		player.allIn, player.dealer = false, false
		player.hasActed = false

		if (player.quit or player.chips < 1) then
			table.insert(toRemove, i)
		else
			for i = 1, 2 do
				table.insert(player.cards, table.remove(deck))
			end
			if (player.receiverId) then
				sendPlayerStateMessage(player)
			end
		end
	end

	for i = #toRemove, 1, -1 do
		table.remove(players, i)
	end

	table.insert(pots, createPot())

	dealerPlayer = wrapPlayerIndex(dealerPlayer + 1)
	players[dealerPlayer].dealer = true
	onBet(players[wrapPlayerIndex(dealerPlayer + 1)], smallBlind)
	onBet(players[wrapPlayerIndex(dealerPlayer + 2)], bigBlind)
	activePlayer = wrapPlayerIndex(dealerPlayer + 3)
end

function createPot()
	local pot = {chips = 0, drawChips = 0, bettingChips = 0, players = {}}
	for _, player in ipairs(players) do
		if (not player.allIn and not player.folded and not player.quit) then
			table.insert(pot.players, player)
		end
	end
	return pot
end

function endBettingRound()
	for _, player in ipairs(players) do
		pots[1].chips = pots[1].chips + (player.bettingChips or 0)
		player.bettingChips = 0
		player.hasActed = false
	end
	pots[1].bettingChips = 0
end

function flop()
	endBettingRound()
	for i = 1, 3 do
		sharedCards[i] = table.remove(deck)
	end
end

function turn()
	endBettingRound()
	for i = 4, 4 do
		sharedCards[i] = table.remove(deck)
	end
end

function river()
	endBettingRound()
	for i = 5, 5 do
		sharedCards[i] = table.remove(deck)
	end
end

function revealNext()
	timer = 0
	activePlayer = nil
	local found = false
	for i = 1, #players do
		local player = players[wrapPlayerIndex(dealerPlayer + i)]
		if (not player.flipped and not player.quit and not player.folded) then
			player.flipped = true
			found = true
			break
		end
	end
	if (not found) then
		changeState("finish")
	end
end

function onBet(player, amount)
	amount = math.min(amount, player.chips)
	player.chips = player.chips - amount
	player.hasActed = true
	player.bettingChips = player.bettingChips + amount
	pots[1].bettingChips = math.max(pots[1].bettingChips, player.bettingChips)
	if (player.chips < 1) then
		player.allIn = true
		player.flipped = true
		table.insert(pots, 1, createPot())
		print (string.format("Detected player all in, there are now %d pots", #pots))
	end
	return amount
end

function onFold(player)
	player.folded = true
	pots[1].chips = pots[1].chips + (player.bettingChips or 0)
	player.bettingChips = 0
	player.hasActed = false

	return checkGameEnded()
end

function checkGameEnded()
	local numActive = 0
	local foundPlayer = nil
	for _, player in ipairs(players) do
		if (not player.folded and not player.quit) then
			numActive = numActive + 1
			foundPlayer = player
		end
	end
	if (numActive < 2) then
		endBettingRound()
		for i = 1, #pots do
			local pot = table.remove(pots)
			foundPlayer.chips = foundPlayer.chips + pot.chips
		end
		timer = 0
		changeState("finish")
		return true
	end
	return false
end

function countPots()
	local count = 0
	for _, pot in ipairs(pots) do
		if (pot.chips > 0) then
			count = count + 1
		end
	end
	return count
end

function splitPot(pot, winningPIs)
	local sortPIs = function(pIA, pIB)
		return wrapPlayerIndex(pIA - dealerPlayer) < wrapPlayerIndex(pIB - dealerPlayer)
	end
	table.sort(winningPIs, sortPIs)
	local remainder = pot.chips % #winningPIs
	for i = 1, remainder do
		players[winningPIs[i]].chips = player[winningPIs[i]].chips + 1
	end
	pot.chips = pot.chips - remainder
	for _, pI in ipairs(winningPIs) do
		players[pI].chips = players[pI].chips + (pot.chips / #winningPIs)
	end
end

function finishPot(pot)
	local winningDescription, winningResult, winningMatchedCardsSet, winningPIs
	isDraw = false
	for pI, player in ipairs(pot.players) do
		if (not (player.quit or player.folded)) then
			player.flipped = true
			player.description = hands.describeHand(sharedCards, player.cards)
			player.result = hands.evaluateHand(player.description)
			player.matchedCardsSet = {}
			print (string.format("%s%s %s%s", player.cards[1].number, player.cards[1].suit, player.cards[2].number, player.cards[2].suit))
			print (pI, player.result.name, player.result.score)

			for i, card in ipairs(player.result.matchedCards or {}) do
				player.matchedCardsSet[card.number .. card.suit] = i <= player.result.primaryMatches
			end
			if (player.result.name == "Pair") then
				print (textutils.serialize(player.matchedCardsSet))
			end
			if (winningResult == nil or winningResult.score < player.result.score) then
				winningDescription = player.description
				winningResult = player.result
				winningMatchedCardsSet = hands.copyTable(player.matchedCardsSet)
				winningPIs = {pI}
				isDraw = false
			elseif (winningResult ~= nil and winningResult.score == player.result.score) then
				isDraw = true
				table.insert(winningPIs, pI)
				for key, value in pairs(player.matchedCardsSet) do
					winningMatchedCardsSet[key] = winningMatchedCardsSet[key] or value
				end
			end
		end
	end
	print(table.concat(winningPIs, ", "))
	print(string.format("Draw %s", tostring(isDraw)))

	if (#winningPIs == 1) then
		players[winningPIs[1]].chips = players[winningPIs[1]].chips + pot.chips
	else
		splitPot(pot, winningPIs)
	end
	for _, pI in ipairs(winningPIs) do
		local player = players[pI]
		if (player.receiverId) then
			sendPlayerStateMessage(player)
		end
	end
	pot.chips = 0

	description = winningDescription
	result = winningResult
	matchedCardsSet = winningMatchedCardsSet
end

function finishRound()
	totalPots = countPots()
	finishNextPot()
end

function finishNextPot()
	if (#pots > 0) then
		timer = 0
		for i = #pots, 1, -1 do
			local pot = table.remove(pots)
			if (pot.chips > 0) then
				currentPot = i
				print (string.format("Finishing pot %d/%d", i, totalPots))
				os.sleep(1)
				finishPot(pot)
				break
			end
		end
	elseif (timer > 100) then
		timer = 0
		changeState("preFlop")
	end
end

function findModem(wireless)
	for _, side in ipairs(peripheral.getNames()) do
		if (peripheral.getType(side) == "modem") then
			local modem = peripheral.wrap(side)
			if (modem.isWireless() == wireless) then
				return side
			end
		end
	end
	error(string.format("Must have a %s modem attached to use this script", wireless and "wireless" or "wired"))
end

function sendStartGameMessage(player)
	pokerProtocol.sendMessage(player.receiverId, {action = "start"})
end

function sendActivePlayerMessage(player)
	pokerProtocol.sendMessage(player.receiverId, {action = "activePlayer", currentBet=pots[1].bettingChips - player.bettingChips})
end

function sendPlayerStateMessage(player)
	pokerProtocol.sendMessage(player.receiverId, {action = "playerState", state = player})
end

function onPlayerJoined(senderId, message)
	print(string.format("%s joined the game: %s", senderId, textutils.serialize(message)))
	local playerIndex = 1 -- TODO: Decide index correctly
	players[playerIndex].receiverId = senderId
	players[playerIndex].chips = message.player.chips or 0
	playersByReceiverId[senderId] = players[playerIndex]
	sendStartGameMessage(players[playerIndex])
	sendPlayerStateMessage(players[playerIndex])
	if (activePlayer == playerIndex) then
		sendActivePlayerMessage(players[playerIndex])
	end
end

function onPlayerBet(senderId, message)
	local player = playersByReceiverId[senderId]
	if (not player) then
		print("Unknown player with receiverId %s", senderId)
		return
	end
	if (not message.betAmount) then
		print("WARNING: No bet amount given from %s", senderId)
		return
	end
	local actualAmount = onBet(player, message.betAmount)
	sendPlayerStateMessage(player)
	updateActivePlayer()
	nextState()
end

function onPlayerFold(senderId, message)
	local player = playersByReceiverId[senderId]
	if (not player) then
		print("Unknown player with receiverId %s", senderId)
		return
	end
	onFold(player)
	sendPlayerStateMessage(player)
	updateActivePlayer()
	nextState()
end

function onPlinthMessage(senderId, message)
	print(string.format("Received plinth message %s: %s", senderId, textutils.serialize(message)))
end

pokerProtocol.addActionHandler("join", onPlayerJoined)
pokerProtocol.addActionHandler("bet", onPlayerBet)
pokerProtocol.addActionHandler("fold", onPlayerFold)

local wirelessModemSide = findModem(true)
local wiredModelSide = findModem(false)

rednet.open(wirelessModemSide)
rednet.open(wiredModelSide)
rednet.host(pokerProtocol.POKER_PROTOCOL, "pokerServer")
rednet.host(PLINTH_PROTOCOL, "pokerServer")

changeState("preFlop")
-- changeState("flop")
-- changeState("turn")
-- changeState("river")

-- sharedCards[1] = {number="10", suit="H"}
-- sharedCards[2] = {number="7", suit="C"}
-- sharedCards[3] = {number="J", suit="H"}
-- sharedCards[4] = {number="10", suit="D"}
-- sharedCards[5] = {number="9", suit="D"}

-- players[1].cards = {{number="5", suit="H"}, {number="Q", suit="D"}}
-- players[2].cards = {{number="8", suit="H"}, {number="J", suit="C"}}
-- players[3].cards = {{number="K", suit="C"}, {number="7", suit="S"}}
-- players[4].cards = {{number="8", suit="S"}, {number="K", suit="H"}}
-- players[5].cards = {{number="4", suit="S"}, {number="2", suit="H"}}
-- players[6].cards = {{number="J", suit="S"}, {number="9", suit="H"}}
-- players[7].cards = {{number="Q", suit="C"}, {number="4", suit="D"}}
-- players[8].cards = {{number="A", suit="D"}, {number="A", suit="H"}}

-- changeState("revealing")

local frm = 1
while (true) do
	drawFrame(frm, gameState, sharedCards, players, activePlayer, result, matchedCardsSet, isDraw, pots, currentPot, totalPots)
	-- playerLocations[7].rot = playerLocations[7].rot + 0.1

	for _, player in ipairs(players) do
		lerpChips(player)
	end

	for _, pot in ipairs(pots) do
		lerpChips(pot)
	end

	if (gameState == "revealing") then
		if (timer > 20) then
			print(timer)
			revealNext()
		end
	elseif (gameState == "finish") then
		if (timer > 20) then
			finishNextPot()
		end
	end
	os.startTimer(0.05)
	while (true) do
		local result = table.pack(os.pullEvent())
		if (result[1] == "timer") then
			pokerProtocol.onTick()
			break
		elseif (result[1] == "monitor_touch") then
			nextState()
		elseif (result[1] == "modem_message") then
			print ("Ignoring modem message")
		elseif (result[1] == "rednet_message") then
			local _, senderId, message, protocol = table.unpack(result)
			if (protocol == pokerProtocol.POKER_PROTOCOL) then
				pokerProtocol.onPokerMessage(senderId, message)
			elseif (protocol == PLINTH_PROTOCOL) then
				onPlinthMessage(senderId, message)
			else
				print(string.format("Received message on unknown protocol %s", protocol))
			end
		else
			print(textutils.serialize(result))
		end
	end
	-- description = hands.describeHand(sharedCards, {})
	-- result = hands.evaluateHand(description)
	-- matchedCardsSet = {}
	-- for i, card in ipairs(result.matchedCards or {}) do
	-- 	matchedCardsSet[card.number .. card.suit] = i <= result.primaryMatches
	-- end
	frm = frm + 1
	timer = timer + 1
end
-- rotBuffer:drawSurfaceRotated(cardBackImgScaled, rotBuffer.width / 2, rotBuffer.height / 2, cardOrigin.x * 8, cardOrigin.y * 8, math.pi)
--screen:drawSurface(rotBuffer, math.floor(width / 2 - rotBufferOffset.x / 8), math.floor(-rotBufferOffset.y / 8) + 1, rotBuffer.width / 8, rotBuffer.height / 8, 0, 0)
--screen:drawSurface(cardBackImgScaled, 0, 0)
-- screen:drawSurface(cardBackImgScaled, 0, 0)
-- screen:drawSurface(rotBuffer, -rotBufferOffset.x, 0)
-- screen:output(monitor)