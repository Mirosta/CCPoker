local monitor = peripheral.find("monitor") or term
if (monitor.setTextScale) then
	monitor.setTextScale(0.5)
end
local width, height = monitor.getSize()
local surface = dofile('surface')
local screen = surface.create(width, height, colors.green)
local tenImg = surface.load(shell.dir() .. "/ten.nfp")
local arrowImg = surface.load(shell.dir() .. "/arrow.nfp")
local chipImg = surface.load(shell.dir() .. "/chip.nfp")
local dealerImg = surface.load(shell.dir() .. "/dealer.nfp")
local font = surface.loadFont(surface.load(shell.dir() .. "/font.bmp"))
local suitImages = {
	H = surface.load(shell.dir() .. "/heart.nfp"),
	D = surface.load(shell.dir() .. "/diamond.nfp"),
	C = surface.load(shell.dir() .. "/club.nfp"),
	S = surface.load(shell.dir() .. "/spade.nfp"),
}
local numberSizes = {}

for i = 1, 13 do
	local key = tostring(i)
	if (i == 1) then
		key = "A"
	elseif (i == 11) then
		key = "J"
	elseif (i == 12) then
		key = "Q"
	elseif (i == 13) then
		key = "K"
	end
	if (i == 10) then
		numberSizes[key] = vector.new(tenImg.width, tenImg.height + 1)
	else
		numberSizes[key] = vector.new(surface.getTextSize(key, font))
	end
end

local playerLocations = {
	{ pos = vector.new(25, 2), rot = math.pi, turnIndex = 1 },
	{ pos = vector.new(33, height - 1), rot = 0, turnIndex = 5 },
	{ pos = vector.new(67, 2), rot = math.pi, turnIndex = 2 },
	{ pos = vector.new(75, height - 1), rot = 0, turnIndex = 6 },
	{ pos = vector.new(111, 2), rot = math.pi, turnIndex = 3 },
	{ pos = vector.new(119, height - 1), rot = 0, turnIndex = 7 },
	{ pos = vector.new(width - 1, height / 2 + 1), rot = -math.pi / 2, turnIndex = 4 },
	{ pos = vector.new(2, height / 2), rot = math.pi / 2, turnIndex = 8 },
}

local cardLocation = { pos = vector.new(width / 2, height / 2) }

function loadImage(path)
	local image = surface.load(path)
	if (image == nil) then
		return nil
	end
	local scaled = surface.create(image.width * 8, image.height * 8)
	local rotBuffer = surface.create(math.floor(math.max(scaled.width, scaled.height) * 1.5), math.floor(math.max(scaled.width, scaled.height) * 1.5))
	local rotBufferOffset = (vector.new(rotBuffer.width, rotBuffer.height) - vector.new(scaled.width, scaled.height)) / 2
	local size = vector.new(image.width, image.height, 0)
	local origin = size / 2
	local lastRot = 0

	scaled:drawSurface(image, 0, 0, image.width * 8, image.height * 8, 0, 0, image.width, image.height)

	local imageObj = {
		image = image,
		width = image.width,
		height = image.height,
		size = size,
		origin = origin
	}

	local approxEqual = function(a, b, delta)
		return a - delta < b and a + delta > b
	end

	function imageObj:drawRotated(to, x, y, rot)
		if (rot == 0) then
			to:drawSurface(self.image, math.floor(x - self.origin.x), math.floor(y - self.origin.y))
		elseif (approxEqual(rot, -math.pi / 2, 0.0000001)) then
			drawSurfaceRotatedRightAngle(to, image, math.floor(x), math.floor(y), 3, self.origin)
		else
			if (rot - 0.00000001 > lastRot or rot + 0.00000001 < lastRot) then
				rotBuffer:clear()
				rotBuffer:drawSurfaceRotated(scaled, rotBuffer.width / 2, rotBuffer.height / 2, self.origin.x * 8, self.origin.y * 8, rot)
			end
			to:drawSurface(rotBuffer, math.floor(x - self.origin.x * 8) - math.floor(rotBufferOffset.x / 2) - 100, math.floor(y - self.origin.y * 8) - math.floor(rotBufferOffset.y / 2), rotBuffer.width, rotBuffer.height)
		end
		lastRot = rot
	end

	return imageObj
