--!native
--!optimize 0
--!strict

type Test = {
	suite: string,
	name: string,
	fn: () -> (),
	timeout: number?,
}

type Benchmark = {
	suite: string,
	name: string,
	cases: { { label: string, fn: () -> () } },
}

local tests: { Test } = {}
local benchmarks: { Benchmark } = {}

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

local function TEST_F(test_suite: string, test_name: string, timeout: number?): (callback: () -> ()) -> ()
	return function(callback: () -> ()): ()
		table.insert(tests, { suite = test_suite, name = test_name, fn = callback, timeout = timeout })
	end
end

local function COLOR_TEXT(colorCode: string, text: string): string
	return string.format("\27[%sm%s\27[0m", colorCode, text)
end

local function PRINT_HEADER(text: string)
	print(string.rep("=", 22) .. " " .. text .. " " .. string.rep("=", 23))
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
			print(t.suite)
			current_suite = t.suite
		end

		print(string.format("[ RUN      ] %s.%s", t.suite, t.name))

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
			print(COLOR_TEXT("33", string.format("[  TIMEOUT ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			timeout_count += 1
		elseif success then
			print(COLOR_TEXT("32", string.format("[       OK ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			passed += 1
		else
			print(COLOR_TEXT("31", string.format("[  FAILED  ] %s.%s (%.2fs)", t.suite, t.name, duration)))
			if err then
				print(string.format("        %s", err))
			end
			failed += 1
		end
	end

	print("")
	PRINT_HEADER("Test Summary")
	print(string.format("    Total:    %d", #tests))
	print(string.format("    Passed:   %s", COLOR_TEXT("32", tostring(passed))))
	print(string.format("    Failed:   %s", COLOR_TEXT("31", tostring(failed))))
	print(string.format("    Timeouts: %s", COLOR_TEXT("33", tostring(timeout_count))))
	print("")

	if failed > 0 or timeout_count > 0 then
		print(COLOR_TEXT("31", "FAILURE"))
	else
		print(COLOR_TEXT("32", "SUCCESS"))
	end
	print("")
end

local function BENCHMARK_F(bench_suite: string, bench_name: string): { CASE: (label: string, fn: () -> ()) -> () }
	local suiteCases = {}

	local function CASE(label: string, fn: () -> ()): ()
		table.insert(suiteCases, { label = label, fn = fn })
	end

	table.insert(benchmarks, { suite = bench_suite, name = bench_name, cases = suiteCases })

	return { CASE = CASE }
end

local function RUN_ALL_BENCHMARKS(): ()
	local totalBenchmarks = 0
	local totalTime = 0
	local totalMemory = 0

	print("\n========== Running Benchmarks ==========\n")

	for _, benchmark in benchmarks do
		print(string.format("Benchmark Suite: %s.%s", benchmark.suite, benchmark.name))

		for _, case in benchmark.cases do
			local startMemory = gcinfo()
			local startTime = os.clock()

			case.fn()

			local endTime = os.clock()
			local endMemory = gcinfo()

			local duration = endTime - startTime
			local memoryUsed = endMemory - startMemory

			local timeStr: string, unit: string
			if duration >= 1 then
				timeStr = string.format("%.3f", duration)
				unit = "s"
			elseif duration >= 0.001 then
				timeStr = string.format("%.3f", duration * 1000)
				unit = "ms"
			else
				timeStr = string.format("%.3f", duration * 1000000)
				unit = "µs"
			end

			print(string.format("[%s %s] Memory: %.2f KB", timeStr, unit, memoryUsed))

			totalBenchmarks += 1
			totalTime += duration
			totalMemory += memoryUsed
		end
	end

	print("\n========== Benchmark Summary ==========")
	print(string.format("Total Benchmarks Run: %d", totalBenchmarks))
	print(string.format("Average Time: %.3f ms", (totalTime / totalBenchmarks) * 1000))
	print(string.format("Average Memory Usage: %.2f KB", totalMemory / totalBenchmarks))
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
