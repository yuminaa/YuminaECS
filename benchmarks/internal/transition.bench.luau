--!optimize 0
--!strict
--!native

local NUM_ENTITIES = 1000

local src_arch = {
	c_data = {
		numbers = table.create(NUM_ENTITIES),
		strings = table.create(NUM_ENTITIES),
		objects = table.create(NUM_ENTITIES),
	},
	entities = table.create(NUM_ENTITIES),
	e_row = {},
	e_n = NUM_ENTITIES,
}

for i = 1, NUM_ENTITIES do
	src_arch.c_data.numbers[i] = i * 1.5
	src_arch.c_data.strings[i] = "test" .. i
	src_arch.c_data.objects[i] = { x = i, y = i * 2 }
	src_arch.entities[i] = i
	src_arch.e_row[i] = i
end

local dest_arch = {
	c_data = {
		numbers = table.create(NUM_ENTITIES),
		strings = table.create(NUM_ENTITIES),
		objects = table.create(NUM_ENTITIES),
	},
	entities = table.create(NUM_ENTITIES),
	e_row = {},
	e_n = 0,
}

return {
	ParameterGenerator = function()
		return nil
	end,
	Functions = {
		["std"] = function(_)
			for entityId = 1, 100 do
				local from_row = src_arch.e_row[entityId]
				local to_row = dest_arch.e_n + 1

				dest_arch.c_data.numbers[to_row] = src_arch.c_data.numbers[from_row]
				dest_arch.c_data.strings[to_row] = src_arch.c_data.strings[from_row]
				dest_arch.c_data.objects[to_row] = src_arch.c_data.objects[from_row]

				dest_arch.entities[to_row] = entityId
				dest_arch.e_row[entityId] = to_row
				dest_arch.e_n = to_row
			end
		end,

		["fast path"] = function(_)
			local expectedSize = 100 + 32

			for entityId = 1, 100 do
				local from_row = src_arch.e_row[entityId]
				local to_row = dest_arch.e_n + 1

				if to_row >= #dest_arch.c_data.numbers then
					table.move(src_arch.c_data.numbers, from_row, from_row + expectedSize, 1, dest_arch.c_data.numbers)
					table.move(src_arch.c_data.strings, from_row, from_row + expectedSize, 1, dest_arch.c_data.strings)
					table.move(src_arch.c_data.objects, from_row, from_row + expectedSize, 1, dest_arch.c_data.objects)
				end

				dest_arch.c_data.numbers[to_row] = src_arch.c_data.numbers[from_row]
				dest_arch.c_data.strings[to_row] = src_arch.c_data.strings[from_row]
				dest_arch.c_data.objects[to_row] = src_arch.c_data.objects[from_row]

				dest_arch.entities[to_row] = entityId
				dest_arch.e_row[entityId] = to_row
				dest_arch.e_n = to_row
			end
		end,
		["local refs"] = function(_)
			local src_nums = src_arch.c_data.numbers
			local src_strs = src_arch.c_data.strings
			local src_objs = src_arch.c_data.objects
			local dest_nums = dest_arch.c_data.numbers
			local dest_strs = dest_arch.c_data.strings
			local dest_objs = dest_arch.c_data.objects
			local dest_ents = dest_arch.entities
			local dest_rows = dest_arch.e_row
			local src_rows = src_arch.e_row
			local e_n = dest_arch.e_n

			for entityId = 1, 100 do
				local from_row = src_rows[entityId]
				e_n += 1

				dest_nums[e_n] = src_nums[from_row]
				dest_strs[e_n] = src_strs[from_row]
				dest_objs[e_n] = src_objs[from_row]
				dest_ents[e_n] = entityId
				dest_rows[entityId] = e_n
			end
			dest_arch.e_n = e_n
		end,

		["batch move"] = function(_)
			local from_start = src_arch.e_row[1]
			local to_start = dest_arch.e_n + 1

			table.move(src_arch.c_data.numbers, from_start, from_start + 99, to_start, dest_arch.c_data.numbers)
			table.move(src_arch.c_data.strings, from_start, from_start + 99, to_start, dest_arch.c_data.strings)
			table.move(src_arch.c_data.objects, from_start, from_start + 99, to_start, dest_arch.c_data.objects)

			for i = 1, 100 do
				local dest_row = to_start + i - 1
				dest_arch.entities[dest_row] = i
				dest_arch.e_row[i] = dest_row
			end
			dest_arch.e_n = to_start + 99
		end,
	},
}
