NVIM ?= nvim
LUA_FILES := $(shell find lua -type f -name '*.lua' | sort)

.PHONY: check

check:
	@for file in $(LUA_FILES); do \
		$(NVIM) --headless --clean "+lua assert(loadfile('$$file'))" +qa; \
	done
