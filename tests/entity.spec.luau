local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ = test_runner.ASSERT_EQ

local function decode_entity(encodedId)
	return bit32.band(encodedId, 0x00FFFFFF), bit32.rshift(encodedId, 0x18)
end

test_runner.TEST_F("entity", "overflow")(function()
	local ecs = yumina.ECS.new()

	local e1 = ecs:Entity()
	local init_id = bit32.band(e1, 0x00FFFFFF)

	for i = 1, 257 do
		ecs:Despawn(e1)
		ecs:Cleanup()
		e1 = ecs:Entity()
		local id, gen = decode_entity(e1)

		ASSERT_EQ(id, init_id)
		ASSERT_EQ(gen, i % 256)
	end
end)

TEST_F("entity", "id_exhaustion")(function()
	local ecs = yumina.ECS.new()

	local entities = {}
	local limit = 1000
	for _ = 1, limit do
		local e = ecs:Entity()
		table.insert(entities, e)
	end

	local idSet = {}
	for _, e in entities do
		local id = bit32.band(e, 0x00FFFFFF)
		ASSERT_EQ(not idSet[id], true)
		idSet[id] = true
	end
end)

TEST_F("entity", "despawn_cleanup")(function()
	local ecs = yumina.ECS.new()

	local e1 = ecs:Entity()
	local init_id, initialGen = decode_entity(e1)

	ecs:Despawn(e1)

	e1 = ecs:Entity()
	local newId, newGen = decode_entity(e1)
	ASSERT_EQ(newId, init_id)
	ASSERT_EQ(newGen, (initialGen + 1) % 256)
end)

TEST_F("entity", "entity_count_limit")(function()
	local ecs = yumina.ECS.new()

	local limit = 2 ^ 24
	local entities = {}

	for _ = 1, limit do
		local e = ecs:Entity()
		table.insert(entities, e)
	end

	ASSERT_EQ(#entities, limit)
end)

test_runner.TEST_F("entity", "stress_test_creation")(function()
	local ecs = yumina.ECS.new()

	local limit = 10000
	for _ = 1, limit do
		ecs:Entity()
	end
end)

RUN_ALL_TESTS()
