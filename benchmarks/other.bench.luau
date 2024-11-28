local jecs = require("@jecs")
local test_runner = require("@test_runner")
local yumina = require("@yumina")

local BENCHMARK_F, RUN_ALL_BENCHMARKS = test_runner.BENCHMARK_F, test_runner.RUN_ALL_BENCHMARKS

local N = 2 ^ 16
local bench = BENCHMARK_F("ecs-comparison", "core")

do -- // Basic creation benchmarks
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()
	local jecs_entities, yumina_entities = {}, {}

	bench.CASE("jecs_entity_creation", function()
		for i = 1, N do
			jecs_entities[i] = jecs_world:entity()
		end
	end)

	bench.CASE("yumina_entity_creation", function()
		for i = 1, N do
			yumina_entities[i] = yumina_world:Entity()
		end
	end)
end

do -- // Single component operations
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()
	local jecs_entities, yumina_entities = {}, {}
	local jecs_A = jecs_world:component()
	local yumina_A = 1

	for i = 1, N do
		jecs_entities[i] = jecs_world:entity()
		yumina_entities[i] = yumina_world:Entity()
	end

	bench.CASE("jecs_add_single", function()
		for i = 1, N do
			jecs_world:set(jecs_entities[i], jecs_A, 1)
		end
	end)

	bench.CASE("yumina_add_single", function()
		for i = 1, N do
			yumina_world:Set(yumina_entities[i], yumina_A, 1)
		end
	end)

	bench.CASE("jecs_set_single", function()
		for i = 1, N do
			jecs_world:set(jecs_entities[i], jecs_A, 2)
		end
	end)

	bench.CASE("yumina_set_single", function()
		for i = 1, N do
			yumina_world:Set(yumina_entities[i], yumina_A, 2)
		end
	end)

	bench.CASE("jecs_has_single", function()
		for i = 1, N do
			local _ = jecs_world:has(jecs_entities[i], jecs_A)
		end
	end)

	bench.CASE("yumina_has_single", function()
		for i = 1, N do
			local _ = yumina_world:Has(yumina_entities[i], yumina_A)
		end
	end)

	bench.CASE("jecs_remove_single", function()
		for i = 1, N do
			jecs_world:remove(jecs_entities[i], jecs_A)
		end
	end)

	bench.CASE("yumina_remove_single", function()
		for i = 1, N do
			yumina_world:Remove(yumina_entities[i], yumina_A)
		end
	end)
end

do -- // Multi-component operations
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()
	local jecs_entities, yumina_entities = {}, {}

	local jecs_comps = {
		jecs_world:component(),
		jecs_world:component(),
		jecs_world:component(),
		jecs_world:component(),
	}
	local yumina_comps = { 1, 2, 3, 4 }

	for i = 1, N do
		jecs_entities[i] = jecs_world:entity()
		yumina_entities[i] = yumina_world:Entity()
	end

	bench.CASE("jecs_add_multi", function()
		for i = 1, N do
			for _, comp in jecs_comps do
				jecs_world:set(jecs_entities[i], comp, 1)
			end
		end
	end)

	bench.CASE("yumina_add_multi", function()
		for i = 1, N do
			for _, comp in yumina_comps do
				yumina_world:Set(yumina_entities[i], comp, 1)
			end
		end
	end)

	bench.CASE("jecs_query_multi", function()
		for _, _, _, _ in jecs_world:query(jecs_comps[1], jecs_comps[2], jecs_comps[3], jecs_comps[4]) do
		end
	end)

	bench.CASE("yumina_query_multi", function()
		for _, _, _, _ in
			yumina_world
				:Query({
					yumina_comps[1],
					yumina_comps[2],
					yumina_comps[3],
					yumina_comps[4],
				})
				:View()
		do
		end
	end)
end

