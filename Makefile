PROJECT_NAME=aes_compact

WAIVER_FILE := conf/waiver.vlt
SRC_DIR=src

RTL_DEPS+=$(wildcard $(SRC_DIR)/*.v)

LINT_FLAGS := -Wall -Wpedantic

lint:  
	verilator $(WAIVER_FILE) --lint-only $(LINT_FLAGS) --no-timing $(RTL_DEPS) --top $(PROJECT_NAME)
.PHONY: lint

clean: 
	rm -r ./runs
	rm -r ./*config_merged.yaml
.PHONY:clean

