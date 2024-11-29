--!native
--!optimize 2
--!strict

type EntityId = number
type ComponentId = number
type Generation = number

type Edge = {
	from: Archetype,
	to: Archetype,
	next: Edge?,
	prev: Edge?,
	componentId: ComponentId,
	transition: TransitionInfo,
}

export type Archetype = {
	bitmasks: { number },
	entities: { EntityId },
	entityRow: { [EntityId]: number },
	componentData: { [ComponentId]: { [EntityId]: any } },
	entityCount: number,
	dirtyFlags: number,
	addEdges: { [ComponentId]: Edge },
	removeEdges: { [ComponentId]: Edge },
	edgeRefs: {
		next: Edge?,
		prev: Edge?,
	},
}

type TransitionKey = number

type TransitionInfo = {
	source: Archetype,
	destination: Archetype,
	sharedComponents: { ComponentId },
	addedComponents: { ComponentId },
	removedComponents: { ComponentId },
	frequency: number,
}

type ArchetypeEdgeCache = {
	[TransitionKey]: {
		to: Archetype,
		transition: TransitionInfo,
	},
}

type QueryCache = {
	archetypes: { Archetype },
	includeBitmasks: { number },
	excludeBitmasks: { number },
	components: { ComponentId },
}

type Signal<T...> = {
	_head: Connection<T...>?,
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> (),
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Connection<T...> = {
	Connected: boolean,
	_signal: Signal<T...>,
	_fn: (T...) -> (),
	_next: Connection<T...>?,
	_prev: Connection<T...>?,
	Disconnect: (self: Connection<T...>) -> (),
	Reconnect: (self: Connection<T...>) -> (),
}

local freeThreads: { thread } = {}

local function RunCallback<T...>(callback: (T...) -> (), thread, ...: T...): ()
	callback(...)
	table.insert(freeThreads, thread)
end

local function Yielder(): ()
	while true do
		RunCallback(coroutine.yield())
	end
end

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect<T...>(self: Connection<T...>): ()
	if not self.Connected then
		return
	end

	self.Connected = false
	local next = self._next
	local prev = self._prev

	if next then
		next._prev = prev
	end
	if prev then
		prev._next = next
	end

	if self._signal._head == self then
		self._signal._head = next
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.Connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection<T...>
	local head = self._head
	local cn = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
		_next = head,
		_prev = nil,
	}, Connection) :: any

	if head then
		head._prev = cn
	end
	self._head = cn

	return cn :: any
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...): ()
	local cn = self._head
	while cn do
		if cn.Connected then
			local thread
			if #freeThreads > 0 then
				thread = freeThreads[#freeThreads]
				freeThreads[#freeThreads] = nil
			else
				thread = coroutine.create(Yielder)
				coroutine.resume(thread)
			end
			coroutine.resume(thread, cn._fn, thread, ...)
		end
		cn = cn._next
	end
end

function Signal.Wait<T...>(self: Signal<T...>): T...
	local thread = coroutine.running()
	local cn
	cn = self:Connect(function(...): ()
		cn:Disconnect()
		local success, err = coroutine.resume(thread, ...)
		if not success then
			error(string.format("Wait callback error: %s", err), 2)
		end
	end)
	return coroutine.yield()
end

function Signal.Once<T...>(self: Signal<T...>, fn: (...any) -> ()): Connection<T...>
	local cn
	cn = self:Connect(function(...): ()
		cn:Disconnect()
		fn(...)
	end)
	return cn
end

function Signal.DisconnectAll<T...>(self: Signal<T...>)
	local cn = self._head
	while cn do
		cn:Disconnect()
		cn = cn._next
	end
end

function Signal.Destroy<T...>(self: Signal<T...>)
	self:DisconnectAll()
	setmetatable(self, nil)
end

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_head = nil,
	}, Signal) :: any
end

local CONFIG = _G.__YUMINA_CONFIG or { DEBUG_MODE = false }
local DEBUG_MODE = CONFIG.DEBUG_MODE or false

local ENTITY_MASK: number = 0x00FFFFFF
local GENERATION_SHIFT: number = 0x18
local MAX_GENERATION: number = 0xFF

local BITS_PER_MASK: number = 32
local NUM_BITMASKS: number = 3

local DIRTY_ADDITION: number = 0x1
local DIRTY_REMOVAL: number = 0x2
local DIRTY_UPDATE: number = 0x4

local RELATIONSHIP_COMPONENT: number = 0x1000000

local ERROR_TYPE = {
	INVALID_ENTITY = "INVALID_ENTITY",
	INVALID_COMPONENT = "INVALID_COMPONENT",
	INVALID_OPERATION = "INVALID_OPERATION",
	ARCHETYPE_ERROR = "ARCHETYPE_ERROR",
	QUERY_ERROR = "QUERY_ERROR",
	TRANSITION_ERROR = "TRANSITION_ERROR",
	MEMORY_ERROR = "MEMORY_ERROR",
}

local band, bor, bnot, lshift, rshift, countrz =
	bit32.band, bit32.bor, bit32.bnot, bit32.lshift, bit32.rshift, bit32.countrz

local function ThrowError(category: string, message: string, context: string?): never?
	if not DEBUG_MODE then
		return
	end
	return error(
		string.format("[Yumina:%s] %s %s", category, message, context and ("(" .. tostring(context) .. ")") or ""),
		2
	)
end

local function AssertArgument(condition: boolean, errorType: string, message: string): never?
	if not DEBUG_MODE then
		return
	end
	if not condition then
		return error(string.format("[Yumina:%s] %s", errorType, message), 2)
	end
	return
end