do -- // Query with different component counts
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()

	local jecs_components = {
		A = jecs_world:component(),
		B = jecs_world:component(),
		C = jecs_world:component(),
		D = jecs_world:component(),
	}

	local yumina_components = {
		A = 1,
		B = 2,
		C = 3,
		D = 4,
	}

	for _ = 1, N do
		local jecs_entity = jecs_world:entity()
		local yumina_entity = yumina_world:Entity()

		for _, comp in jecs_components do
			jecs_world:set(jecs_entity, comp :: any, 1)
		end
		for _, comp in yumina_components do
			yumina_world:Set(yumina_entity, comp :: any, 1)
		end
	end

	bench.CASE("jecs_query_one", function()
		for _ in jecs_world:query(jecs_components.A) do
		end
	end)

	bench.CASE("yumina_query_one", function()
		for _ in yumina_world:Query({ yumina_components.A }) do
		end
	end)

	bench.CASE("jecs_query_four", function()
		for _ in jecs_world:query(jecs_components.A, jecs_components.B, jecs_components.C, jecs_components.D) do
		end
	end)

	bench.CASE("yumina_query_four", function()
		for _ in
			yumina_world
				:Query({
					yumina_components.A,
					yumina_components.B,
					yumina_components.C,
					yumina_components.D,
				})
				:View()
		do
		end
	end)
end

do -- // Fragmentation benchmarks
	local function bench_fragmented_query(entities_per_archetype: number)
		bench.CASE("jecs_query_" .. entities_per_archetype .. "_per_archetype", function()
			local world = jecs.World.new()
			local A = world:component()
			local B = world:component()
			local C = world:component()
			local D = world:component()

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = world:entity()
					world:set(entity, A, true)
					world:set(entity, B, true)
					world:set(entity, C, true)
					world:set(entity, D, true)
				end
			end

			for _, _, _, _ in world:query(A, B, C, D) do
			end
		end)

		bench.CASE("yumina_query_" .. entities_per_archetype .. "_per_archetype", function()
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

			for _, _, _, _ in ecs:Query({ A, B, C, D }):View() do
			end
		end)
	end

	-- Test different fragmentation levels
	for i = 13, 0, -1 do
		bench_fragmented_query(2 ^ i)
	end
end

do -- // Sparse component distribution
	local function create_sparse_world(density: number)
		bench.CASE("jecs_sparse_query_" .. density, function()
			local world = jecs.World.new()
			local comps = {
				world:component(),
				world:component(),
				world:component(),
				world:component(),
			}

			for _ = 1, N do
				local entity = world:entity()
				for _, comp in comps do
					if math.random() < density then
						world:set(entity, comp, true)
					end
				end
			end

			for _, _, _, _ in world:query(comps[1], comps[2], comps[3], comps[4]) do
			end
		end)

		bench.CASE("yumina_sparse_query_" .. density, function()
			local ecs = yumina.new()
			local comps = { 1, 2, 3, 4 }

			for _ = 1, N do
				local entity = ecs:Entity()
				for _, comp in comps do
					if math.random() < density then
						ecs:Set(entity, comp, true)
					end
				end
			end

			for _, _, _, _ in ecs:Query({ comps[1], comps[2], comps[3], comps[4] }):View() do
			end
		end)
	end

	create_sparse_world(0.25)
	create_sparse_world(0.50)
	create_sparse_world(0.75)
end

do -- // Mixed operations
	bench.CASE("jecs_mixed_operations", function()
		local world = jecs.World.new()
		local A = world:component()
		local B = world:component()
		local C = world:component()

		for _ = 1, N do
			local entity = world:entity()
			world:set(entity, A, 1)
			world:set(entity, B, 1)
			world:remove(entity, A)
			world:set(entity, C, 1)
			if world:has(entity, C) then
				world:set(entity, A, 2)
			end
			world:remove(entity, B)
		end
	end)

	bench.CASE("yumina_mixed_operations", function()
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

RUN_ALL_BENCHMARKS()
