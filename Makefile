.PHONY: test test-watch
test:
	@NVIM_APPNAME=writa nvim --headless --noplugin -u tests/minimal_init.lua \
	  -c "PlenaryBustedDirectory tests/projects/ { minimal_init = 'tests/minimal_init.lua' }" \
	  -c "qa!"

test-watch:
	@command -v entr >/dev/null 2>&1 || { echo "install 'entr'"; exit 1; }
	@find lua/plugins/writing/projects tests/projects -name '*.lua' | entr -c make test
