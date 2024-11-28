local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ, ASSERT_TRUE = test_runner.ASSERT_EQ, test_runner.ASSERT_TRUE

TEST_F("Signal", "connect_and_fire")(function()
	local ecs = yumina.new()
	local POSITION = 1

	local fired = false
	local firedEntity, firedComponent, firedData

	ecs.OnSet:Connect(function(entity, component, data)
		fired = true
		firedEntity = entity
		firedComponent = component
		firedData = data
	end)

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })

	ecs.OnSet:Wait()
	ASSERT_TRUE(fired)
	ASSERT_EQ(entity, firedEntity)
	ASSERT_EQ(firedComponent, POSITION)
	ASSERT_EQ(firedData.x, 1)
	ASSERT_EQ(firedData.y, 2)
end)

TEST_F("Signal", "multi_connection")(function()
	local ecs = yumina.new()
	local count = 0
	local POSITION = 1

	ecs.OnSet:Connect(function()
		count += 1
	end)
	ecs.OnTransition:Connect(function()
		count += 1
	end)

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })

	ecs.OnSet:Wait()
	ASSERT_EQ(count, 2)
end)

TEST_F("Signal", "disconnect")(function()
	local ecs = yumina.new()
	local POSITION = 1
	local count = 0

	local connection = ecs.OnSet:Connect(function()
		count += 1
	end)

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs.OnSet:Wait()

	connection:Disconnect()
	ecs:Set(entity, POSITION, { x = 3, y = 4 })
	ecs.OnSet:Wait()

	ASSERT_EQ(count, 1)
end)

TEST_F("Signal", "disconnect_all")(function()
	local ecs = yumina.new()
	local POSITION = 1
	local count = 0

	ecs.OnSet:Connect(function()
		count += 1
	end)
	ecs.OnSet:Connect(function()
		count += 1
	end)

	ecs.OnSet:DisconnectAll()

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs.OnSet:Wait()

	ASSERT_EQ(count, 0)
end)

TEST_F("Signal", "connect_after_fire")(function()
	local ecs = yumina.new()
	local POSITION = 1
	local count = 0

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })

	ecs.OnSet:Connect(function()
		count += 1
	end)
	ecs:Set(entity, POSITION, { x = 3, y = 4 })
	ecs.OnSet:Wait()

	ASSERT_EQ(count, 1)
end)

TEST_F("Signal", "no_call_after_fire")(function()
	local ecs = yumina.new()
	local count = 0

	local connection
	connection = ecs.OnSet:Connect(function()
		count += 1
		connection:Disconnect()
	end)

	local POSITION = 1
	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, POSITION, { x = 3, y = 4 })
	ecs.OnSet:Wait()

	ASSERT_EQ(count, 1)
end)

TEST_F("Signal", "edge_case_empty_signal_fire")(function()
	local ecs = yumina.new()
	ecs.OnCleanup:Fire()
end)

TEST_F("Signal", "multi_disconnect")(function()
	local ecs = yumina.new()
	local POSITION = 1
	local VELOCITY = 2
	local transitions = 0

	local connection = ecs.OnTransition:Connect(function()
		transitions += 1
	end)

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, VELOCITY, { vx = 1, vy = 1 })
	ecs.OnSet:Wait()

	connection:Disconnect()
	connection:Disconnect()

	ecs:Remove(entity, VELOCITY)
	ecs.OnSet:Wait()

	ASSERT_EQ(transitions, 2)
end)

TEST_F("Signal", "connect_after_return", 3)(function()
	local ecs = yumina.new()
	local POSITION = 1
	local fired = false

	coroutine.wrap(function()
		ecs.OnSet:Connect(function()
			fired = true
		end)
	end)()
	ecs.OnSet:Wait()

	local entity = ecs:Entity()
	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs.OnSet:Wait()

	ASSERT_TRUE(fired)
end)

RUN_ALL_TESTS()