end

math.round = function(v)
	local floorV = math.floor(v)
	if (v - floorV >= 0.5) then
		return math.ceil(v)
	end
	return floorV
end

function drawSurfaceRotatedRightAngle(to, surf, x, y, rotIndex, offset)
	local target = vector.new(x, y)
	local sourceStart = vector.new()
	local sourceEnd = vector.new(surf.width - 1, surf.height - 1)
	local targetSize = vector.new(surf.width, surf.height)
	local delta = vector.new(1, 1)
	local rotatedOffset = offset
	local sourceToIndex = function(x, y)
		return (y * surf.width + x) * 3 + 1
	end

	if (rotIndex == 1) then
		sourceEnd = vector.new(surf.height - 1, surf.width - 1)
		targetSize = vector.new(surf.height, surf.width)
		rotatedOffset = vector.new(offset.y, offset.x)
		sourceToIndex = function(x, y)
			return ((surf.height - x - 1) * surf.width + y) * 3 + 1
		end
	elseif (rotIndex == 2) then
		sourceToIndex = function(x, y)
			return ((surf.height - y - 1) * surf.width + (surf.width - x - 1)) * 3 + 1
		end
	elseif (rotIndex == 3) then
		sourceEnd = vector.new(surf.height - 1, surf.width - 1)
		targetSize = vector.new(surf.height, surf.width)
		rotatedOffset = vector.new(offset.y, offset.x)
		sourceToIndex = function(x, y)
			return (x * surf.width + (surf.width - y - 1)) * 3 + 1
		end
	end

	target = vector.new(math.floor(target.x - rotatedOffset.x), math.floor(target.y - rotatedOffset.y))
	for y = sourceStart.y, sourceEnd.y, delta.y do
		for x = sourceStart.x, sourceEnd.x, delta.x do
			color = surf.buffer[sourceToIndex(x, y)]
			to:drawPixel(target.x, target.y, color)
			target.x = target.x + 1
		end
		target.x = target.x - targetSize.x
		target.y = target.y + 1
	end
end

local cardBackImg = loadImage(shell.dir() .. "/card_back_l.nfp")
local playerCardBuffer = surface.create(cardBackImg.width, cardBackImg.height)
local chipBuffer = surface.create(chipImg.width, chipImg.height)

function drawChips(to, chipStr, pos, rotIndex, up, right)
	up = up or vector.new(0, -1)
	right = right or vector.new(1, 0)

	local chipsStartPos = pos - right * (5 * string.len(chipStr) + 3)
	local chipsPos = chipsStartPos
	local chipPosDelta = right * 5
	for i = 1, string.len(chipStr) do
		local char = string.sub(chipStr, i, i)
		drawSurfaceRotatedRightAngle(to, chipImg, chipsPos.x, chipsPos.y, 0, vector.new(chipImg.width / 2, chipImg.height / 2))
		chipsPos = chipsPos + chipPosDelta
		if (char == "1") then
			chipsPos = chipsPos - right
		end
	end
	chipsPos = chipsStartPos
	for i = 1, string.len(chipStr) do
		local char = string.sub(chipStr, i, i)
		chipBuffer:clear()
		chipBuffer:drawText(char .. "", font, 1, 1, colors.black)
		drawSurfaceRotatedRightAngle(to, chipBuffer, chipsPos.x, chipsPos.y, rotIndex, vector.new(chipImg.width / 2, chipImg.height / 2))
		chipsPos = chipsPos + chipPosDelta
		if (char == "1") then
			chipsPos = chipsPos - right
		end
	end
end

