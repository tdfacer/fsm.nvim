.PHONY: test lint format check clean

TESTS_DIR := tests
MINIMAL_INIT := $(TESTS_DIR)/minimal_init.lua

test:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedDirectory $(TESTS_DIR)/unit {minimal_init = '$(MINIMAL_INIT)'}"

test-integration:
	nvim --headless -u $(MINIMAL_INIT) -c "PlenaryBustedDirectory $(TESTS_DIR)/integration {minimal_init = '$(MINIMAL_INIT)'}"

test-all: test test-integration

lint:
	luacheck lua/ plugin/ tests/

format:
	stylua lua/ plugin/ tests/

check: lint
	stylua --check lua/ plugin/ tests/

clean:
	rm -rf .tests/
