local royalFlush = {name = "Royal Flush", baseScore = 49500000, primaryMatches = 5}
local straightFlush = {name = "Straight Flush", baseScore = 44000000, primaryMatches = 5}
local fourOfAKind = {name = "Four of a Kind", baseScore = 38500000, primaryMatches = 4}
local fullHouse = {name = "Full House", baseScore = 33000000, primaryMatches = 5}
local flush = {name = "Flush", baseScore = 27500000, primaryMatches = 5}
local straight = {name = "Straight", baseScore = 22000000, primaryMatches = 5}
local threeOfAKind = {name = "Three of a Kind", baseScore = 16500000, primaryMatches = 3}
local twoPair = {name = "Two Pair", baseScore = 11000000, primaryMatches = 4}
local pair = {name = "Pair", baseScore = 5500000, primaryMatches = 2}
local highCard = {name = "High Card", baseScore = 0, primaryMatches = 1}

local handRankings = {
	royalFlush,
	straightFlush,
	fourOfAKind,
	fullHouse,
	flush,
	straight,
	threeOfAKind,
	twoPair,
	pair,
	highCard,
}

local specialCardValues = {
	J = 11,
	Q = 12,
	K = 13,
	A = 14
}

local valueSpecialCards = {
	[1] = "A",
	[11] = "J",
	[12] = "Q",
	[13] = "K",
	[14] = "A"
}

local suits = {"H", "D", "C", "S"}

local getValue = function(number)
	return specialCardValues[number] or tonumber(number)
end

local getNumber = function(value)
	return valueSpecialCards[value] or tostring(value)
end

local compareCards = function(cardA, cardB)
	if (cardA == nil) then
		return false
	end
	if (cardB == nil) then
		return true
	end
	local numberValueA, numberValueB = getValue(cardA.number), getValue(cardB.number)
	if (numberValueA == numberValueB) then
		return cardA.suit < cardB.suit
	end
	return numberValueA < numberValueB
end

local reverseOrder = function(comparator)
	return function(...)
		return not comparator(...)
	end
end

