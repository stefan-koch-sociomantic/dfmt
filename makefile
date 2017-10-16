SRCS := $(shell find src -name "*.d") \
	$(shell find libdparse/src -name "*.d")
INCLUDE_PATHS := -Ilibdparse/src -Isrc
DMD_COMMON_FLAGS := -dip25 -w $(INCLUDE_PATHS)
DMD_DEBUG_FLAGS := -g $(DMD_COMMON_FLAGS)
DMD_FLAGS := -O -inline $(DMD_COMMON_FLAGS)
DMD_TEST_FLAGS := -unittest -g $(DMD_COMMON_FLAGS)
LDC_FLAGS := -g -w -oq $(INCLUDE_PATHS)
GDC_FLAGS := -g -w -oq $(INCLUDE_PATHS)
DC ?= dmd
LDC ?= ldc2
GDC ?= gdc

.PHONY: dmd ldc gdc test

dmd: bin/dfmt

ldc: $(SRCS)
	$(LDC) $(LDC_FLAGS) $^ -ofbin/dfmt
	-rm -f *.o

gdc: $(SRCS)
	$(GDC) $(GDC_FLAGS) $^ -obin/dfmt

test: debug
	cd tests && ./test.sh

bin/dfmt-test: $(SRCS)
	$(DC) $(DMD_TEST_FLAGS) $^ -of$@

bin/dfmt: $(SRCS)
	$(DC) $(DMD_FLAGS) $^ -of$@

debug: $(SRCS)
	$(DC) $(DMD_DEBUG_FLAGS) $^ -ofbin/dfmt

pkg: dmd
	$(MAKE) -f makd/Makd.mak pkg

clean:
	@rm -rf bin/dfmt

