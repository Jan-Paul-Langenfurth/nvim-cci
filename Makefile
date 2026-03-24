LUA_PATH := ./lua/?.lua;./lua/?/init.lua;$(LUA_PATH)
export LUA_PATH

.PHONY: test lint

test:
	busted tests/spec/

lint:
	luacheck lua/
