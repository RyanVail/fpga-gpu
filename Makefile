TEST_DIR  := tests/
BUILD_DIR := build/
RTL_DIR   := rtl/
RTL_TEST  := rtl/tests/
TESTS     := $(wildcard $(TEST_DIR)*.cpp)
DEPS      := $(wildcard $(BUILD_DIR)*.d)
WAVES     := 1

VERILATOR  ?= verilator
COMP_FLAGS := -Wall \
			 --MMD \
			 --MP \
			 --cc --exe --build \
			 -j 0 \
			 -I$(RTL_DIR) -I$(RTL_SIM)
SIM_FLAGS  := +verilator+quiet
WAVE_FLAGS := --trace-fst

ifeq ($(WAVES), 1)
	COMP_FLAGS += $(WAVE_FLAGS)
endif

all: build run

build: $(TESTS)
	mkdir -p build
	mkdir -p build/waves
	@for src in $(basename $(notdir $(TESTS))); do \
		rtl_src=""; \
		if [ -f "$(RTL_DIR)$$src.sv" ]; then \
			rtl_src="$(RTL_DIR)$$src.sv"; \
		elif [ -f "$(RTL_TEST)$$src.sv" ]; then \
			rtl_src="$(RTL_TEST)$$src.sv"; \
		else \
			echo "Error: No RTL found for $$src in $(RTL_DIR) or $(RTL_TEST)"; \
			exit 1; \
		fi; \
		echo "Compiling test $$src with RTL $$rtl_src"; \
		$(VERILATOR) \
			--Mdir $(BUILD_DIR)$$src \
			$(COMP_FLAGS) \
			$$rtl_src \
			$(TEST_DIR)$$src.cpp; \
	done

run: $(TESTS)
	@for src in $(basename $(notdir $(TESTS))); do \
		echo "Running test $$src"; \
		$(BUILD_DIR)$$src/V$$src $(SIM_FLAGS); \
	done

clean:
	@rm -rf $(BUILD_DIR)

-include $(DEPS)