function drawPlayerCards(player, matchedCardsSet, isActive, frm)
	if player.quit then
		return
	end

	local loc = playerLocations[player.location]
	local rotIndex = math.round(loc.rot * 2 / math.pi) % 4
	local offset = vector.new()
	local rotatedDelta = vector.new(math.cos(loc.rot), math.sin(loc.rot))
	local up = vector.new(rotatedDelta.y, -rotatedDelta.x)
	offset = offset - rotatedDelta * (cardBackImg.origin.x)
	
	if (player.dealer and not player.flipped) then
		local dealerPos = loc.pos + up * 11 + rotatedDelta * 8
		drawSurfaceRotatedRightAngle(screen, dealerImg, dealerPos.x, dealerPos.y, rotIndex, vector.new(dealerImg.width / 2, dealerImg.height / 2))
	end

	if (player.drawChips or player.chips ~= nil) then
		drawChips(screen, tostring(player.drawChips or player.chips), loc.pos + up * 2 + offset, rotIndex, up, rotatedDelta)
	end

	if (player.folded) then
		return
	end

	if (player.bettingChips ~= nil and player.bettingChips > 0) then
		local chipStr = tostring(player.bettingChips)
		local betChipPos = loc.pos + up * 11 + rotatedDelta * string.len(chipStr) * 5
		if (player.flipped) then
			betChipPos = betChipPos + up * 5
		end
		drawChips(screen, chipStr, betChipPos, rotIndex, up, rotatedDelta)
	end

	if (isActive) then
		local arrowPos = loc.pos + up * (1 + math.sin(frm / 2.5) * 3 + cardBackImg.height)
		if (loc.rot < math.pi / 4) then
			arrowPos = arrowPos + rotatedDelta
		end
		drawSurfaceRotatedRightAngle(screen, arrowImg, arrowPos.x, arrowPos.y, rotIndex, vector.new(arrowImg.width / 2, arrowImg.height / 2))
	end

	if (player.flipped) then
		offset = offset + up * 5
	end

	for _, card in ipairs(player.cards) do
		local pos = loc.pos + offset
		local matchingOffset = vector.new()
		if (matchedCardsSet ~= nil and card.number and card.suit) then
			if(matchedCardsSet[card.number .. card.suit]) then
				matchingOffset = up * 2
			else
				matchingOffset = -up
			end
		end
		pos = pos + matchingOffset
		local topLeft = pos - cardBackImg.origin
		playerCardBuffer:clear()

		offset = offset + rotatedDelta * (1 + cardBackImg.size.x)
		if (player.flipped) then
			drawCardBackground(playerCardBuffer, vector.new(), cardBackImg.size, (matchedCardsSet and ((matchedCardsSet[card.number .. card.suit] and colors.orange) or ((matchedCardsSet[card.number .. card.suit] == false) and colors.yellow))) or colors.gray)
			playerCardBuffer:drawSurface(suitImages[card.suit], 2, 1)
			drawCardText(playerCardBuffer, card.number, vector.new(), cardBackImg.size + vector.new(0, 1))
		else
			playerCardBuffer:drawSurface(cardBackImg.image, 0, 0)
		end
		drawSurfaceRotatedRightAngle(screen, playerCardBuffer, pos.x, pos.y, rotIndex, cardBackImg.origin)
	end
end

function drawPlayersCards(players, matchedCardsSet, activePlayer, frm)
	for i, player in ipairs(players) do
		drawPlayerCards(player, matchedCardsSet, i == activePlayer, frm)
		-- screen:drawPixel(math.floor(loc.pos.x), math.floor(loc.pos.y), colors.red)
		-- screen:drawPixel(math.floor(loc.pos.x + up.x), math.floor(loc.pos.y + up.y), colors.blue)
	end
end

function drawCardText(to, number, pos, size)
	local textSize = numberSizes[number]
	local x = math.floor(pos.x + (size.x - textSize.x) / 2)
	local y = math.floor(pos.y + size.y - 1 - textSize.y)
	if (number == "10") then
		drawMask(to, tenImg, x, y, colors.black)
	else
		to:drawText(number, font, x, y, colors.black)
	end
end

function drawCardBackground(to, pos, size, lineColor)
	local bottomRight = pos + size - vector.new(1,1)
	to:fillRect(math.floor(pos.x + 1), math.floor(pos.y + 1), math.floor(size.x - 2), math.floor(size.y - 2), colors.white)

	to:drawLine(math.floor(pos.x + 1), math.floor(pos.y), math.floor(bottomRight.x - 1), math.floor(pos.y), lineColor)
	to:drawLine(math.floor(bottomRight.x), math.floor(pos.y + 1), math.floor(bottomRight.x), math.floor(bottomRight.y - 1), lineColor)
	to:drawLine(math.floor(pos.x + 1), math.floor(bottomRight.y), math.floor(bottomRight.x - 1), math.floor(bottomRight.y), lineColor)
	to:drawLine(math.floor(pos.x), math.floor(pos.y + 1), math.floor(pos.x), math.floor(bottomRight.y - 1), lineColor)
