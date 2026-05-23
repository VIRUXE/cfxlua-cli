# =============================================================================
# CfxLua CLI Orchestrator Makefile
# =============================================================================

.PHONY: all clean install package-linux package-windows package-deb

all:
	@if [ ! -d "core/libs/glm" ]; then \
		echo "Initializing submodules..."; \
		git submodule update --init --recursive; \
	fi
	$(MAKE) -C core linux-noreadline -j$$(nproc)

clean:
	@if [ -d "core" ]; then $(MAKE) -C core clean; fi
	rm -rf dist *.tar.gz *.zip *.deb build/

install:
	./install.sh

package-linux:
	./build_release.sh

package-deb:
	./build_deb.sh

package-windows:
	@if [ ! -d "core/libs/glm" ]; then \
		echo "Initializing submodules..."; \
		git submodule update --init --recursive; \
	fi
	# Cross-compiling for Windows
	$(MAKE) -C core clean
	$(MAKE) -C core CC="x86_64-w64-mingw32-g++ -std=c++11" CPP="x86_64-w64-mingw32-g++ -std=c++11" PLAT=mingw -j$$(nproc)
	# Package logic should be handled by build_release.sh or similar
	./build_release.sh
