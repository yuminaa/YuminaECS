local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ = test_runner.ASSERT_EQ

TEST_F("caching", "query_cache_invalidation")(function()
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

TEST_F("caching", "edge_cache_reuse")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local cache_count = 0
	ecs.OnCached:Connect(function(cache_type)
		if cache_type == "Transition" then
			cache_count += 1
		end
	end)

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1, y = 1 })
	ecs:Set(e1, VELOCITY, { x = 2, y = 2 })

	local initial_count = cache_count

	local e2 = ecs:Entity()
	ecs:Set(e2, POSITION, { x = 3, y = 3 })
	ecs:Set(e2, VELOCITY, { x = 4, y = 4 })

	ASSERT_EQ(cache_count, initial_count)
end)

TEST_F("caching", "query_cache_reuse")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1

	local cache_count = 0
	ecs.OnCached:Connect(function(cache_type)
		if cache_type == "Query" then
			cache_count += 1
		end
	end)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1 })
	ecs:Set(e2, POSITION, { x = 2 })

	ecs:Query({ POSITION }):View()
	local initial_count = cache_count

	ecs:Query({ POSITION }):View()
	ASSERT_EQ(cache_count, initial_count)
end)

TEST_F("caching", "cache_cleanup")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1 })
	ecs:Set(e1, VELOCITY, { x = 2 })

	ecs:Query({ POSITION }):View()
	ecs:Query({ POSITION, VELOCITY }):View()

	ecs:Remove(e1, POSITION)
	ecs:Remove(e1, VELOCITY)

	ecs:Cleanup()

	local count = 0
	for _, _ in ecs:Query({ POSITION }):View() do
		count += 1
	end
	ASSERT_EQ(count, 0)
end)

TEST_F("caching", "cross_mask_cache")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local DAMAGE = 33

	local cache_count = 0
	ecs.OnCached:Connect(function(cache_type)
		if cache_type == "Transition" then
			cache_count += 1
		end
	end)

	local e1 = ecs:Entity()
	ecs:Set(e1, DAMAGE, 10)
	ecs:Set(e1, POSITION, { x = 1 })

	local initial_count = cache_count

	local e2 = ecs:Entity()
	ecs:Set(e2, DAMAGE, 20)
	ecs:Set(e2, POSITION, { x = 2 })

	ASSERT_EQ(cache_count, initial_count)
end)

TEST_F("caching", "edge_cache_persistence")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2

	local cache_events = 0
	ecs.OnCached:Connect(function(cache_type)
		if cache_type == "Transition" then
			cache_events += 1
		end
	end)

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1 })
	ecs:Set(e1, VELOCITY, { x = 1 })

	local e2 = ecs:Entity()
	ecs:Set(e2, POSITION, { x = 2 })
	ecs:Set(e2, VELOCITY, { x = 2 })

	local initial_events = cache_events
	ASSERT_EQ(initial_events, 2)

	ecs:Cleanup()
	local e3 = ecs:Entity()
	ecs:Set(e3, POSITION, { x = 3 })
	ecs:Set(e3, VELOCITY, { x = 3 })

	ASSERT_EQ(cache_events, initial_events + 1)
end)

TEST_F("caching", "relationship_cache_isolation")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local PARENT = ecs:Pair(1)

	local cache_events = 0
	ecs.OnCached:Connect(function(cache_type)
		if cache_type == "Transition" then
			cache_events += 1
		end
	end)

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1 })
	local normal_events = cache_events

	local e2 = ecs:Entity()
	local e3 = ecs:Entity()
	ecs:Set(e2, PARENT, e3)
	ASSERT_EQ(cache_events, normal_events)
end)

TEST_F("caching", "query_cache_partial_match")(function()
	local ecs = yumina.ECS.new()
	local POSITION = 1
	local VELOCITY = 2
	local DAMAGE = 33

	local e1 = ecs:Entity()
	ecs:Set(e1, POSITION, { x = 1 })
	ecs:Set(e1, VELOCITY, { x = 1 })
	ecs:Set(e1, DAMAGE, 10)

	local query1 = ecs:Query({ POSITION, VELOCITY })
	local count1 = 0
	for _ in query1:View() do
		count1 += 1
	end
	ecs:Remove(e1, VELOCITY)

	local count2 = 0
	for _ in query1:View() do
		count2 += 1
	end
	ASSERT_EQ(count2, 0)
end)

RUN_ALL_TESTS()