local function ValidateComponentId(componentId: number): ()
	local baseComponent = band(componentId, bnot(RELATIONSHIP_COMPONENT))
	AssertArgument(typeof(componentId) == "number", ERROR_TYPE.INVALID_COMPONENT, "Component ID must be a number")
	AssertArgument(
		baseComponent > 0 and baseComponent <= BITS_PER_MASK * NUM_BITMASKS,
		ERROR_TYPE.INVALID_COMPONENT,
		string.format("Component ID must be between 1 and %d", BITS_PER_MASK * NUM_BITMASKS)
	)
end

local function ValidateEntity(self: Yumina, entityId: EntityId): number
	AssertArgument(typeof(entityId) == "number", ERROR_TYPE.INVALID_ENTITY, "Entity ID must be a number")

	local id = band(entityId, ENTITY_MASK)
	local generation = rshift(entityId, GENERATION_SHIFT)
	local currentGen = self._generations[id]

	if not currentGen then
		ThrowError(ERROR_TYPE.INVALID_ENTITY, "Entity does not exist", tostring(id))
	end
	if currentGen ~= generation then
		ThrowError(
			ERROR_TYPE.INVALID_ENTITY,
			string.format("Invalid generation (expected %d, got %d)", currentGen, generation),
			tostring(id)
		)
	end
	return id
end

local function GetComponentBits(componentId: number): (number, number)
	return rshift(componentId - 1, 5) + 1, -- // maskIndex
		band(componentId - 1, 0x1F) -- // bitPosition
end

local function GetArchetypeKey(bitmasks: { number }): number
	return bor(
		band(bitmasks[1], 0x1FFFFF),
		lshift(band(bitmasks[2], 0x1FFFFF), 21),
		lshift(band(bitmasks[3], 0x3FFFFF), 42)
	)
end

local function GetTransitionKey(sourceBitmasks: { number }, destBitmasks: { number }): number
	return bor(
		band(sourceBitmasks[1], 0x3FF),
		lshift(band(sourceBitmasks[2], 0x3FF), 10),
		lshift(band(sourceBitmasks[3], 0x3FF), 20),
		lshift(band(destBitmasks[1], 0x3FF), 30),
		lshift(band(destBitmasks[2], 0x3FF), 40),
		lshift(band(destBitmasks[3], 0x3FF), 50)
	)
end

local function GetQueryKey(includeBitmasks: { number }, excludeBitmasks: { number }): number
	return bor(
		band(includeBitmasks[1], 0x3FF),
		lshift(band(includeBitmasks[2], 0x3FF), 10),
		lshift(band(includeBitmasks[3], 0x3FF), 20),
		lshift(band(excludeBitmasks[1], 0x3FF), 30),
		lshift(band(excludeBitmasks[2], 0x3FF), 40),
		lshift(band(excludeBitmasks[3], 0x3FF), 50)
	)
end

--[[
    @class Yumina
    @description Core ECS implementation with archetype-based storage
]]
local Yumina = {}
Yumina.__index = Yumina

export type Yumina = typeof(setmetatable({
	_archetypeIndex = {} :: { [number]: Archetype },
	_entityIndex = {} :: { [EntityId]: Archetype },
	_denseEntities = {},
	_sparseToLive = {},
	_aliveCount = 0,
	_generations = {} :: { [EntityId]: Generation },
	_nextId = 1 :: EntityId,
	_edgeCache = {} :: ArchetypeEdgeCache,
	_relations = {} :: { [EntityId]: { [ComponentId]: { target: EntityId, data: any? } } },
	_queryCache = {} :: { [number]: QueryViewer },
	_reverseRelations = {} :: { [EntityId]: { [ComponentId]: { EntityId } } },

	OnSet = Signal.new() :: Signal<EntityId, ComponentId, any>,
	OnTransition = Signal.new() :: Signal<EntityId, Archetype, Archetype>,
	OnCached = Signal.new() :: Signal<"Transition" | "Query", number>,
	OnCleanup = Signal.new() :: Signal<()>,
}, Yumina))

--[[
    @function Yumina.new
    @description Creates a new ECS instance
    @return Yumina New ECS instance
]]
function Yumina.new(): Yumina
	local self = setmetatable({}, Yumina)
	self._archetypeIndex = {}
	self._entityIndex = {}
	self._denseEntities = {}
	self._sparseToLive = {}
	self._aliveCount = 0
	self._generations = {}
	self._nextId = 1
	self._edgeCache = {}
	self._queryCache = {}
	self._relations = {}
	self._reverseRelations = {}

	self.OnSet = Signal.new() :: Signal<EntityId, ComponentId, any>
	self.OnTransition = Signal.new() :: Signal<EntityId, Archetype, Archetype>
	self.OnCached = Signal.new() :: Signal<"Transition" | "Query", number>
	self.OnCleanup = Signal.new() :: Signal<()>
	return self
end

--[[
    @function Yumina.Entity
    @description Creates a new entity with a unique ID and generation
    @return EntityId Encoded entity ID containing both ID and generation
]]
function Yumina.Entity(self: Yumina): EntityId
	local entityId: EntityId
	local generation: Generation

	if self._aliveCount < #self._denseEntities then
		entityId = self._denseEntities[self._aliveCount + 1]
		generation = (self._generations[entityId] or 0) + 1
		if generation > MAX_GENERATION then
			generation = 0
		end
	else
		entityId = self._nextId
		self._nextId += 1
		generation = 0
		table.insert(self._denseEntities, entityId)
	end

	self._aliveCount += 1
	self._sparseToLive[entityId] = self._aliveCount
	self._generations[entityId] = generation
	return bor(lshift(generation, GENERATION_SHIFT), entityId)
end

