local jecs = require("@jecs")
local test_runner = require("@test_runner")
local yumina = require("@yumina")

local BENCHMARK_F, RUN_ALL_BENCHMARKS = test_runner.BENCHMARK_F, test_runner.RUN_ALL_BENCHMARKS

local N = 2 ^ 16

local jecs_setup = jecs.World.new()
local JECS_A = jecs_setup:component() :: jecs.Entity<number>
local JECS_B = jecs_setup:component() :: jecs.Entity<number>
local JECS_C = jecs_setup:component() :: jecs.Entity<number>
local JECS_D = jecs_setup:component() :: jecs.Entity<number>

local YUMINA_A = 1
local YUMINA_B = 2
local YUMINA_C = 3
local YUMINA_D = 4

local bench = BENCHMARK_F("ecs-comparison", "core")

do
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

do
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()
	local jecs_entities, yumina_entities = {}, {}

	for i = 1, N do
		jecs_entities[i] = jecs_world:entity()
		yumina_entities[i] = yumina_world:Entity()
	end

	bench.CASE("jecs_add_single", function()
		for i = 1, N do
			jecs_world:set(jecs_entities[i], JECS_A, 1)
		end
	end)

	bench.CASE("yumina_add_single", function()
		for i = 1, N do
			yumina_world:Set(yumina_entities[i], YUMINA_A, 1)
		end
	end)

	bench.CASE("jecs_set_single", function()
		for i = 1, N do
			jecs_world:set(jecs_entities[i], JECS_A, 2)
		end
	end)

	bench.CASE("yumina_set_single", function()
		for i = 1, N do
			yumina_world:Set(yumina_entities[i], YUMINA_A, 2)
		end
	end)

	bench.CASE("jecs_has_single", function()
		for i = 1, N do
			local _ = jecs_world:has(jecs_entities[i], JECS_A)
		end
	end)

	bench.CASE("yumina_has_single", function()
		for i = 1, N do
			local _ = yumina_world:Has(yumina_entities[i], YUMINA_A)
		end
	end)

	bench.CASE("jecs_remove_single", function()
		for i = 1, N do
			jecs_world:remove(jecs_entities[i], JECS_A)
		end
	end)

	bench.CASE("yumina_remove_single", function()
		for i = 1, N do
			yumina_world:Remove(yumina_entities[i], YUMINA_A)
		end
	end)
end

do
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()
	local jecs_entities, yumina_entities = {}, {}

	for i = 1, N do
		jecs_entities[i] = jecs_world:entity()
		yumina_entities[i] = yumina_world:Entity()
	end

	bench.CASE("jecs_add_multi", function()
		for i = 1, N do
			jecs_world:set(jecs_entities[i], JECS_A, 1)
			jecs_world:set(jecs_entities[i], JECS_B, 1)
			jecs_world:set(jecs_entities[i], JECS_C, 1)
			jecs_world:set(jecs_entities[i], JECS_D, 1)
		end
	end)

	bench.CASE("yumina_add_multi", function()
		for i = 1, N do
			yumina_world:Set(yumina_entities[i], YUMINA_A, 1)
			yumina_world:Set(yumina_entities[i], YUMINA_B, 1)
			yumina_world:Set(yumina_entities[i], YUMINA_C, 1)
			yumina_world:Set(yumina_entities[i], YUMINA_D, 1)
		end
	end)

	bench.CASE("jecs_query_multi", function()
		for _, _, _, _ in jecs_world:query(JECS_A, JECS_B, JECS_C, JECS_D):iter() do
		end
	end)

	bench.CASE("yumina_query_multi", function()
		for _, _, _, _ in yumina_world:Query({ YUMINA_A, YUMINA_B, YUMINA_C, YUMINA_D }):View() do
		end
	end)
end

