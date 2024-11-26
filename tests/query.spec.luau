local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ = test_runner.ASSERT_EQ

TEST_F("query", "single_component")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })
	ecs:Set(e2, POSITION, { x = 0, y = 0, z = 0 })

	local count1 = 0
	for _, _ in ecs:Query({ POSITION }):View() do
		count1 += 1
	end

	ASSERT_EQ(count1, 2)
end)

TEST_F("query", "multi_query")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })
	ecs:Set(e1, VELOCITY, { vx = 0, vy = 1, vz = 0 })
	ecs:Set(e2, POSITION, { x = 0, y = 0, z = 0 })

	local count1 = 0
	for _, _ in ecs:Query({ POSITION, VELOCITY }):View() do
		count1 += 1
	end

	ASSERT_EQ(count1, 1)
end)

TEST_F("query", "exclude_components")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	local e3 = ecs:Entity()

	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })
	ecs:Set(e2, POSITION, { x = 1, y = 1, z = 1 })
	ecs:Set(e2, VELOCITY, { vx = 1, vy = 1, vz = 1 })
	ecs:Set(e3, POSITION, { x = 2, y = 2, z = 2 })

	-- Query for entities with Position but without Velocity
	local count = 0
	for _, _ in ecs:Query({ POSITION }):Without({ VELOCITY }):View() do
		count += 1
	end

	ASSERT_EQ(count, 2) -- Should find e1 and e3
end)

TEST_F("query", "component_data_access")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 5, y = 10, z = 15 })
	ecs:Set(e1, VELOCITY, { vx = 1, vy = 2, vz = 3 })

	for _, pos, vel in ecs:Query({ POSITION, VELOCITY }):View() do
		ASSERT_EQ(pos.x, 5)
		ASSERT_EQ(pos.y, 10)
		ASSERT_EQ(pos.z, 15)
		ASSERT_EQ(vel.vx, 1)
		ASSERT_EQ(vel.vy, 2)
		ASSERT_EQ(vel.vz, 3)
	end
end)

TEST_F("query", "query_after_remove")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })
	ecs:Set(e1, VELOCITY, { vx = 0, vy = 1, vz = 0 })

	-- Initial query
	local count1 = 0
	for _, _ in ecs:Query({ POSITION, VELOCITY }):View() do
		count1 += 1
	end
	ASSERT_EQ(count1, 1)

	-- Remove component and query again
	ecs:Remove(e1, VELOCITY)
	local count2 = 0
	for _, _ in ecs:Query({ POSITION, VELOCITY }):View() do
		count2 += 1
	end
	ASSERT_EQ(count2, 0)
end)

TEST_F("query", "cross_mask_query")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1 -- First mask
	local DAMAGE = 33 -- Second mask

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()

	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })
	ecs:Set(e1, DAMAGE, 100)
	ecs:Set(e2, POSITION, { x = 1, y = 1, z = 1 })

	local count = 0
	for _, _, dmg in ecs:Query({ POSITION, DAMAGE }):View() do
		count += 1
		ASSERT_EQ(dmg, 100)
	end

	ASSERT_EQ(count, 1)
end)

TEST_F("query", "empty_result")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 0, y = 0, z = 0 })

	local count = 0
	for _, _ in ecs:Query({ VELOCITY }):View() do
		count += 1
	end

	ASSERT_EQ(count, 0)
end)

RUN_ALL_TESTS()
