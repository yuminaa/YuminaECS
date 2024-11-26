--!optimize 0
--!strict
--!native

local array = table.create(256)
local bits = 0
for i = 0, 255 do
	local val = math.random(0,1)
	array[i] = val < 0.5
	bits = bit32.bor(bits, bit32.lshift(val, bit32.band(i, 31)))
end

return {
	ParameterGenerator = function()
		return nil
	end,
	
	Functions = {
		["if"] = function(_)
			local sum = 0
			for _ = 1, 1000 do
				local val = bit32.band(bits, 0xFF)
				if val < 128 then
					sum = sum + 1
				end
			end
		end,
		
		["direct"] = function(_)
			local sum = 0
			for _ = 1, 1000 do
				local val = bit32.band(bits, 0xFF)
				sum = sum + (val < 128 and 1 or 0)
			end
		end,
		
		["bitwise"] = function(_)
			local sum = 0
			for _ = 1, 1000 do
				local val = bit32.band(bits, 0xFF)
				sum = sum + bit32.rshift(bit32.bnot(bit32.rshift(val, 7)), 31)
			end
		end,
		
		["index"] = function(_)
			local sum = 0
			for _ = 1, 1000 do
				local val = bit32.band(bits, 0xFF)
				sum = sum + (array[val] and 1 or 0)
			end
		end,
	},
}