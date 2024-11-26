--!optimize 0
--!strict
--!native

local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

local function get_c_bits(ccomponent_id: number): (number, number)
	return rshift(ccomponent_id - 1, 5) + 1, band(ccomponent_id - 1, 0x1F)
end

local function pack_arch_bits(a: number, b: number, c: number): (number, number)
	return bor(band(a, 0xFFFFFFFF), lshift(band(b, 0xFFFFFFFF), 32)),
		bor(rshift(b, 32), lshift(band(c, 0xFFFFFFFF), 32))
end

local bitmasks = { 0xFF00FF, 0x00FF00, 0xFF00FF }
local low, high = pack_arch_bits(bitmasks[1], bitmasks[2], bitmasks[3])

return {
	ParameterGenerator = function()
		return nil
	end,

	Functions = {
		["std"] = function(_)
			for i = 1, 1000 do
				local mask_i, bit_pos = get_c_bits(i % 32 + 1)
				local mask = lshift(1, bit_pos)
				local new_bits = {
					bitmasks[1],
					bitmasks[2],
					bitmasks[3],
				}
				new_bits[mask_i] = bor(new_bits[mask_i], mask)
			end
		end,

		["packed"] = function(_)
			for i = 1, 1000 do
				local mask_i, bit_pos = get_c_bits(i % 32 + 1)
				local mask = lshift(1, bit_pos)
				if mask_i == 1 then
					low = bor(low, mask)
				elseif mask_i == 2 then
					local split = lshift(mask, 21)
					low = bor(low, band(split, 0xFFFFFFFF))
					high = bor(high, band(rshift(split, 32), 0xFFFFFFFF))
				else
					high = bor(high, lshift(mask, 10))
				end
			end
		end,

		["pre-computed"] = function(_)
			local masks = {}
			for i = 1, 32 do
				local mask_i, bit_pos = get_c_bits(i)
				masks[i] = { mask_i, lshift(1, bit_pos) }
			end

			for i = 1, 1000 do
				local comp = i % 32 + 1
				local mask_i, mask = masks[comp][1], masks[comp][2]
				local new_bits = {
					bitmasks[1],
					bitmasks[2],
					bitmasks[3],
				}
				new_bits[mask_i] = bor(new_bits[mask_i], mask)
			end
		end,
	},
}
