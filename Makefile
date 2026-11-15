# Developer tasks. `make check` is what CI runs: format check, lint, type check, tests.
# Tools come from Mason (installed by the config itself) or from your PATH.
NVIM ?= nvim
DATA := $(shell $(NVIM) --headless -u NONE -i NONE "+lua io.write(vim.fn.stdpath('data'))" +qa 2>&1)
export PATH := $(DATA)/mason/bin:$(PATH)
LUA_DIRS := lua tests scripts
TEST_ENV := XDG_STATE_HOME=$(CURDIR)/.cache/state

.PHONY: check fmt fmt-check lint typecheck test

check: fmt-check lint typecheck test

fmt:
	stylua $(LUA_DIRS)

fmt-check:
	stylua --check $(LUA_DIRS)

lint:
	selene $(LUA_DIRS)

# lua-language-server with Neovim's runtime and the plugins whose API this config calls directly
typecheck:
	@mkdir -p .cache
	@$(NVIM) --headless -u NONE -i NONE -l scripts/luarc.lua "$(DATA)/lazy" > .cache/luarc.json
	lua-language-server --check . --configpath "$(CURDIR)/.cache/luarc.json" --checklevel=Warning --logpath .cache/luals

deps/mini.test:
	git clone --quiet --depth 1 https://github.com/nvim-mini/mini.test $@

test: deps/mini.test
	$(TEST_ENV) $(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"