local compareFirst = function(comparator)
	return function(...)
		local items = table.pack(...)
		for i = 1, #items do
			if (items[i] ~= nil and #items[i] > 0) then
				items[i] = items[i][1]
			else
				items[i] = nil
			end
		end
		return comparator(table.unpack(items))
	end
end

local compareArray = function(comparator)
	return function(a, b)
		for i = 1, math.min(#a, #b) do
			if (comparator(a[i], b[i])) then
				return true
			elseif (comparator(b[i], a[i])) then
				return false
			end
		end
		return #a < #b
	end
end

local doGroup = function(description, cards)
	for _, card in ipairs(cards) do
		table.insert(description.allCards, card)

		if (description.bySuit[card.suit] == nil) then
			description.bySuit[card.suit] = {}
		end
		table.insert(description.bySuit[card.suit], card)

		if (description.byNumber[card.number] == nil) then
			description.byNumber[card.number] = {}
		end
		table.insert(description.byNumber[card.number], card)
	end
end

local findTuples = function(description)
	for number, cards in pairs(description.byNumber) do
		if (#cards == 2) then
			table.insert(description.pairs, cards)
		elseif (#cards == 3) then
			table.insert(description.triples, cards)
		elseif (#cards == 4) then
			table.insert(description.quadruples, cards)
		end
	end
end

local copyTable = function(t)
	local copy = {}
	for k,v in pairs(t) do
		copy[k] = v
	end
	return copy
end

local permuteOne = function(permutations, value, copy)
	if (#permutations < 1) then
		return {{value}}
	end
	local permutation = {}
	if (copy) then
		permutation = copyTable(permutations)
		for i, values in ipairs(permutation) do
			permutation[i] = copyTable(values)
		end
	else
		permutation = permutations
	end

	for _, values in ipairs(permutation) do
		table.insert(values, value)
	end

	return permutation
end

local permute = function(permutationList)
	local permutations = {}
	for _, values in ipairs(permutationList) do
		local toInsert = {}
		for i, value in ipairs(values) do
			local copy = i < #values or #permutations < 1
			local permutation = permuteOne(permutations, value, copy)
			if (copy) then
				table.insert(toInsert, permutation)
			end
		end
		for _, permutation in ipairs(toInsert) do
			for _, values in ipairs(permutation) do
				table.insert(permutations, values)
			end
		end
	end
	return permutations
end

local findRuns = function(description)
	local currentRun = {}
	for i = 14, 1, -1 do
		local number = getNumber(i)
		if (description.byNumber[number] ~= nil and #description.byNumber[number] > 0) then
			table.insert(currentRun, description.byNumber[number])
			if (#currentRun == 5) then
				for _, run in ipairs(permute(currentRun)) do
					table.insert(description.runs, run)
				end
				table.remove(currentRun, 1)
			end
		else
			currentRun = {}
		end
	end
end

local sortDescription = function(description)
	table.sort(description.allCards, reverseOrder(compareCards))
	for suit, cards in pairs(description.bySuit) do
		table.sort(cards, reverseOrder(compareCards))
	end
	table.sort(description.quadruples, reverseOrder(compareFirst(compareCards)))
	table.sort(description.triples, reverseOrder(compareFirst(compareCards)))
	table.sort(description.pairs, reverseOrder(compareFirst(compareCards)))
	table.sort(description.runs, reverseOrder(compareArray(compareCards)))
end

local describeHand = function(sharedCards, playerCards)
	local description = {allCards = {}, bySuit = {}, byNumber = {}, quadruples = {}, triples = {}, pairs = {}, runs = {}}
	doGroup(description, sharedCards)
	doGroup(description, playerCards)
	findTuples(description)
	findRuns(description)
	sortDescription(description)
	return description
end

local allSuitsMatch = function(cards)
	local currentSuit = nil
	for _, card in ipairs(cards) do
		if (currentSuit ~= nil and currentSuit ~= card.suit) then
			return false
		end
		currentSuit = card.suit
	end
	return true
end

local calculateRelativeScore = function( ... )
	local relevantCards = table.pack(...)
	local total = 0
	local mult = 14 ^ (#relevantCards - 1)
	for i, card in ipairs(relevantCards) do
		total = total + (getValue(card.number)-1) * mult
		mult = mult / 14
	end
	return total
end

local takeUnmatchedCards = function(description, matchedCards, n)
	local matchedCardsSet = {}
	local cardsTaken = {}
	if (n < 1) then
		return cardsTaken
	end
	for _, card in ipairs(matchedCards) do
		matchedCardsSet[card.number .. card.suit] = true
	end
	for _, card in pairs(description.allCards) do
		if (not matchedCardsSet[card.number .. card.suit]) then
			table.insert(cardsTaken, card)
			if (#cardsTaken >= n) then
				break
			end
		end
	end
	return cardsTaken
end

local concatToTable = function(to, from)
	for _, v in ipairs(from) do
		table.insert(to, v)
	end
	return to
end

local evaluateTuple = function(description, tupleFieldName)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description[tupleFieldName] < 1) then
		return result
	end
	local matchedCards = copyTable(description[tupleFieldName][1])
	local otherCards = takeUnmatchedCards(description, matchedCards, 5 - #matchedCards)
	local scoredCards = {matchedCards[1]}
	concatToTable(scoredCards, otherCards)
	concatToTable(matchedCards, otherCards)
	result.matched = true
	result.relativeScore = calculateRelativeScore(table.unpack(scoredCards))
	result.matchedCards = matchedCards
	return result
end

royalFlush.evaluate = function(description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description.runs < 1) then
		return result
	end
	local potentialRun = description.runs[1]
	if (potentialRun[1].number ~= "A") then
		return result
	end
	if (not allSuitsMatch(potentialRun)) then
		return result
	end
	result.matched = true
	result.matchedCards = potentialRun
	return result
end

straightFlush.evaluate = function(description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description.runs < 1) then
		return result
	end
	for _, run in ipairs(description.runs) do
		if (allSuitsMatch(run)) then
			result.matched = true
			result.relativeScore = calculateRelativeScore(run[1])
			result.matchedCards = run
			return result
		end
	end
	return result
end

fourOfAKind.evaluate = function(description)
	return evaluateTuple(description, "quadruples")
end

fullHouse.evaluate = function (description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description.triples < 1) then
		return result
	end
	if (#description.pairs < 1) then
		return result
	end
	local triple = description.triples[1]
	local pair = description.pairs[1]
	local matchedCards = {}

	concatToTable(matchedCards, triple)
	concatToTable(matchedCards, pair)

	result.matched = true
	result.relativeScore = calculateRelativeScore(triple[1], pair[1])
	result.matchedCards = matchedCards
	return result
end

flush.evaluate = function(description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	local bestFlush = nil
	for _, cards in pairs(description.bySuit) do
		if (#cards > 4 and (bestFlush == nil or compareCards(bestFlush[1], cards[1]))) then
			bestFlush = cards
		end
	end
	if (bestFlush == nil) then
		return result
	end
	local matchedCards = {}
	concatToTable(matchedCards, bestFlush)

	result.matched = true
	result.relativeScore = calculateRelativeScore(bestFlush[1])
	result.matchedCards = matchedCards
	return result
end

straight.evaluate = function(description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description.runs < 1) then
		return result
	end
	result.matched = true
	result.relativeScore = calculateRelativeScore(description.runs[1][1])
	result.matchedCards = description.runs[1]
	return result
end

threeOfAKind.evaluate = function(description)
	return evaluateTuple(description, "triples")
end

twoPair.evaluate = function(description)
	local result = {matched = false, relativeScore = 0, matchedCards = {}}
	if (#description.pairs < 2) then
		return result
	end
	local matchedCards = copyTable(description.pairs[1])
	concatToTable(matchedCards, description.pairs[2])
	local otherCard = takeUnmatchedCards(description, matchedCards, 1)[1]
	table.insert(matchedCards, otherCard)

	result.matched = true
	result.relativeScore = calculateRelativeScore(matchedCards[1], matchedCards[3], otherCard)
	result.matchedCards = matchedCards
	return result
end

pair.evaluate = function(description)
	return evaluateTuple(description, "pairs")
end

highCard.evaluate = function(description)
	local result = {matched = true, relativeScore = 0, matchedCards = {}}
	result.matchedCards = takeUnmatchedCards(description, {}, 5)
	result.relativeScore = calculateRelativeScore(table.unpack(result.matchedCards))
	return result
end

local evaluateHand = function(description)
	for _, handType in ipairs(handRankings) do
		local result = handType.evaluate(description)
		if (result.matched) then
			return {name = handType.name, score = handType.baseScore + result.relativeScore, matchedCards = result.matchedCards, primaryMatches = handType.primaryMatches}
		end
	end
	return nil
end

local createDeck = function()
	local deck = {}
	for _, suit in ipairs(suits) do
		for i = 1, 13 do
			table.insert(deck, {number = getNumber(i), suit = suit})
		end
	end
	return deck
end

local shuffledDeck = function()
	local deck = createDeck()
	local length, temp = #deck, nil
	for i = 1, length do
		j = math.random(length)
		temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp
	end
	return deck
end

local hands = {}
hands.compareCards = compareCards
hands.compareFirst = compareFirst
hands.reverseOrder = reverseOrder
hands.permute = permute
hands.permuteOne = permuteOne
hands.copyTable = copyTable
hands.allSuitsMatch = allSuitsMatch
hands.calculateRelativeScore = calculateRelativeScore
hands.rankings = handRankings
hands.describeHand = describeHand
hands.evaluateHand = evaluateHand
hands.shuffledDeck = shuffledDeck
return hands