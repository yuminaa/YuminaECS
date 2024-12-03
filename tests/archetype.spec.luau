local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ, ASSERT_TRUE = test_runner.ASSERT_EQ, test_runner.ASSERT_TRUE

local POSITION = 1
local VELOCITY = 2
local DAMAGE = 33

TEST_F("archetype", "single_component")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })

	local archetype = ecs._entityIndex[entity]
	ASSERT_TRUE(archetype ~= nil)
	ASSERT_EQ(archetype.entityCount, 1)
	ASSERT_EQ(archetype.bitmasks[1], 1)
	ASSERT_EQ(archetype.bitmasks[2], 0)
	ASSERT_EQ(archetype.bitmasks[3], 0)
end)

TEST_F("archetype", "multi_component_same_mask")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, VELOCITY, { x = 3, y = 4 })

	local archetype = ecs._entityIndex[entity]
	ASSERT_TRUE(archetype ~= nil)
	ASSERT_EQ(archetype.entityCount, 1)
	ASSERT_EQ(archetype.bitmasks[1], 3)
	ASSERT_EQ(archetype.bitmasks[2], 0)
	ASSERT_EQ(archetype.bitmasks[3], 0)
end)

TEST_F("archetype", "components_across_masks")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, DAMAGE, 10)

	local archetype = ecs._entityIndex[entity]
	ASSERT_TRUE(archetype ~= nil)
	ASSERT_EQ(archetype.entityCount, 1)
	ASSERT_EQ(archetype.bitmasks[1], 1)
	ASSERT_EQ(archetype.bitmasks[2], 1)
	ASSERT_EQ(archetype.bitmasks[3], 0)
end)

TEST_F("archetype", "transition")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	local first_archetype = ecs._entityIndex[entity]
	ecs:Set(entity, VELOCITY, { x = 3, y = 4 })
	local second_archetype = ecs._entityIndex[entity]

	ASSERT_TRUE(first_archetype ~= second_archetype)
	ASSERT_EQ(first_archetype.entityCount, 0)
	ASSERT_EQ(second_archetype.entityCount, 1)
end)

TEST_F("archetype", "component_removal")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, VELOCITY, { x = 3, y = 4 })
	local init_archetype = ecs._entityIndex[entity]

	ecs:Remove(entity, VELOCITY)
	local final_archetype = ecs._entityIndex[entity]

	ASSERT_TRUE(init_archetype ~= final_archetype)
	ASSERT_EQ(init_archetype.entityCount, 0)
	ASSERT_EQ(final_archetype.entityCount, 1)
	ASSERT_EQ(final_archetype.bitmasks[1], 1)
end)

TEST_F("archetype", "reuse")(function()
	local ecs = yumina.new()
	local entity1 = ecs:Entity()
	local entity2 = ecs:Entity()

	ecs:Set(entity1, POSITION, { x = 1, y = 2 })
	ecs:Set(entity1, VELOCITY, { x = 3, y = 4 })
	local archetype1 = ecs._entityIndex[entity1]

	ecs:Set(entity2, POSITION, { x = 5, y = 6 })
	ecs:Set(entity2, VELOCITY, { x = 7, y = 8 })
	local archetype2 = ecs._entityIndex[entity2]

	ASSERT_TRUE(archetype1 == archetype2)
	ASSERT_EQ(archetype1.entityCount, 2)
end)

TEST_F("archetype", "column_transition_caching")(function()
	local ecs = yumina.new()
	local entity1 = ecs:Entity()
	local entity2 = ecs:Entity()

	ecs:Set(entity1, POSITION, { x = 1, y = 2 })
	ecs:Set(entity1, VELOCITY, { x = 3, y = 4 })

	local init_transition_count = 0
	for _, transitions in ecs._columnTransitions do
		for _ in transitions do
			init_transition_count += 1
		end
	end

	ecs:Set(entity2, POSITION, { x = 5, y = 6 })
	ecs:Set(entity2, VELOCITY, { x = 7, y = 8 })

	local final_transition_count = 0
	for _, transitions in ecs._columnTransitions do
		for _ in transitions do
			final_transition_count += 1
		end
	end

	ASSERT_EQ(init_transition_count, final_transition_count)
end)

TEST_F("archetype", "sequential_add_remove")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	ecs:Set(entity, VELOCITY, { x = 3, y = 4 })
	ecs:Set(entity, DAMAGE, 10)

	ecs:Remove(entity, DAMAGE)
	local archetype1 = ecs._entityIndex[entity]
	ASSERT_EQ(archetype1.bitmasks[1], 3)
	ASSERT_EQ(archetype1.bitmasks[2], 0)

	ecs:Remove(entity, VELOCITY)
	local archetype2 = ecs._entityIndex[entity]
	ASSERT_EQ(archetype2.bitmasks[1], 1)
	ASSERT_EQ(archetype2.bitmasks[2], 0)

	ecs:Remove(entity, POSITION)
	local archetype3 = ecs._entityIndex[entity]
	ASSERT_TRUE(archetype3 ~= nil)
end)

TEST_F("archetype", "component_override")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 2 })
	local archetype1 = ecs._entityIndex[entity]

	ecs:Set(entity, POSITION, { x = 3, y = 4 })
	local archetype2 = ecs._entityIndex[entity]

	ASSERT_TRUE(archetype1 == archetype2)
	ASSERT_EQ(archetype1.bitmasks[1], 1)
end)

TEST_F("archetype", "rapid_state_change")(function()
	local ecs = yumina.new()
	local entity = ecs:Entity()

	ecs:Set(entity, POSITION, { x = 1, y = 1 })
	ecs:Set(entity, VELOCITY, { x = 2, y = 2 })
	ecs:Remove(entity, POSITION)
	ecs:Set(entity, DAMAGE, 10)
	ecs:Remove(entity, VELOCITY)
	ecs:Set(entity, POSITION, { x = 3, y = 3 })

	local archetype = ecs._entityIndex[entity]
	ASSERT_TRUE(archetype ~= nil)
	ASSERT_EQ(archetype.bitmasks[1], 1)
	ASSERT_EQ(archetype.bitmasks[2], 1)
	ASSERT_EQ(archetype.entityCount, 1)
end)

TEST_F("archetype", "visualize_transitions")(function()
	local ecs = yumina.new()

	local function print_transitions()
		print("\nArchetypes:")
		for _, archetype in ecs._archetypeIndex do
			print(
				"Archetype: "
					.. string.format(
						"[%d,%d,%d] count:%d",
						archetype.bitmasks[1],
						archetype.bitmasks[2],
						archetype.bitmasks[3],
						archetype.entityCount
					)
			)
			for _, transitions in ecs._columnTransitions do
				for _, transition in transitions do
					if transition.sourceColumns == archetype.componentData then
						print("  -> Components shared: " .. table.concat(transition.sharedComponents, ","))
					end
				end
			end
		end
	end

	local e1 = ecs:Entity()
	print_transitions()

	ecs:Set(e1, POSITION, { x = 1, y = 1 })
	print_transitions()

	ecs:Set(e1, VELOCITY, { x = 1, y = 1 })
	print_transitions()

	ecs:Remove(e1, POSITION)
	print_transitions()
end)

RUN_ALL_TESTS()
