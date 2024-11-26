--!native
--!optimize 0
--!strict

type Test = {
	suite: string,
	name: string,
	fn: () -> (),
	timeout: number?,
}

type BenchmarkStats = {
	min: number,
	max: number,
	mean: number,
	stdDev: number,
	median: number,
	p90: number,
}

type BenchmarkResult = {
	iterations: number,
	time: BenchmarkStats,
	memory: BenchmarkStats,
	bandwidth: BenchmarkStats,
	totalBytes: number,
}

type BenchmarkCase = {
	label: string,
	fn: () -> (),
	results: BenchmarkResult?,
}

type Benchmark = {
	suite: string,
	name: string,
	cases: { BenchmarkCase },
}

local tests: { Test } = {}
local benchmarks: { Benchmark } = {}

local ITERATIONS = 10
local WARMUP_ITERATIONS = 2

local COLOR = {
	RESET = "\27[0m",
	BOLD = "\27[1m",
	RED = "\27[31m",
	GREEN = "\27[32m",
	YELLOW = "\27[33m",
	BLUE = "\27[34m",
	MAGENTA = "\27[35m",
	CYAN = "\27[36m",
	GRAY = "\27[90m",
}

local function COLOR_TEXT(color: string, text: string): string
	return color .. text .. COLOR.RESET
end

-- Assertion Functions
local function ASSERT_EQ<T>(actual: T, expected: T): ()
	if actual ~= expected then
		error(string.format("ASSERT_EQ failed: Expected: %s, Actual: %s", tostring(expected), tostring(actual)), 2)
	end
end

local function ASSERT_NE<T>(actual: T, expected: T): ()
	if actual == expected then
		error(
			string.format("ASSERT_NE failed: Expected %s to be different from %s", tostring(expected), tostring(actual)),
			2
		)
	end
end

local function ASSERT_TRUE<T>(condition: T): ()
	if not condition then
		error("ASSERT_TRUE failed: Condition is false", 2)
	end
end

local function ASSERT_FALSE<T>(condition: T): ()
	if condition then
		error("ASSERT_FALSE failed: Condition is true", 2)
	end
end

local function ASSERT_LT(actual: number, expected: number): ()
	if actual >= expected then
		error(
			string.format("ASSERT_LT failed: Expected %s to be less than %s", tostring(actual), tostring(expected)),
			2
		)
	end
end

local function ASSERT_LE(actual: number, expected: number): ()
	if actual > expected then
		error(
			string.format(
				"ASSERT_LE failed: Expected %s to be less than or equal to %s",
				tostring(actual),
				tostring(expected)
			),
			2
		)
	end
end

local function ASSERT_GT(actual: number, expected: number): ()
	if actual <= expected then
		error(
			string.format("ASSERT_GT failed: Expected %s to be greater than %s", tostring(actual), tostring(expected)),
			2
		)
	end
end

local function ASSERT_GE(actual: number, expected: number): ()
	if actual < expected then
		error(
			string.format(
				"ASSERT_GE failed: Expected %s to be greater than or equal to %s",
				tostring(actual),
				tostring(expected)
			),
			2
		)
	end
end

local function ASSERT_NEAR(actual: number, expected: number, tolerance: number): ()
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"ASSERT_NEAR failed: Expected %s to be within %s of %s",
				tostring(actual),
				tostring(tolerance),
				tostring(expected)
			),
			2
		)
	end
end

local function PRINT_HEADER(text: string, char: string?)
	char = char or "="
	local width = 80
	local padding = width - #text - 2
	local left = math.floor(padding / 2)
	local right = padding - left

	print(
		"\n"
			.. COLOR_TEXT(
				COLOR.BOLD .. COLOR.CYAN,
				(char or "="):rep(left) .. " " .. text .. " " .. (char or "="):rep(right)
			)
	)
end

local function PRINT_TABLE_HEADER()
	local headers = {
		{ "Benchmark", "32" },
		{ "Time", "12" },
		{ "CPU", "12" },
		{ "Memory", "16" },
		{ "Bandwidth", "16" },
	}

	local headerLine = ""
	for _, header in headers do
		headerLine ..= string.format("%-" .. header[2] .. "s", header[1])
	end
	print(COLOR_TEXT(COLOR.BOLD .. COLOR.BLUE, headerLine))
	print(COLOR_TEXT(COLOR.GRAY, string.rep("-", 80)))
end

local function TEST_F(test_suite: string, test_name: string, timeout: number?): (callback: () -> ()) -> ()
	return function(callback: () -> ()): ()
		table.insert(tests, { suite = test_suite, name = test_name, fn = callback, timeout = timeout })
	end
end

