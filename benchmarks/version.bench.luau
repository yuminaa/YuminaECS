local new_yumina = require("@yumina")
local old_yumina = require("@old_yumina")
local test_runner = require("@test_runner")

local BENCHMARK_F, RUN_ALL_BENCHMARKS = test_runner.BENCHMARK_F, test_runner.RUN_ALL_BENCHMARKS

local N = 2 ^ 16

local A = 1
local B = 2
local C = 3
local D = 4

local bench = BENCHMARK_F("yumina-comparison", "core")

do
	bench.CASE("old_world_entity-creation", function()
		local world = old_yumina.new()
		for i = 1, N do
			world:Entity()
		end
	end)
	bench.CASE("new_entity-creation", function()
		local world = new_yumina.new()
		for i = 1, N do
			world:Entity()
		end
	end)
end

do
	local old_world = old_yumina.new()
	local world = new_yumina.new()
	local old_entities, new_entities = {}, {}

	for i = 1, N do
		old_entities[i] = old_world:Entity()
		new_entities[i] = world:Entity()
	end

	bench.CASE("old_add-single", function()
		for i = 1, N do
			old_world:Set(old_entities[i], A, 1)
		end
	end)

	bench.CASE("new_add-single", function()
		for i = 1, N do
			world:Set(new_entities[i], A, 1)
		end
	end)

	bench.CASE("old_set-single", function()
		for i = 1, N do
			old_world:Set(old_entities[i], A, 2)
		end
	end)

	bench.CASE("new_set-single", function()
		for i = 1, N do
			world:Set(new_entities[i], A, 2)
		end
	end)

	bench.CASE("old_has-single", function()
		for i = 1, N do
			local _ = old_world:Has(old_entities[i], A)
		end
	end)

	bench.CASE("new_has-single", function()
		for i = 1, N do
			local _ = world:Has(new_entities[i], A)
		end
	end)

	bench.CASE("old_remove-single", function()
		for i = 1, N do
			old_world:Remove(old_entities[i], A)
		end
	end)

	bench.CASE("new_remove-single", function()
		for i = 1, N do
			world:Remove(new_entities[i], A)
		end
	end)
end

do
	local old_world = old_yumina.new()
	local world = new_yumina.new()
	local old_entities, new_entities = {}, {}

	for i = 1, N do
		old_entities[i] = old_world:Entity()
		new_entities[i] = world:Entity()
	end

	bench.CASE("old_add-multi", function()
		for i = 1, N do
			old_world:Set(old_entities[i], A, 1)
			old_world:Set(old_entities[i], B, 1)
			old_world:Set(old_entities[i], C, 1)
			old_world:Set(old_entities[i], D, 1)
		end
	end)

	bench.CASE("new_add-multi", function()
		for i = 1, N do
			world:Set(new_entities[i], A, 1)
			world:Set(new_entities[i], B, 1)
			world:Set(new_entities[i], C, 1)
			world:Set(new_entities[i], D, 1)
		end
	end)

	bench.CASE("old_query-multi", function()
		for _, _, _, _ in old_world:Query({ A, B, C, D }):View() do
		end
	end)

	bench.CASE("new_query-multi", function()
		for _, _, _, _ in world:Query({ A, B, C, D }):View() do
		end
	end)
end

do
	local old_world = old_yumina.new()
	local world = new_yumina.new()

	for _ = 1, N do
		local e = old_world:Entity()
		local entity = world:Entity()

		old_world:Set(e, A, 1)
		old_world:Set(e, B, 1)
		old_world:Set(e, C, 1)
		old_world:Set(e, D, 1)

		world:Set(entity, A, 1)
		world:Set(entity, B, 1)
		world:Set(entity, C, 1)
		world:Set(entity, D, 1)
	end

	bench.CASE("old_query-one", function()
		for _ in old_world:Query({ A }):View() do
		end
	end)

	bench.CASE("new_query-one", function()
		for _ in world:Query({ A }):View() do
		end
	end)

	bench.CASE("old_query-four", function()
		for _ in old_world:Query({ A, B, C, D }):View() do
		end
	end)

	bench.CASE("new_query-four", function()
		for _ in world:Query({ A, B, C, D }):View() do
		end
	end)
end

do
	local function bench_fragmented_query(entities_per_archetype: number)
		bench.CASE("new_query-" .. entities_per_archetype .. "-per-archetype", function()
			local world = old_yumina.new()

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = world:Entity()
					world:Set(entity, A, 1)
					world:Set(entity, B, 1)
					world:Set(entity, C, 1)
					world:Set(entity, D, 1)
				end
			end

			for _, _, _, _ in world:Query({ A, B, C, D }):View() do
			end
		end)

		bench.CASE("new_query-" .. entities_per_archetype .. "-per-archetype", function()
			local ecs = new_yumina.new()

			for _ = 1, N, entities_per_archetype do
				for _ = 1, entities_per_archetype do
					local entity = ecs:Entity()
					ecs:Set(entity, A, 1)
					ecs:Set(entity, B, 1)
					ecs:Set(entity, C, 1)
					ecs:Set(entity, D, 1)
				end
			end

			for _, _, _, _ in ecs:Query({ A, B, C, D }):View() do
			end
		end)
	end

	for i = 13, 0, -1 do
		bench_fragmented_query(2 ^ i)
	end
end

do
	local function create_sparse_world(density: number)
		bench.CASE("old_sparse-query-" .. density, function()
			local world = old_yumina.new()

			for _ = 1, N do
				local entity = world:Entity()
				if math.random() < density then
					world:Set(entity, A, 1)
				end
				if math.random() < density then
					world:Set(entity, B, 1)
				end
				if math.random() < density then
					world:Set(entity, C, 1)
				end
				if math.random() < density then
					world:Set(entity, D, 1)
				end
			end

			for _, _, _, _ in world:Query({ A, B, C, D }):View() do
			end
		end)

		bench.CASE("new_sparse-query-" .. density, function()
			local ecs = new_yumina.new()

			for _ = 1, N do
				local entity = ecs:Entity()
				if math.random() < density then
					ecs:Set(entity, A, true)
				end
				if math.random() < density then
					ecs:Set(entity, B, true)
				end
				if math.random() < density then
					ecs:Set(entity, C, true)
				end
				if math.random() < density then
					ecs:Set(entity, D, true)
				end
			end

			for _, _, _, _ in ecs:Query({ A, B, C, D }):View() do
			end
		end)
	end

	create_sparse_world(0.25)
	create_sparse_world(0.50)
	create_sparse_world(0.75)
end

do
	bench.CASE("old_mixed-operations", function()
		local world = old_yumina.new()

		for _ = 1, N do
			local entity = world:Entity()
			world:Set(entity, A, 1)
			world:Set(entity, B, 1)
			world:Remove(entity, A)
			world:Set(entity, C, 1)
			if world:Has(entity, C) then
				world:Set(entity, A, 2)
			end
			world:Remove(entity, B)
		end
	end)

	bench.CASE("new_mixed-operations", function()
		local ecs = new_yumina.new()

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