local function __DespawnSingle(self: Yumina, entityId: number): ()
	local liveIndex = self._sparseToLive[entityId]
	if not liveIndex then
		return
	end

	local lastLiveEntity = self._denseEntities[self._aliveCount]
	if lastLiveEntity ~= entityId then
		self._denseEntities[liveIndex] = lastLiveEntity
		self._sparseToLive[lastLiveEntity] = liveIndex
		self._denseEntities[self._aliveCount] = entityId
	end

	self._aliveCount -= 1
	self._sparseToLive[entityId] = nil

	local archetype = self._entityIndex[entityId]
	if archetype then
		local row = archetype.entityRow[entityId]
		local lastRow = archetype.entityCount

		if row and lastRow > 0 then
			if row == lastRow then
				for _, componentArray in archetype.componentData do
					componentArray[row] = nil
				end
			else
				local lastEntity = archetype.entities[lastRow]
				if lastEntity then
					archetype.entities[row] = lastEntity
					archetype.entityRow[lastEntity] = row
					for _, componentArray in archetype.componentData do
						componentArray[row] = componentArray[lastRow]
						componentArray[lastRow] = nil
					end
				end
			end
			archetype.entities[lastRow] = nil
		end

		archetype.entityCount -= 1
		archetype.entityRow[entityId] = nil

		if archetype.entityCount == 0 then
			self._archetypeIndex[GetArchetypeKey(archetype.bitmasks)] = nil
		end

		archetype.dirtyFlags = bor(archetype.dirtyFlags, DIRTY_REMOVAL)
		self._entityIndex[entityId] = nil
		self._generations[entityId] = band(self._generations[entityId] + 1, MAX_GENERATION)
	end
end

--[[
    @function Yumina.Despawn
    @description Removes an entity and all its components
    @param encodedId EntityId The encoded entity ID to despawn
]]
function Yumina.Despawn(self: Yumina, encodedId: EntityId): ()
	local entityId = band(encodedId, ENTITY_MASK)
	local generation = rshift(encodedId, GENERATION_SHIFT)
	if self._generations[entityId] ~= generation then
		return
	end

	if not self._relations[entityId] then
		__DespawnSingle(self, entityId)
		return
	end

	local toProcess = table.create(32)
	local processed = { [entityId] = true }
	local processIndex = 0

	processIndex += 1
	toProcess[processIndex] = entityId
	if self._relations[entityId] then
		for relationComponent, relation in self._relations[entityId] do
			if not processed[relation.target] then
				processed[relation.target] = true
				processIndex += 1
				toProcess[processIndex] = relation.target
			end

			if self._reverseRelations[entityId] and self._reverseRelations[entityId][relationComponent] then
				for _, sourceId in self._reverseRelations[entityId][relationComponent] do
					if not processed[sourceId] then
						processed[sourceId] = true
						processIndex += 1
						toProcess[processIndex] = sourceId
					end
				end
			end
		end
	end

	local currentIndex = 1
	while currentIndex <= processIndex do
		local currentId = toProcess[currentIndex]
		currentIndex += 1
		if self._relations[currentId] then
			for relationComponent, relation in self._relations[currentId] do
				if not processed[relation.target] then
					processed[relation.target] = true
					processIndex += 1
					toProcess[processIndex] = relation.target
				end
				self._relations[currentId][relationComponent] = nil
			end
			self._relations[currentId] = nil
		end

		if self._reverseRelations[currentId] then
			for relationComponent, sources in self._reverseRelations[currentId] do
				for _, sourceId in sources do
					if not processed[sourceId] then
						processed[sourceId] = true
						processIndex += 1
						toProcess[processIndex] = sourceId
					end
					if self._relations[sourceId] then
						self._relations[sourceId][relationComponent] = nil
					end
				end
			end
			self._reverseRelations[currentId] = nil
		end

		__DespawnSingle(self, entityId)
	end
end

local function __CreateArchetype(self: Yumina, bitmasks: { number }): Archetype
	local archetype = {
		bitmasks = bitmasks,
		componentData = {},
		entities = {},
		entityRow = {},
		entityCount = 0,
		dirtyFlags = DIRTY_ADDITION,
		addEdges = {},
		removeEdges = {},
		edgeRefs = { next = nil, prev = nil },
	} :: Archetype

	local key = GetArchetypeKey(bitmasks)
	self._archetypeIndex[key] = archetype
	return archetype
end

local function __CreateTransitionInfo(self: Yumina, source: Archetype, destination: Archetype): TransitionInfo
	local transitionKey = GetTransitionKey(source.bitmasks, destination.bitmasks)
	local cachedTransition = self._edgeCache[transitionKey]
	if cachedTransition then
		return cachedTransition.transition
	end

	local shared = table.create(4)
	local added = table.create(1)
	local sharedCount = 0
	local addedCount = 0

	for maskIndex = 1, NUM_BITMASKS do
		local sourceMask = source.bitmasks[maskIndex]
		local destMask = destination.bitmasks[maskIndex]
		local baseComponent = (maskIndex - 1) * BITS_PER_MASK

		local sharedMask = band(sourceMask, destMask)
		while sharedMask ~= 0 do
			local bit = countrz(sharedMask)
			sharedCount += 1
			shared[sharedCount] = baseComponent + bit + 1
			sharedMask = band(sharedMask, bnot(lshift(1, bit)))
		end

		local addedMask = band(bnot(sourceMask), destMask)
		while addedMask ~= 0 do
			local bit = countrz(addedMask)
			addedCount += 1
			added[addedCount] = baseComponent + bit + 1
			addedMask = band(addedMask, bnot(lshift(1, bit)))
		end
	end

	local transition = {
		source = source,
		destination = destination,
		sharedComponents = table.move(shared, 1, sharedCount, 1, table.create(sharedCount)),
		addedComponents = table.move(added, 1, addedCount, 1, table.create(addedCount)),
		removedComponents = {},
		frequency = 0,
	}

	self._edgeCache[transitionKey] = { to = destination, transition = transition }
	self.OnCached:Fire("Transition", transitionKey)
	return transition
end

