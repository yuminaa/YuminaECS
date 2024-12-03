local test_runner = require("@test_runner")
local yumina = require("@yumina")

local BENCHMARK_F, RUN_ALL_BENCHMARKS = test_runner.BENCHMARK_F, test_runner.RUN_ALL_BENCHMARKS

local N = 2 ^ 17
local bench = BENCHMARK_F("yumina-ecs", "core")

do -- // Basic creation benchmarks
	local ecs = yumina.new()
	local entities = {}

	bench.CASE("entity_creation", function()
		for i = 1, N do
			entities[i] = ecs:Entity()
		end
	end)
end

do -- // Single component operations
	local ecs = yumina.new()
	local entities = {}
	local A = 1

	for i = 1, N do
		entities[i] = ecs:Entity()
	end

	bench.CASE("add_single", function()
		for i = 1, N do
			ecs:Set(entities[i], A, 1)
		end
	end)

	bench.CASE("set_single", function()
		for i = 1, N do
			ecs:Set(entities[i], A, 2)
		end
	end)

	bench.CASE("has_single", function()
		for i = 1, N do
			local _ = ecs:Has(entities[i], A)
		end
	end)

	bench.CASE("remove_single", function()
		for i = 1, N do
			ecs:Remove(entities[i], A)
		end
	end)
end

do -- // Multi-component operations
	local ecs = yumina.new()
	local entities = {}
	local comps = { 1, 2, 3, 4 }

	for i = 1, N do
		entities[i] = ecs:Entity()
	end

	bench.CASE("add_multi", function()
		for i = 1, N do
			for _, comp in comps do
				ecs:Set(entities[i], comp, 1)
			end
		end
	end)

	bench.CASE("has_multi", function()
		for i = 1, N do
			for _, comp in comps do
				local _ = ecs:Has(entities[i], comp)
			end
		end
	end)

	bench.CASE("set_multi", function()
		for i = 1, N do
			for _, comp in comps do
				ecs:Set(entities[i], comp, 2)
			end
		end
	end)

	bench.CASE("remove_multi", function()
		for i = 1, N do
			for _, comp in comps do
				ecs:Remove(entities[i], comp)
			end
		end
	end)
end

do -- // Get operations with different component counts
	local ecs = yumina.new()
	local entities = {}
	local A, B, C, D = 1, 2, 3, 4

	for i = 1, N do
		local entity = ecs:Entity()
		entities[i] = entity
		ecs:Set(entity, A, 1)
		ecs:Set(entity, B, 1)
		ecs:Set(entity, C, 1)
		ecs:Set(entity, D, 1)
	end

	bench.CASE("get_one", function()
		for i = 1, N do
			local _ = ecs:Has(entities[i], A)
		end
	end)

	bench.CASE("get_two", function()
		for i = 1, N do
			local _, _ = ecs:Has(entities[i], A), ecs:Has(entities[i], B)
		end
	end)

	bench.CASE("get_four", function()
		for i = 1, N do
			local _, _, _, _ =
				ecs:Has(entities[i], A), ecs:Has(entities[i], B), ecs:Has(entities[i], C), ecs:Has(entities[i], D)
		end
	end)
end

do -- // Query benchmarks with different component combinations
	local ecs = yumina.new()
	local A, B, C, D = 1, 2, 3, 4

	for _ = 1, N do
		local entity = ecs:Entity()
		ecs:Set(entity, A, 1)
		ecs:Set(entity, B, 1)
		ecs:Set(entity, C, 1)
		ecs:Set(entity, D, 1)
	end

	bench.CASE("query_one", function()
		for _ in ecs:Query({ A }):View() do
		end
	end)

	bench.CASE("query_two", function()
		for _ in ecs:Query({ A, B }):View() do
		end
	end)

	bench.CASE("query_four", function()
		for _ in ecs:Query({ A, B, C, D }):View() do
		end
	end)

	bench.CASE("query_sparse", function()
		for _ in ecs:Query({ A, C, D }):View() do
		end
	end)
end

do -- // Query with data checks and retrieval
	local ecs = yumina.new()
	local A, B, C, D = 1, 2, 3, 4

	for _ = 1, N do
		local entity = ecs:Entity()
		ecs:Set(entity, A, 1)
		ecs:Set(entity, B, 1)
		ecs:Set(entity, C, 1)
		ecs:Set(entity, D, 1)
	end

	bench.CASE("query_with_data_one", function()
		for _, val in ecs:Query({ A }):View() do
			if val then
				local _ = val
			end
		end
	end)

	bench.CASE("query_with_data_four", function()
		for _ in ecs:Query({ A, B, C, D }):View() do
		end
	end)
end

do -- // Fragmentation benchmarks
	local function bench_fragmented_query(entities_per_archetype: number)
		bench.CASE("query_" .. entities_per_archetype .. "_per_archetype", function()
			local ecs = yumina.new()
			local A, B, C, D = 1, 2, 3, 4

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = ecs:Entity()
					ecs:Set(entity, A, true)
					ecs:Set(entity, B, true)
					ecs:Set(entity, C, true)
					ecs:Set(entity, D, true)
				end
			end

			for _, _, _, _, _ in ecs:Query({ A, B, C, D }):View() do
			end
		end)
	end

	for i = 13, 0, -1 do
		bench_fragmented_query(2 ^ i)
	end
end

do -- // Mixed operations
	bench.CASE("mixed_operations", function()
		local ecs = yumina.new()
		local A, B, C = 1, 2, 3

		for _ = 1, N do
			local entity = ecs:Entity()
			ecs:Set(entity, A, 1)
			ecs:Set(entity, B, 1)
			ecs:Remove(entity, A)
			ecs:Set(entity, C, 1)
			if ecs:Has(entity, C) then
				ecs:Set(entity, A, 2)
			end
			ecs:Remove(entity, B)
		end
	end)
end

bench.CASE("cleanup_benchmark", function()
	local ecs = yumina.new()
	local A, B = 1, 2

	for i = 1, N do
		local e = ecs:Entity()
		if i % 2 == 0 then
			ecs:Set(e, A, 1)
		end
		if i % 3 == 0 then
			ecs:Set(e, B, 1)
		end
		if i % 5 == 0 then
			ecs:Remove(e, A)
		end
	end

	ecs:Cleanup()
end)

RUN_ALL_BENCHMARKS()