do
	local jecs_world = jecs.World.new()
	local yumina_world = yumina.new()

	for _ = 1, N do
		local jecs_entity = jecs_world:entity()
		local yumina_entity = yumina_world:Entity()

		jecs_world:set(jecs_entity, JECS_A, 1)
		jecs_world:set(jecs_entity, JECS_B, 1)
		jecs_world:set(jecs_entity, JECS_C, 1)
		jecs_world:set(jecs_entity, JECS_D, 1)

		yumina_world:Set(yumina_entity, YUMINA_A, 1)
		yumina_world:Set(yumina_entity, YUMINA_B, 1)
		yumina_world:Set(yumina_entity, YUMINA_C, 1)
		yumina_world:Set(yumina_entity, YUMINA_D, 1)
	end

	bench.CASE("jecs_query_one", function()
		for _ in jecs_world:query(JECS_A):iter() do
		end
	end)

	bench.CASE("yumina_query_one", function()
		for _ in yumina_world:Query({ YUMINA_A }):View() do
		end
	end)

	bench.CASE("jecs_query_four", function()
		for _ in jecs_world:query(JECS_A, JECS_B, JECS_C, JECS_D):iter() do
		end
	end)

	bench.CASE("yumina_query_four", function()
		for _ in yumina_world:Query({ YUMINA_A, YUMINA_B, YUMINA_C, YUMINA_D }):View() do
		end
	end)
end

do
	local function bench_fragmented_query(entities_per_archetype: number)
		bench.CASE("jecs_query_" .. entities_per_archetype .. "_per_archetype", function()
			local world = jecs.World.new()

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = world:entity()
					world:set(entity, JECS_A, 1)
					world:set(entity, JECS_B, 1)
					world:set(entity, JECS_C, 1)
					world:set(entity, JECS_D, 1)
				end
			end

			for _, _, _, _ in world:query(JECS_A, JECS_B, JECS_C, JECS_D):iter() do
			end
		end)

		bench.CASE("yumina_query_" .. entities_per_archetype .. "_per_archetype", function()
			local ecs = yumina.new()

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = ecs:Entity()
					ecs:Set(entity, YUMINA_A, 1)
					ecs:Set(entity, YUMINA_B, 1)
					ecs:Set(entity, YUMINA_C, 1)
					ecs:Set(entity, YUMINA_D, 1)
				end
			end

			for _, _, _, _ in ecs:Query({ YUMINA_A, YUMINA_B, YUMINA_C, YUMINA_D }):View() do
			end
		end)
	end

	for i = 13, 0, -1 do
		bench_fragmented_query(2 ^ i)
	end
end

do
	local function create_sparse_world(density: number)
		bench.CASE("jecs_sparse_query_" .. density, function()
			local world = jecs.World.new()

			for _ = 1, N do
				local entity = world:entity()
				if math.random() < density then
					world:set(entity, JECS_A, 1)
				end
				if math.random() < density then
					world:set(entity, JECS_B, 1)
				end
				if math.random() < density then
					world:set(entity, JECS_C, 1)
				end
				if math.random() < density then
					world:set(entity, JECS_D, 1)
				end
			end

			for _, _, _, _ in world:query(JECS_A, JECS_B, JECS_C, JECS_D):iter() do
			end
		end)

		bench.CASE("yumina_sparse_query_" .. density, function()
			local ecs = yumina.new()

			for _ = 1, N do
				local entity = ecs:Entity()
				if math.random() < density then
					ecs:Set(entity, YUMINA_A, true)
				end
				if math.random() < density then
					ecs:Set(entity, YUMINA_B, true)
				end
				if math.random() < density then
					ecs:Set(entity, YUMINA_C, true)
				end
				if math.random() < density then
					ecs:Set(entity, YUMINA_D, true)
				end
			end

			for _, _, _, _ in ecs:Query({ YUMINA_A, YUMINA_B, YUMINA_C, YUMINA_D }):View() do
			end
		end)
	end

	create_sparse_world(0.25)
	create_sparse_world(0.50)
	create_sparse_world(0.75)
end

do
	bench.CASE("jecs_mixed_operations", function()
		local world = jecs.World.new()

		for _ = 1, N do
			local entity = world:entity()
			world:set(entity, JECS_A, 1)
			world:set(entity, JECS_B, 1)
			world:remove(entity, JECS_A)
			world:set(entity, JECS_C, 1)
			if world:has(entity, JECS_C) then
				world:set(entity, JECS_A, 2)
			end
			world:remove(entity, JECS_B)
		end
	end)

	bench.CASE("yumina_mixed_operations", function()
		local ecs = yumina.new()

		for _ = 1, N do
			local entity = ecs:Entity()
			ecs:Set(entity, YUMINA_A, 1)
			ecs:Set(entity, YUMINA_B, 1)
			ecs:Remove(entity, YUMINA_A)
			ecs:Set(entity, YUMINA_C, 1)
			if ecs:Has(entity, YUMINA_C) then
				ecs:Set(entity, YUMINA_A, 2)
			end
			ecs:Remove(entity, YUMINA_B)
		end
	end)
end

RUN_ALL_BENCHMARKS()