local function __AddEdge(self: Yumina, from: Archetype, to: Archetype, componentId: ComponentId): Edge
	local addEdge = {
		from = from,
		to = to,
		next = nil,
		prev = nil,
		componentId = componentId,
		transition = __CreateTransitionInfo(self, from, to),
	} :: Edge

	local removeEdge = {
		from = to,
		to = from,
		next = nil,
		prev = nil,
		componentId = componentId,
		transition = __CreateTransitionInfo(self, to, from),
	} :: Edge

	if to.edgeRefs.next then
		addEdge.next = to.edgeRefs.next
		to.edgeRefs.next.prev = addEdge
	end
	to.edgeRefs.next = addEdge
	addEdge.prev = from.edgeRefs.prev

	if from.edgeRefs.next then
		removeEdge.next = from.edgeRefs.next
		from.edgeRefs.next.prev = removeEdge
	end
	from.edgeRefs.next = removeEdge
	removeEdge.prev = to.edgeRefs.prev

	from.addEdges[componentId] = addEdge
	to.removeEdges[componentId] = removeEdge

	return addEdge
end

local function __FastPathMove(
	self: Yumina,
	entity: EntityId,
	source: Archetype,
	destination: Archetype,
	transition: TransitionInfo,
	newComponentsData: { [ComponentId]: any }?
)
	-- // TODO: CRITICAL: This path is causing a big performance loss
	if band(destination.dirtyFlags, bor(DIRTY_UPDATE, DIRTY_ADDITION)) ~= 0 then
		local transitionKey = GetTransitionKey(source.bitmasks, destination.bitmasks)
		self._edgeCache[transitionKey] = nil
		transition = __CreateTransitionInfo(self, source, destination)
	end

	local sourceEntityRow = source.entityRow
	local sourceEntities = source.entities
	local fromRow = sourceEntityRow[entity]
	local sourceCount = source.entityCount
	local dstComponents = destination.componentData
	local srcComponents = source.componentData
	local toRow = destination.entityCount + 1

	if fromRow then
		for _, componentId in transition.sharedComponents do
			local srcColumn = srcComponents[componentId]
			if srcColumn then
				local value = srcColumn[fromRow]
				if value ~= nil then
					if not dstComponents[componentId] then
						dstComponents[componentId] = table.create(toRow + 32)
					end
					dstComponents[componentId][toRow] = value
				end
			end
		end

		local needsBackfill = fromRow < sourceCount
		if needsBackfill then
			local lastEntity = sourceEntities[sourceCount]
			sourceEntities[fromRow] = lastEntity
			sourceEntityRow[lastEntity] = fromRow

			for _, srcColumn in srcComponents do
				srcColumn[fromRow] = srcColumn[sourceCount]
				srcColumn[sourceCount] = nil
			end
		end

		source.entityCount = sourceCount - 1
		sourceEntities[sourceCount] = nil
		sourceEntityRow[entity] = nil
		source.dirtyFlags = bor(source.dirtyFlags, DIRTY_REMOVAL)
	end

	if newComponentsData then
		for componentId, value in newComponentsData do
			if not dstComponents[componentId] then
				dstComponents[componentId] = table.create(toRow + 32)
			end
			dstComponents[componentId][toRow] = value
		end
	end

	destination.entities[toRow] = entity
	destination.entityRow[entity] = toRow
	destination.entityCount = toRow
	destination.dirtyFlags = bor(destination.dirtyFlags, DIRTY_ADDITION)
	self._entityIndex[entity] = destination
	self.OnTransition:Fire(entity, source, destination)
end

--[[
    @function Yumina.Has
    @description Checks if an entity has a specific component
    @param entity EntityId The entity to check
    @param component ComponentId The component ID to check for
    @return any? The component data if found, nil otherwise
]]
function Yumina.Has(self: Yumina, entity: EntityId, component: ComponentId): any?
	local entityId = ValidateEntity(self, entity)
	local archetype = self._entityIndex[entityId]
	if not archetype then
		return nil
	end
	local componentArray = archetype.componentData[component]
	if not componentArray then
		return nil
	end
	return componentArray[archetype.entityRow[entityId]]
end

function Yumina.Pair(self: Yumina, componentId: ComponentId): ComponentId
	if DEBUG_MODE then
		ValidateComponentId(componentId)
	end
	local relation = bor(componentId, RELATIONSHIP_COMPONENT)
	self._relations = self._relations or {}
	self._reverseRelations = self._reverseRelations or {}
	return relation
end

function Yumina.GetRelated(self: Yumina, entity: EntityId, relationComponent: ComponentId): { EntityId }
	if not self._reverseRelations[entity] or not self._reverseRelations[entity][relationComponent] then
		return {}
	end

	local results = {}
	for sourceId in self._reverseRelations[entity][relationComponent] do
		table.insert(results, sourceId)
	end
	return results
end

function Yumina.Target(self: Yumina, entity: EntityId, relationComponent: ComponentId): (EntityId?, any?)
	if not self._relations[entity] or not self._relations[entity][relationComponent] then
		return nil
	end
	local relation = self._relations[entity][relationComponent]
	return relation.target, relation.data
end