end

function drawSharedCard(to, pos, size, number, suit, matching)
	drawCardBackground(to, pos, size, matching and colors.orange or colors.gray)
	
	to:drawSurface(suitImages[suit], math.floor(pos.x + (size.x - suitImages[suit].width) - 2), math.floor(pos.y + 2))

	drawCardText(to, number, pos, size)
end

function drawSharedCards(to, center, cards, matchedCardsSet, maxCards)
	local cardSize = vector.new(12, 17)
	local offset = vector.new(-cardSize.x * maxCards * 0.5 - 2, -cardSize.y / 2)
	local delta = vector.new(cardSize.x + 1)

	for _, card in ipairs(cards) do
		local matchingOffset = vector.new()
		local matched = false
		if (matchedCardsSet ~= nil) then
			if(matchedCardsSet[card.number .. card.suit]) then
				matchingOffset = vector.new(0, -3)
				matched = true
			else
				matchingOffset = vector.new(0, 3)
			end
		end
		drawSharedCard(to, center + offset + matchingOffset, cardSize, card.number, card.suit, matched)
		offset = offset + delta
	end
end

function drawMask(to, mask, x, y, b)
	local cx, cy = x + to.ox, y + to.oy
	local ox, idx = cx

	for i = 0, mask.width - 1 do
		for j = 0, mask.height - 1 do
			x, y = cx + i, cy + j
			if (mask.buffer[(j * mask.width + i) * 3 + 1]) then
				if x >= to.cx and x < to.cx + to.cwidth and y >= to.cy and y < to.cy + to.cheight then
					idx = (y * to.width + x) * 3
					if b or to.overwrite then
						to.buffer[idx + 1] = b
					end
				end
			end
		end
	end
end

function drawBorderedText(to, text, font, x, y, color, borderColor)
	to:drawText(text, font, x - 1, y - 1, borderColor)
	to:drawText(text, font, x + 1, y + 1, borderColor)
	to:drawText(text, font, x + 1, y - 1, borderColor)
	to:drawText(text, font, x - 1, y + 1, borderColor)
	to:drawText(text, font, x - 1, y, borderColor)
	to:drawText(text, font, x + 1, y, borderColor)
	to:drawText(text, font, x, y - 1, borderColor)
	to:drawText(text, font, x, y + 1, borderColor)
	to:drawText(text, font, x, y, color)
end

function drawFrame(frm, gameState, sharedCards, players, activePlayer, result, matchedCardsSet, isDraw, pots, currentPot, totalPots)
	screen:clear(colors.green)
	
	drawSharedCards(screen, cardLocation.pos, sharedCards, matchedCardsSet, 5)

	local potTotal = 0
	for _, pot in ipairs(pots) do
		potTotal = potTotal + (pot.drawChips or pot.chips)
	end
	if (potTotal > 0) then
		drawChips(screen, potTotal, vector.new(width / 2, height / 2 - 14), rotIndex)
	end

	drawPlayersCards(players, matchedCardsSet, activePlayer, frm)
	if (gameState == "finish" and totalPots > 0) then
		if (currentPot ~= totalPots and totalPots > 1) then
			local currentPotStr = "Side Pot"
			if (totalPots > 2) then
				currentPotStr = currentPotStr .. string.format(" %d/%d", totalPots - currentPot, totalPots - 1)
			end
			local currentPotSize = vector.new(surface.getTextSize(currentPotStr, font))
			drawBorderedText(screen, currentPotStr, font, math.floor((width - currentPotSize.x) / 2), math.floor(height / 2 - 14), colors.black, colors.lightGray)
		end
		local name = result.name
		if (isDraw) then
			name = "Draw - " .. name
		end
		local resultNameSize = vector.new(surface.getTextSize(name, font))
		drawBorderedText(screen, name, font, math.floor((width - resultNameSize.x) / 2), math.floor(height / 2 + 11), colors.black, colors.lightGray)
	end

	screen:output(monitor)
end

return {
	screen = screen,
	monitor = monitor
}
