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

test: analyze
	@for file in $(TEST_FILES); do \
		echo "Running test: $$file"; \
		luau $$file -O0 --codegen || { echo "Test failed: $$file"; exit 1; }; \
	done
