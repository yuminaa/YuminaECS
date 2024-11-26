--!optimize 0
--!strict
--!native

local band, bor, bnot, lshift, rshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift, bit32.rshift

local function get_c_bits(component_id: number): (number, number)
	return rshift(component_id - 1, 5) + 1, band(component_id - 1, 0x1F)
end

local bitmasks = { 0xFF00FF, 0x00FF00, 0xFF00FF }
local low, high =
	band(bor(bitmasks[1], lshift(bitmasks[2], 21)), 0xFFFFFFFF),
	band(bor(rshift(bitmasks[2], 11), lshift(bitmasks[3], 10)), 0xFFFFFFFF)

return {
	ParameterGenerator = function()
		return nil
	end,

	Functions = {
		["current"] = function(_)
			for i = 1, 1000 do
				local mask_i, bit_pos = get_c_bits(i % 32 + 1)
				local mask = lshift(1, bit_pos)
				local newBits = { bitmasks[1], bitmasks[2], bitmasks[3] }
				newBits[mask_i] = band(newBits[mask_i], bnot(mask))
			end
		end,

		["packed"] = function(_)
			local test_l, test_h = low, high
			for i = 1, 1000 do
				local mask_i, bit_pos = get_c_bits(i % 32 + 1)
				local mask = lshift(1, bit_pos)
				if mask_i == 1 then
					test_l = band(test_l, bnot(mask))
				elseif mask_i == 2 then
					local split = lshift(mask, 21)
					test_l = band(test_l, bnot(band(split, 0xFFFFFFFF)))
					test_h = band(test_h, bnot(band(rshift(split, 32), 0xFFFFFFFF)))
				else
					test_h = band(test_h, bnot(lshift(mask, 10)))
				end
			end
		end,
	},
}
