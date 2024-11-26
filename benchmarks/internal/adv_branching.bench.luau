--!optimize 0
--!strict
--!native

local values = table.create(256)
for i = 0, 255 do
	values[i] = math.random(0, 255)
end

return {
	ParameterGenerator = function()
		return nil
	end,
	
	Functions = {
		["if"] = function(_)
			local sum: number = 0
			for i: number = 1, 1000 do
				local val: number = values[i % 256]
				if val < 128 then
					sum = sum + 1
				end
			end
		end,
		
		["direct"] = function(_)
			local sum: number = 0
			for i: number = 1, 1000 do
				local val: number = values[i % 256]
				sum = sum + (val < 128 and 1 or 0)
			end
		end,
		
		["bitwise"] = function(_)
			local sum: number = 0
			for i: number = 1, 1000 do
				local val: number = values[i % 256]
				sum = sum + bit32.rshift(bit32.bnot(bit32.rshift(val, 7)), 31)
			end
		end,
		
		["index"] = function(_)
			local sum: number = 0
			for i: number = 1, 1000 do
				local val: number = values[i % 256]
				sum = sum + (values[val % 256] < 128 and 1 or 0)
			end
		end,
	},
}