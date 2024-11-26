local test_runner = require("@test_runner")
local yumina = require("@yumina")

local TEST_F, RUN_ALL_TESTS = test_runner.TEST_F, test_runner.RUN_ALL_TESTS
local ASSERT_EQ = test_runner.ASSERT_EQ

TEST_F("component", "data_integrity")(function()
	local ecs = yumina.ECS.new()
	local DATA = 1
	local MARKER = 2

	local complexData = {
		nested = {
			value = 42,
			array = { 1, 2, 3 },
			ref = { x = 10 },
		},
	}

	local e = ecs:Entity()
	ecs:Set(e, DATA, complexData)

	ecs:Set(e, MARKER, true)

	local retrievedData = ecs:Has(e, DATA)
	ASSERT_EQ(retrievedData.nested.value, complexData.nested.value)
	ASSERT_EQ(retrievedData.nested.array[2], complexData.nested.array[2])
	ASSERT_EQ(retrievedData.nested.ref.x, complexData.nested.ref.x)
end)

RUN_ALL_TESTS()
