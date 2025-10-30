MAKEFLAGS += --silent

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
             --quiet \
             -MAKEFLAGS --quiet \
			 --cc --exe --build \
			 -j 0 \
			 -I$(RTL_DIR) -I$(RTL_SIM)
SIM_FLAGS  := +verilator+quiet
WAVE_FLAGS := --trace-fst

ifeq ($(WAVES), 1)
	COMP_FLAGS += $(WAVE_FLAGS)
endif

all: build_tests .WAIT run_tests

TEST_BUILDS := $(foreach f, $(basename $(notdir $(TESTS))), build_test_$(f))
build_tests: $(TEST_BUILDS)

create_test_dir:
	mkdir -p build
	mkdir -p build/waves

build_test_%: create_test_dir
	rtl_src=""; \
	if [ -f "$(RTL_DIR)$*.sv" ]; then \
		rtl_src="$(RTL_DIR)$*.sv"; \
	elif [ -f "$(RTL_TEST)$*.sv" ]; then \
		rtl_src="$(RTL_TEST)$*.sv"; \
	else \
		echo "Error: No RTL found for $* in $(RTL_DIR) or $(RTL_TEST)"; \
		exit 1; \
	fi; \
	echo "Compiling test $*"; \
	$(VERILATOR) \
		--Mdir $(BUILD_DIR)$* \
		$(COMP_FLAGS) \
		$$rtl_src \
		$(TEST_DIR)$*.cpp; \

TEST_RUNS := $(foreach f, $(basename $(notdir $(TESTS))), run_test_$(f))
run_tests: $(TEST_RUNS)

run_test_%:
	echo "Running test $*"; \
	$(BUILD_DIR)$*/V$* $(SIM_FLAGS); \
	echo "Finished test $*"; \

clean:
	@rm -rf $(BUILD_DIR)

-include $(DEPS)