local function RUN_ALL_TESTS(): ()
	local passed = 0
	local failed = 0
	local timeout_count = 0

	PRINT_HEADER("Running Tests")

	local current_suite = ""
	for _, t in tests do
		if current_suite ~= t.suite then
			if current_suite ~= "" then
				print("")
			end
			print(COLOR_TEXT(COLOR.CYAN, t.suite))
			current_suite = t.suite
		end

		print(COLOR_TEXT(COLOR.GRAY, string.format("[ RUN      ] %s.%s", t.suite, t.name)))

		local start_time = os.clock()
		local test_thread = coroutine.create(function()
			t.fn()
		end)

		local success, err
		local is_timeout = false

		if t.timeout then
			local timeout_time = start_time + t.timeout
			while coroutine.status(test_thread) ~= "dead" do
				success, err = coroutine.resume(test_thread)
				if os.clock() > timeout_time then
					is_timeout = true
					break
				end
			end
		else
			success, err = coroutine.resume(test_thread)
		end

		local duration = os.clock() - start_time

		if is_timeout then
			print(COLOR_TEXT(COLOR.YELLOW, string.format("[  TIMEOUT ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			timeout_count += 1
		elseif success then
			print(COLOR_TEXT(COLOR.GREEN, string.format("[       OK ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			passed += 1
		else
			print(COLOR_TEXT(COLOR.RED, string.format("[  FAILED  ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			if err then
				print(COLOR_TEXT(COLOR.RED, string.format("        %s", err)))
			end
			failed += 1
		end
	end

	PRINT_HEADER("Test Summary")
	print(string.format("    Total:    %d", #tests))
	print(string.format("    Passed:   %s", COLOR_TEXT(COLOR.GREEN, tostring(passed))))
	print(string.format("    Failed:   %s", COLOR_TEXT(COLOR.RED, tostring(failed))))
	print(string.format("    Timeouts: %s", COLOR_TEXT(COLOR.YELLOW, tostring(timeout_count))))
	print("")

	if failed > 0 or timeout_count > 0 then
		print(COLOR_TEXT(COLOR.RED, "FAILURE"))
	else
		print(COLOR_TEXT(COLOR.GREEN, "SUCCESS"))
	end
	print("")
end

local function calculateStats(samples: { number }): BenchmarkStats
	table.sort(samples)

	local sum = 0
	local min = samples[1]
	local max = samples[#samples]

	for _, value in samples do
		sum += value
	end

	local mean = sum / #samples
	local sumSquaredDiff = 0

	for _, value in samples do
		local diff = value - mean
		sumSquaredDiff += diff * diff
	end

	local median = samples[math.floor(#samples / 2)]
	local p90Index = math.floor(#samples * 0.9)
	local p90 = samples[p90Index]

	return {
		min = min,
		max = max,
		mean = mean,
		stdDev = math.sqrt(sumSquaredDiff / (#samples - 1)),
		median = median,
		p90 = p90,
	}
end

-- Formatting Functions
local function FORMAT_TIME(duration: number): (string, string)
	if duration >= 1 then
		return string.format("%.3f", duration), "s"
	elseif duration >= 0.001 then
		return string.format("%.3f", duration * 1000), "ms"
	else
		return string.format("%.3f", duration * 1000000), "µs"
	end
end

local function FORMAT_BYTES(bytes: number): string
	if bytes >= 1024 * 1024 * 1024 then
		return string.format("%.2f GiB", bytes / (1024 * 1024 * 1024))
	elseif bytes >= 1024 * 1024 then
		return string.format("%.2f MiB", bytes / (1024 * 1024))
	elseif bytes >= 1024 then
		return string.format("%.2f KiB", bytes / 1024)
	else
		return string.format("%d B", bytes)
	end
end

local function FORMAT_BANDWIDTH(bytesPerSecond: number): string
	return FORMAT_BYTES(bytesPerSecond) .. "/s"
end

local function FORMAT_STATS(stats: BenchmarkStats, formatter: (n: number) -> string): string
	return string.format(
		"%s (±%s) [%s-%s] p90:%s",
		formatter(stats.mean),
		formatter(stats.stdDev),
		formatter(stats.min),
		formatter(stats.max),
		formatter(stats.p90)
	)
end

local function BENCHMARK_F(bench_suite: string, bench_name: string): { CASE: (label: string, fn: () -> ()) -> () }
	local suiteCases = {}

	local function CASE(label: string, fn: () -> ()): ()
		table.insert(suiteCases, { label = label, fn = fn, results = nil })
	end

	table.insert(benchmarks, { suite = bench_suite, name = bench_name, cases = suiteCases })
	return { CASE = CASE }
end

local function RUN_BENCHMARK_CASE(case: BenchmarkCase): BenchmarkResult
	local times = table.create(ITERATIONS)
	local memories = table.create(ITERATIONS)
	local bandwidths = table.create(ITERATIONS)
	local totalBytes = 0

	for _ = 1, WARMUP_ITERATIONS do
		case.fn()
	end

	for i = 1, ITERATIONS do
		local startMemory = gcinfo() * 1024
		local startTime = os.clock()

		case.fn()

		local endTime = os.clock()
		local endMemory = gcinfo() * 1024

		local duration = endTime - startTime
		local memoryDelta = endMemory - startMemory
		local bandwidth = duration > 0 and math.abs(memoryDelta) / duration or 0

		times[i] = duration
		memories[i] = memoryDelta
		bandwidths[i] = bandwidth
		totalBytes += memoryDelta
	end

	return {
		iterations = ITERATIONS,
		time = calculateStats(times),
		memory = calculateStats(memories),
		bandwidth = calculateStats(bandwidths),
		totalBytes = totalBytes,
	}
end

local function FORMAT_RESULT_LINE(label: string, result: BenchmarkResult): string
	local timeColor = COLOR.GREEN
	if result.time.mean >= 1 then
		timeColor = COLOR.RED
	elseif result.time.mean >= 0.1 then
		timeColor = COLOR.YELLOW
	end

	local memoryColor = COLOR.GREEN
	if result.memory.mean >= 1024 * 1024 * 100 then
		memoryColor = COLOR.RED
	elseif result.memory.mean >= 1024 * 1024 * 10 then
		memoryColor = COLOR.YELLOW
	end

	return string.format(
		"%-32s%s%s%s",
		COLOR_TEXT(COLOR.BOLD, label),
		COLOR_TEXT(timeColor, " " .. FORMAT_STATS(result.time, function(n)
			local str, unit = FORMAT_TIME(n)
			return str .. unit
		end)),
		COLOR_TEXT(memoryColor, " " .. FORMAT_STATS(result.memory, FORMAT_BYTES)),
		COLOR_TEXT(COLOR.CYAN, " " .. FORMAT_STATS(result.bandwidth, FORMAT_BANDWIDTH))
	)
end

local function RUN_ALL_BENCHMARKS(): ()
	PRINT_HEADER("Running Benchmark Suite")

	local totalResults = {}
	local benchCount = 0

	for _, benchmark in benchmarks do
		PRINT_HEADER(
			string.format(
				"Benchmark Suite: %s::%s",
				COLOR_TEXT(COLOR.MAGENTA, benchmark.suite),
				COLOR_TEXT(COLOR.MAGENTA, benchmark.name)
			),
			"-"
		)

		PRINT_TABLE_HEADER()

		for _, case in benchmark.cases do
			print(COLOR_TEXT(COLOR.GRAY, string.format("Running %d iterations of %s...", ITERATIONS, case.label)))

			local result = RUN_BENCHMARK_CASE(case)
			case.results = result
			table.insert(totalResults, result)
			benchCount += 1

			print(FORMAT_RESULT_LINE(case.label, result))
		end

		print(COLOR_TEXT(COLOR.GRAY, string.rep("-", 120)) .. "\n")
	end

	local times = table.create(benchCount)
	local memories = table.create(benchCount)
	local bandwidths = table.create(benchCount)
	local totalBytes = 0

	for i, result in totalResults do
		times[i] = result.time.mean
		memories[i] = result.memory.mean
		bandwidths[i] = result.bandwidth.mean
		totalBytes += result.totalBytes
	end

	local timeStats = calculateStats(times)
	local memoryStats = calculateStats(memories)
	local bandwidthStats = calculateStats(bandwidths)

	PRINT_HEADER("Benchmark Summary")
	print(COLOR_TEXT(COLOR.BOLD, string.format("Total Benchmarks: %d", benchCount)))
	print(COLOR_TEXT(COLOR.BOLD, string.format("Total Iterations: %d", benchCount * ITERATIONS)))
	print(COLOR_TEXT(COLOR.BOLD, "Time: " .. FORMAT_STATS(timeStats, function(n)
		local str, unit = FORMAT_TIME(n)
		return str .. unit
	end)))
	print(COLOR_TEXT(COLOR.BOLD, "Memory: " .. FORMAT_STATS(memoryStats, FORMAT_BYTES)))
	print(COLOR_TEXT(COLOR.BOLD, "Bandwidth: " .. FORMAT_STATS(bandwidthStats, FORMAT_BANDWIDTH)))
	print(COLOR_TEXT(COLOR.BOLD, "Total Memory: " .. FORMAT_BYTES(totalBytes)))
	print(COLOR_TEXT(COLOR.GRAY, string.rep("=", 120)) .. "\n")
end

return table.freeze({
	ASSERT_EQ = ASSERT_EQ,
	ASSERT_GE = ASSERT_GE,
	ASSERT_GT = ASSERT_GT,
	ASSERT_LE = ASSERT_LE,
	ASSERT_LT = ASSERT_LT,
	ASSERT_NE = ASSERT_NE,
	ASSERT_NEAR = ASSERT_NEAR,
	ASSERT_TRUE = ASSERT_TRUE,
	ASSERT_FALSE = ASSERT_FALSE,

	TEST_F = TEST_F,
	BENCHMARK_F = BENCHMARK_F,
	RUN_ALL_TESTS = RUN_ALL_TESTS,
	RUN_ALL_BENCHMARKS = RUN_ALL_BENCHMARKS,
})
