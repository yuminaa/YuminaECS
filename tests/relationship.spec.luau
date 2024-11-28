local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ, ASSERT_TRUE, ASSERT_FALSE = test_runner.ASSERT_EQ, test_runner.ASSERT_TRUE, test_runner.ASSERT_FALSE

TEST_F("relationship", "relationship_cycles")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	local e3 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	ecs:Set(e2, PARENT, e3)
	ecs:Set(e3, PARENT, e1)

	local target1, _ = ecs:Target(e1, PARENT)
	local target2, _ = ecs:Target(e2, PARENT)
	local target3, _ = ecs:Target(e3, PARENT)

	ASSERT_EQ(target1, e2)
	ASSERT_EQ(target2, e3)
	ASSERT_EQ(target3, e1)

	ecs:Despawn(e1)
	ASSERT_TRUE(target2)
	ASSERT_TRUE(target3)
end)

TEST_F("relationship", "cyclic_cleanup")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	local e3 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	ecs:Set(e2, PARENT, e3)
	ecs:Set(e3, PARENT, e1)

	ecs:Despawn(e2)

	ASSERT_EQ(ecs:Target(e1, PARENT), nil)
	ASSERT_EQ(ecs:Target(e3, PARENT), nil)
end)

TEST_F("relationship", "remove_and_read")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	local t1, _ = ecs:Target(e1, PARENT)
	ASSERT_EQ(t1, e2)

	ecs:Set(e1, PARENT, nil)
	local t2, _ = ecs:Target(e1, PARENT)
	ASSERT_EQ(t2, nil)

	ecs:Set(e1, PARENT, e2)
	local t3, _ = ecs:Target(e1, PARENT)
	ASSERT_EQ(t3, e2)
end)

TEST_F("relationship", "multiple_relationships")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)
	local FRIEND = ecs:Pair(2)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	local e3 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	ecs:Set(e1, FRIEND, e3)

	local parent, _ = ecs:Target(e1, PARENT)
	local friend, _ = ecs:Target(e1, FRIEND)

	ASSERT_EQ(parent, e2)
	ASSERT_EQ(friend, e3)
end)

TEST_F("relationship", "get_related_entities")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local parent = ecs:Entity()
	local child1 = ecs:Entity()
	local child2 = ecs:Entity()
	local child3 = ecs:Entity()

	ecs:Set(child1, PARENT, parent)
	ecs:Set(child2, PARENT, parent)
	ecs:Set(child3, PARENT, parent)

	local children = ecs:GetRelated(parent, PARENT)
	ASSERT_EQ(#children, 3)
end)

TEST_F("relationship", "despawn_cascade")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)
	local FRIEND = ecs:Pair(2)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()
	local e3 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	ecs:Set(e2, FRIEND, e3)
	ecs:Set(e3, PARENT, e1)

	ecs:Despawn(e2)

	ASSERT_EQ(ecs:Target(e1, PARENT), nil)
	ASSERT_EQ(ecs:Target(e2, FRIEND), nil)
	ASSERT_EQ(ecs:Target(e3, PARENT), nil)
end)

TEST_F("relationship", "relationship_data_storage")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local e1 = ecs:Entity()
	local e2 = ecs:Entity()

	ecs:Set(e1, PARENT, e2)
	local target, _ = ecs:Target(e1, PARENT)
	ASSERT_EQ(target, e2)

	local related = ecs:GetRelated(e2, PARENT)
	ASSERT_EQ(#related, 1)
	ASSERT_EQ(related[1], e1)
end)

TEST_F("relationship", "multiple_reverse_relationships")(function()
	local ecs = yumina.new()
	local PARENT = ecs:Pair(1)

	local target = ecs:Entity()
	local e1 = ecs:Entity()
	local e2 = ecs:Entity()

	ecs:Set(e1, PARENT, target)
	ecs:Set(e2, PARENT, target)

	local initial = ecs:GetRelated(target, PARENT)
	ASSERT_EQ(#initial, 2)

	ecs:Remove(e1, PARENT)
	local after_remove = ecs:GetRelated(target, PARENT)
	ASSERT_EQ(#after_remove, 1)

	local has_relationship = false
	for _, entity in after_remove do
		if entity == e2 then
			has_relationship = true
			break
		end
	end
	ASSERT_FALSE(has_relationship)
end)

RUN_ALL_TESTS()
