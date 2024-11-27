SHELL := /bin/bash

.PHONY: test

TEST_FILES = tests/entity.spec.luau \
	tests/query.spec.luau \
	tests/archetype.spec.luau \
	tests/relationship.spec.luau \
	tests/cache.spec.luau \
	tests/signal.spec.luau

analyze:
	luau-analyze --mode=strict --formatter=gnu yumina.luau

bench:
	luau benchmarks/bench.luau --codegen -O2 -g0

test: analyze
	@for file in $(TEST_FILES); do \
		echo "Running test: $$file"; \
		luau $$file -O0 --codegen || { echo "Test failed: $$file"; exit 1; }; \
	done

profile:
	luau benchmarks/bench.luau --profile=5000 -O2 --codegen -g0
	python3 tools/perfgraph.py profile.out > profile.svg && open profile.svg
	python3 tools/perfstat.py profile.out
