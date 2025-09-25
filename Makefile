TEST_DIR  := tests/
BUILD_DIR := build/
RTL_DIR   := rtl/
SOURCES   := $(wildcard $(RTL_DIR)*.sv)
TESTS     := $(wildcard $(TEST_DIR)*.cpp)
DEPS      := $(wildcard $(BUILD_DIR)*.d)

VERILATOR  ?= verilator
COMP_FLAGS := -Wall --MMD --MP --cc --exe --build -j 0 --Mdir $(BUILD_DIR)
SIM_FLAGS  := +verilator+quiet

all: build run

build: $(TESTS)
	$(VERILATOR) $(SOURCES) $(COMP_FLAGS) $?

run: $(TESTS)
	@for src in $(basename $(notdir $(TESTS))); do \
        exec $(BUILD_DIR)V$(lastword $$src) $(SIM_FLAGS); \
		echo "Passed $(lastword $$src)"; \
    done

clean:
	@rm -rf $(BUILD_DIR)

-include $(DEPS)