--[[
    @function Yumina.Set
    @description Sets a component value for an entity
    @param entity EntityId Target entity
    @param component ComponentId Component ID to set
    @param data T Component data
    @return Yumina Self for chaining
]]
function Yumina.Set<T>(self: Yumina, entity: EntityId, component: ComponentId, data: T): Yumina
	local entityId = if DEBUG_MODE then ValidateEntity(self, entity) else entity
	local currentArchetype = self._entityIndex[entityId]

	if component >= RELATIONSHIP_COMPONENT then
		local relations = self._relations[entity]
		if data then
			local targetEntity = if typeof(data) == "number" then data else (data :: any).target
			if not relations then
				relations = {}
				self._relations[entity] = relations
			end
			relations[component] = { target = targetEntity, data = data }

			local reverseRels = self._reverseRelations[targetEntity]
			if not reverseRels then
				local temp = {}
				temp[component] = { entity }
				self._reverseRelations[targetEntity] = temp
				reverseRels = temp
			else
				local sources = reverseRels[component]
				if not sources then
					reverseRels[component] = { entity }
				else
					sources[#sources + 1] = entity
				end
			end
		elseif relations and relations[component] then
			local oldTarget = relations[component].target
			if oldTarget then
				local sources = self._reverseRelations[oldTarget][component]
				if sources then
					local last = sources[#sources]
					if last == entity then
						sources[#sources] = nil
					else
						for i = 1, #sources do
							if sources[i] == entity then
								sources[i] = last
								sources[#sources] = nil
								break
							end
						end
					end
				end
			end
			relations[component] = nil
		end
		return self
	end

	if currentArchetype then
		local maskIndex = rshift(component - 1, 5) + 1
		local bitPos = band(component - 1, 0x1F)
		local mask = lshift(1, bitPos)

		if band(currentArchetype.bitmasks[maskIndex], mask) ~= 0 then
			local row = currentArchetype.entityRow[entityId]
			local column = currentArchetype.componentData[component]
			if not column then
				column = table.create(currentArchetype.entityCount + 32)
				currentArchetype.componentData[component] = column
			end
			column[row] = data
			currentArchetype.dirtyFlags = bor(currentArchetype.dirtyFlags, DIRTY_UPDATE)
			self.OnSet:Fire(entity, component, data)
			return self
		end

		local edge = currentArchetype.addEdges[component]
		if edge and edge.transition then
			__FastPathMove(self, entityId, currentArchetype, edge.to, edge.transition, { [component] = data })
			self.OnSet:Fire(entity, component, data)
			return self
		end

		local newBits = {
			currentArchetype.bitmasks[1],
			currentArchetype.bitmasks[2],
			currentArchetype.bitmasks[3],
		}
		newBits[maskIndex] = bor(newBits[maskIndex], mask)

		local archetypeKey = GetArchetypeKey(newBits)
		local targetArchetype = self._archetypeIndex[archetypeKey]
		if not targetArchetype then
			targetArchetype = __CreateArchetype(self, newBits)
		end

		local newEdge = __AddEdge(self, currentArchetype, targetArchetype, component)
		__FastPathMove(self, entityId, currentArchetype, targetArchetype, newEdge.transition, { [component] = data }) -- // Problematic spot
		self.OnSet:Fire(entity, component, data)
		return self
	end

	local maskIndex = rshift(component - 1, 5) + 1
	local bitPos = band(component - 1, 0x1F)
	local bitMask = lshift(1, bitPos)

	local archetypeKey = if maskIndex == 1
		then bitMask
		else if maskIndex == 2 then lshift(bitMask, 21) else lshift(bitMask, 42)

	local existingArchetype = self._archetypeIndex[archetypeKey]
	if existingArchetype then
		local newRow = existingArchetype.entityCount + 1
		existingArchetype.entityCount = newRow
		existingArchetype.entities[newRow] = entityId
		existingArchetype.entityRow[entityId] = newRow

		local column = existingArchetype.componentData[component]
		if not column then
			column = table.create(32)
			existingArchetype.componentData[component] = column
		end
		column[newRow] = data

		existingArchetype.dirtyFlags = bor(existingArchetype.dirtyFlags, DIRTY_ADDITION)
		self._entityIndex[entityId] = existingArchetype
	else
		local bitmasks = {
			maskIndex == 1 and bitMask or 0,
			maskIndex == 2 and bitMask or 0,
			maskIndex == 3 and bitMask or 0,
		}
		local newArchetype = __CreateArchetype(self, bitmasks)
		local column = table.create(32)
		column[1] = data
		newArchetype.componentData[component] = column
		newArchetype.entities[1] = entityId
		newArchetype.entityRow[entityId] = 1
		newArchetype.entityCount = 1
		self._entityIndex[entityId] = newArchetype
	end

	self.OnSet:Fire(entity, component, data)
	return self
end

--[[
    @function Yumina.Remove  
    @description Removes a component from an entity
    @param entity EntityId Target entity
    @param component ComponentId Component to remove
    @return Yumina Self for chaining
]]
function Yumina.Remove(self: Yumina, entity: EntityId, component: ComponentId): Yumina
	local entityId = ValidateEntity(self, entity)

	if band(component, RELATIONSHIP_COMPONENT) ~= 0 then
		if self._relations[entity] then
			local relation = self._relations[entity][component]
			if relation then
				local targetEntity = relation.target
				self._relations[entity][component] = nil

				if self._reverseRelations[targetEntity] and self._reverseRelations[targetEntity][component] then
					local sources = self._reverseRelations[targetEntity][component]
					for i, sourceId in sources do
						if sourceId == entity then
							table.remove(sources, i)
							break
						end
					end
					if #sources == 0 then
						self._reverseRelations[targetEntity][component] = nil
					end
				end
			end
		end
	end

	local currentArchetype = self._entityIndex[entityId]
	if not currentArchetype then
		return self
	end

	local maskIndex, bitPos = GetComponentBits(component)
	local mask = lshift(1, bitPos)
	if band(currentArchetype.bitmasks[maskIndex], mask) == 0 then
		return self
	end

	local edge = currentArchetype.removeEdges[component]
	if edge and edge.to then
		__FastPathMove(self, entityId, currentArchetype, edge.to, edge.transition)
		return self
	end

	local newBits = { currentArchetype.bitmasks[1], currentArchetype.bitmasks[2], currentArchetype.bitmasks[3] }
	newBits[maskIndex] = band(newBits[maskIndex], bnot(mask))

	local targetArchetype = self._archetypeIndex[GetArchetypeKey(newBits)]
	if not targetArchetype then
		targetArchetype = __CreateArchetype(self, newBits)
	end

	local edge2 = __AddEdge(self, targetArchetype, currentArchetype, component)
	__FastPathMove(self, entityId, currentArchetype, edge2.from, edge2.transition)
	return self
end

--[[
    @class QueryViewer
    @description Query iterator for filtered entity views
]]
local QueryViewer = {}
QueryViewer.__index = QueryViewer

export type QueryViewer = typeof(setmetatable({
	archetypes = {} :: { Archetype },
	components = {} :: { ComponentId },
	includeBitmasks = {} :: { number },
	excludeBitmasks = {} :: { number },
}, QueryViewer))

local function __NewQuery(q: {
	archetypes: { Archetype },
	components: { ComponentId },
	includeBitmasks: { number },
	excludeBitmasks: { number },
}): QueryViewer
	return setmetatable(q, QueryViewer)
end

--[[
    @function QueryViewer.With
    @description Adds required components to query
    @param componentIds { ComponentId } Components that must be present
    @return QueryViewer Self for chaining
]]
function QueryViewer.With(self: QueryViewer, componentIds: { ComponentId }): QueryViewer
	if _G.__YUMINA_DEBUG then
		AssertArgument(#componentIds > 0, ERROR_TYPE.QUERY_ERROR, "Must provide at least one component ID")
	end

	for _, componentId in componentIds do
		local maskIndex, bitPosition = GetComponentBits(componentId)
		self.includeBitmasks[maskIndex] = bor(self.includeBitmasks[maskIndex], lshift(1, bitPosition))

		local exists = false
		for _, existingId in self.components do
			if existingId == componentId then
				exists = true
				break
			end
		end
		if not exists then
			table.insert(self.components, componentId)
		end
	end

	for i = #self.archetypes, 1, -1 do
		local archetype = self.archetypes[i]
		local matches = true

		for maskIndex = 1, NUM_BITMASKS do
			if
				band(archetype.bitmasks[maskIndex], self.includeBitmasks[maskIndex]) ~= self.includeBitmasks[maskIndex]
			then
				matches = false
				break
			end
		end

		if not matches then
			local lastIndex = #self.archetypes
			if i ~= lastIndex then
				self.archetypes[i] = self.archetypes[lastIndex]
			end
			self.archetypes[lastIndex] = nil
		end
	end

	return self
end

--[[
    @function QueryViewer.Without  
    @description Excludes components from query
    @param componentIds { ComponentId } Components that must not be present
    @return QueryViewer Self for chaining
]]
function QueryViewer.Without(self: QueryViewer, componentIds: { ComponentId }): QueryViewer
	if _G.__YUMINA_DEBUG then
		AssertArgument(#componentIds > 0, ERROR_TYPE.QUERY_ERROR, "Must provide at least one component ID")
	end

	for _, componentId in componentIds do
		local maskIndex, bitPosition = GetComponentBits(componentId)
		self.excludeBitmasks[maskIndex] = bor(self.excludeBitmasks[maskIndex], lshift(1, bitPosition))
	end

	for i = #self.archetypes, 1, -1 do
		local archetype = self.archetypes[i]
		local shouldExclude = false
		for maskIndex = 1, NUM_BITMASKS do
			if band(archetype.bitmasks[maskIndex], self.excludeBitmasks[maskIndex]) ~= 0 then
				shouldExclude = true
				break
			end
		end

		if shouldExclude then
			local lastIndex = #self.archetypes
			if i ~= lastIndex then
				self.archetypes[i] = self.archetypes[lastIndex]
			end
			self.archetypes[lastIndex] = nil
		end
	end

	return self
end

function QueryViewer.View(self: QueryViewer): () -> (EntityId?, ...any)
	if #self.components == 0 then
		return function()
			return nil
		end
	end

	local numComponents = #self.components
	local currentArchetype = self.archetypes[1]
	if not currentArchetype then
		return function()
			return nil
		end
	end

	local componentArrays = table.create(numComponents)
	local componentValues = table.create(numComponents)
	if numComponents == 1 then
		local componentId = self.components[1]
		local archIndex = 1
		local entities = currentArchetype.entities
		local entityCount = #entities
		local entityIndex = 1
		local componentData = currentArchetype.componentData
		local column = componentData[componentId]

		return function()
			while true do
				if entityIndex <= entityCount then
					local entityId = entities[entityIndex]
					entityIndex += 1
					return entityId, column and column[entityIndex]
				end
				archIndex += 1
				currentArchetype = self.archetypes[archIndex]
				if not currentArchetype then
					return nil
				end
				entities = currentArchetype.entities
				entityCount = #entities
				entityIndex = 1
				componentData = currentArchetype.componentData
				column = componentData[componentId]
			end
		end
	end

	if numComponents == 2 then
		local c1, c2 = self.components[1], self.components[2]
		local archIndex = 1
		local entities = currentArchetype.entities
		local entityCount = #entities
		local entityIndex = 1
		local componentData = currentArchetype.componentData
		local column1 = componentData[c1]
		local column2 = componentData[c2]

		return function()
			while true do
				if entityIndex <= entityCount then
					local entityId = entities[entityIndex]
					local row = entityIndex
					entityIndex += 1
					return entityId, column1 and column1[row], column2 and column2[row]
				end
				archIndex += 1
				currentArchetype = self.archetypes[archIndex]
				if not currentArchetype then
					return nil
				end
				entities = currentArchetype.entities
				entityCount = #entities
				entityIndex = 1
				componentData = currentArchetype.componentData
				column1 = componentData[c1]
				column2 = componentData[c2]
			end
		end
	end

	if numComponents == 3 then
		local c1, c2, c3 = self.components[1], self.components[2], self.components[3]
		local archIndex = 1
		local entities = currentArchetype.entities
		local entityCount = #entities
		local entityIndex = 1
		local componentData = currentArchetype.componentData
		local column1 = componentData[c1]
		local column2 = componentData[c2]
		local column3 = componentData[c3]

		return function()
			while true do
				if entityIndex <= entityCount then
					local entityId = entities[entityIndex]
					local row = entityIndex
					entityIndex += 1
					return entityId, column1 and column1[row], column2 and column2[row], column3 and column3[row]
				end
				archIndex += 1
				currentArchetype = self.archetypes[archIndex]
				if not currentArchetype then
					return nil
				end
				entities = currentArchetype.entities
				entityCount = #entities
				entityIndex = 1
				componentData = currentArchetype.componentData
				column1 = componentData[c1]
				column2 = componentData[c2]
				column3 = componentData[c3]
			end
		end
	end

	if numComponents == 4 then
		local c1, c2, c3, c4 = self.components[1], self.components[2], self.components[3], self.components[4]
		local archIndex = 1
		local entities = currentArchetype.entities
		local entityCount = #entities
		local entityIndex = 1
		local componentData = currentArchetype.componentData
		local column1 = componentData[c1]
		local column2 = componentData[c2]
		local column3 = componentData[c3]
		local column4 = componentData[c4]

		return function()
			while true do
				if entityIndex <= entityCount then
					local entityId = entities[entityIndex]
					local row = entityIndex
					entityIndex += 1
					return entityId,
						column1 and column1[row],
						column2 and column2[row],
						column3 and column3[row],
						column4 and column4[row]
				end
				archIndex += 1
				currentArchetype = self.archetypes[archIndex]
				if not currentArchetype then
					return nil
				end
				entities = currentArchetype.entities
				entityCount = #entities
				entityIndex = 1
				componentData = currentArchetype.componentData
				column1 = componentData[c1]
				column2 = componentData[c2]
				column3 = componentData[c3]
				column4 = componentData[c4]
			end
		end
	end

	if numComponents == 5 then
		local c1, c2, c3, c4, c5 =
			self.components[1], self.components[2], self.components[3], self.components[4], self.components[5]
		local archIndex = 1
		local entities = currentArchetype.entities
		local entityCount = #entities
		local entityIndex = 1
		local componentData = currentArchetype.componentData
		local column1 = componentData[c1]
		local column2 = componentData[c2]
		local column3 = componentData[c3]
		local column4 = componentData[c4]
		local column5 = componentData[c5]

		return function()
			while true do
				if entityIndex <= entityCount then
					local entityId = entities[entityIndex]
					local row = entityIndex
					entityIndex += 1
					return entityId,
						column1 and column1[row],
						column2 and column2[row],
						column3 and column3[row],
						column4 and column4[row],
						column5 and column5[row]
				end
				archIndex += 1
				currentArchetype = self.archetypes[archIndex]
				if not currentArchetype then
					return nil
				end
				entities = currentArchetype.entities
				entityCount = #entities
				entityIndex = 1
				componentData = currentArchetype.componentData
				column1 = componentData[c1]
				column2 = componentData[c2]
				column3 = componentData[c3]
				column4 = componentData[c4]
				column5 = componentData[c5]
			end
		end
	end

	local archIndex = 1
	local entityIndex = 1
	local entities = currentArchetype.entities
	local entityCount = #entities
	local components = self.components
	local componentData = currentArchetype.componentData
	for i, componentId in components do
		componentArrays[i] = componentData[componentId]
	end

	return function()
		while true do
			if entityIndex <= entityCount then
				local entityId = entities[entityIndex]
				local row = entityIndex
				for i = 1, numComponents do
					componentValues[i] = componentArrays[i] and componentArrays[i][row]
				end
				entityIndex += 1
				return entityId, table.unpack(componentValues, 1, numComponents)
			end

			archIndex += 1
			currentArchetype = self.archetypes[archIndex]
			if not currentArchetype then
				return nil
			end

			entities = currentArchetype.entities
			entityCount = #entities
			entityIndex = 1
			componentData = currentArchetype.componentData
			for i = 1, numComponents do
				componentArrays[i] = componentData[components[i]]
			end
		end
	end
end

--[[
    @function Yumina.Query
    @description Creates a query for entities matching component criteria
    @param components { ComponentId } Array of component IDs to query for
    @return QueryViewer Query iterator
]]
function Yumina.Query(self: Yumina, components: { ComponentId }): QueryViewer
	if #components == 1 then
		local componentId = components[1]
		if DEBUG_MODE then
			ValidateComponentId(componentId)
		end

		local maskIndex, bitPos = GetComponentBits(componentId)
		local bitMask = lshift(1, bitPos)
		local queryKey = bor(
			band(maskIndex == 1 and bitMask or 0, 0x3FF),
			lshift(band(maskIndex == 2 and bitMask or 0, 0x3FF), 10),
			lshift(band(maskIndex == 3 and bitMask or 0, 0x3FF), 20)
		)

		local cached = self._queryCache[queryKey]
		if cached and band(cached.archetypes[1] and cached.archetypes[1].dirtyFlags or 0, DIRTY_UPDATE) == 0 then
			return cached
		end

		local result = {}
		for _, archetype in self._archetypeIndex do
			if band(archetype.bitmasks[maskIndex], bitMask) == bitMask then
				result[#result + 1] = archetype
			end
		end

		local query = __NewQuery({
			archetypes = result,
			includeBitmasks = {
				maskIndex == 1 and bitMask or 0,
				maskIndex == 2 and bitMask or 0,
				maskIndex == 3 and bitMask or 0,
			},
			excludeBitmasks = { 0, 0, 0 },
			components = components,
		})
		self._queryCache[queryKey] = query
		self.OnCached:Fire("Query", queryKey)
		return query
	end

	if #components == 2 then
		local c1, c2 = components[1], components[2]
		if DEBUG_MODE then
			ValidateComponentId(c1)
			ValidateComponentId(c2)
		end

		local m1, b1p = GetComponentBits(c1)
		local m2, b2p = GetComponentBits(c2)
		local b1, b2 = lshift(1, b1p), lshift(1, b2p)

		local mask1 = m1 == 1 and b1 or (m2 == 1 and b2 or 0)
		local mask2 = m1 == 2 and b1 or (m2 == 2 and b2 or 0)
		local mask3 = m1 == 3 and b1 or (m2 == 3 and b2 or 0)
		local queryKey = bor(band(mask1, 0x3FF), lshift(band(mask2, 0x3FF), 10), lshift(band(mask3, 0x3FF), 20))

		local cached = self._queryCache[queryKey]
		if cached and band(cached.archetypes[1] and cached.archetypes[1].dirtyFlags or 0, DIRTY_UPDATE) == 0 then
			return cached
		end

		local result = {}
		for _, archetype in self._archetypeIndex do
			if band(archetype.bitmasks[m1], b1) == b1 and band(archetype.bitmasks[m2], b2) == b2 then
				result[#result + 1] = archetype
			end
		end

		local query = __NewQuery({
			archetypes = result,
			includeBitmasks = {
				mask1,
				mask2,
				mask3,
			},
			excludeBitmasks = { 0, 0, 0 },
			components = components,
		})
		self._queryCache[queryKey] = query
		self.OnCached:Fire("Query", queryKey)
		return query
	end

	local queryBitmasks = { 0, 0, 0 }
	for _, componentId in components do
		if DEBUG_MODE then
			ValidateComponentId(componentId)
		end
		local maskIndex, bitPos = GetComponentBits(componentId)
		queryBitmasks[maskIndex] = bor(queryBitmasks[maskIndex], lshift(1, bitPos))
	end

	local queryKey = GetQueryKey(queryBitmasks, { 0, 0, 0 })
	local cached = self._queryCache[queryKey]
	if cached and band(cached.archetypes[1] and cached.archetypes[1].dirtyFlags or 0, DIRTY_UPDATE) == 0 then
		return cached
	end

	local result = {}
	for _, archetype in self._archetypeIndex do
		if
			band(archetype.bitmasks[1], queryBitmasks[1]) == queryBitmasks[1]
			and band(archetype.bitmasks[2], queryBitmasks[2]) == queryBitmasks[2]
			and band(archetype.bitmasks[3], queryBitmasks[3]) == queryBitmasks[3]
		then
			result[#result + 1] = archetype
		end
	end

	local query = __NewQuery({
		archetypes = result,
		includeBitmasks = queryBitmasks,
		excludeBitmasks = { 0, 0, 0 },
		components = components,
	})
	self._queryCache[queryKey] = query
	self.OnCached:Fire("Query", queryKey)
	return query
end

local function ValidateEdge(edge: Edge): { Edge }
	return edge
		and edge.from
		and edge.to
		and edge.componentId
		and edge.transition
		and edge.from.addEdges
		and edge.to.removeEdges
end

--[[
    @function Yumina.Cleanup
    @description Performs cache cleanup and maintenance
]]
function Yumina.Cleanup(self: Yumina): ()
	if self._nextId >= ENTITY_MASK then
		ThrowError(ERROR_TYPE.MEMORY_ERROR, "Entity ID space exhausted")
	end

	local dirtyArchetypes = {}
	local emptyArchetypes = {}
	for id, archetype in self._archetypeIndex do
		if archetype.entityCount == 0 then
			emptyArchetypes[id] = archetype
		elseif band(archetype.dirtyFlags, bor(DIRTY_ADDITION, DIRTY_REMOVAL, DIRTY_UPDATE)) ~= 0 then
			dirtyArchetypes[id] = archetype
		end
	end

	for id, archetype in emptyArchetypes do
		for componentId, edge in archetype.addEdges do
			if edge and ValidateEdge(edge) then
				edge.from.addEdges[componentId] = nil
				edge.to.removeEdges[componentId] = nil

				if edge and edge.next and ValidateEdge(edge.next) then
					edge.next.prev = edge.prev
				end
				if edge and edge.next and edge.prev and ValidateEdge(edge.prev) then
					edge.prev.next = edge.next
				end

				local transitionKey = GetTransitionKey(edge.from.bitmasks, edge.to.bitmasks)
				self._edgeCache[transitionKey] = nil
			end
		end

		archetype.addEdges = {}
		archetype.removeEdges = {}
		archetype.edgeRefs = { next = nil, prev = nil }
		archetype.componentData = {}
		self._archetypeIndex[id] = nil
	end

	local function MatchesQuery(archetype: Archetype, includeBits: { number }, excludeBits: { number }): boolean
		for maskIndex = 1, NUM_BITMASKS do
			if band(archetype.bitmasks[maskIndex], includeBits[maskIndex]) ~= includeBits[maskIndex] then
				return false
			end
			if band(archetype.bitmasks[maskIndex], excludeBits[maskIndex]) ~= 0 then
				return false
			end
		end
		return true
	end

	for _, query in self._queryCache do
		local needsUpdate = false
		for _, archetype in query.archetypes do
			local archetypeKey = GetArchetypeKey(archetype.bitmasks)
			if emptyArchetypes[archetypeKey] or dirtyArchetypes[archetypeKey] then
				needsUpdate = true
				break
			end
		end

		if needsUpdate then
			local archetypes = query.archetypes
			local updatedArchetypes = {}
			local updatedCount = 0
			for _, archetype in archetypes do
				local key = GetArchetypeKey(archetype.bitmasks)
				if not emptyArchetypes[key] then
					if dirtyArchetypes[key] then
						if MatchesQuery(archetype, query.includeBitmasks, query.excludeBitmasks) then
							updatedCount += 1
							updatedArchetypes[updatedCount] = archetype
						end
					else
						updatedCount += 1
						updatedArchetypes[updatedCount] = archetype
					end
				end
			end
			query.archetypes = updatedArchetypes
		end
	end
	for _, archetype in dirtyArchetypes do
		archetype.dirtyFlags = 0
	end

	self.OnCleanup:Fire()
end

return Yumina.new()
