--!optimize 0
--!strict
--!native

local band, bor, lshift, rshift = bit32.band, bit32.bor, bit32.lshift, bit32.rshift

local function pack_bits(a: number, b: number, c: number): (number, number)
	return band(bor(a, lshift(b, 21)), 0xFFFFFFFF), band(bor(rshift(b, 11), lshift(c, 10)), 0xFFFFFFFF)
end

local archetype = { 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF }
local include = { 0x0000FFFF, 0x0000FFFF, 0x0000FFFF }
local exclude = { 0xFFFF0000, 0xFFFF0000, 0xFFFF0000 }

local arch_low, arch_high = pack_bits(archetype[1], archetype[2], archetype[3])
local inc_low, inc_high = pack_bits(include[1], include[2], include[3])
local exc_low, exc_high = pack_bits(exclude[1], exclude[2], exclude[3])

return {
	ParameterGenerator = function()
		return nil
	end,

	Functions = {
		["pre-computed"] = function(_)
			local mask1 = band(archetype[1], include[1])
			local mask2 = band(archetype[2], include[2])
			local mask3 = band(archetype[3], include[3])

			for _ = 1, 1000 do
				local _ = mask1 == include[1]
					and mask2 == include[2]
					and mask3 == include[3]
					and band(archetype[1], exclude[1]) == 0
					and band(archetype[2], exclude[2]) == 0
					and band(archetype[3], exclude[3]) == 0
			end
		end,

		["packed"] = function(_)
			for _ = 1, 1000 do
				local _ = band(band(arch_low, inc_low), inc_low) == inc_low
					and band(band(arch_high, inc_high), inc_high) == inc_high
					and band(arch_low, exc_low) == 0
					and band(arch_high, exc_high) == 0
			end
		end,

		["vectorized"] = function(_)
			for _ = 1, 1000 do
				local low = band(arch_low, inc_low) == inc_low and band(arch_low, exc_low) == 0
				local high = band(arch_high, inc_high) == inc_high and band(arch_high, exc_high) == 0
				local _ = low and high
			end
		end,
	},
}
