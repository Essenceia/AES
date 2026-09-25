PROJECT_NAME=aes_compact

WAIVER_FILE := conf/waiver.vlt
SRC_DIR=src

RTL_DEPS+=$(wildcard $(SRC_DIR)/*.v)

LINT_FLAGS := -Wall -Wpedantic

lint: lint_aes lint_ghash
.PHONY: lint 

lint_aes:  
	verilator $(WAIVER_FILE) --lint-only $(LINT_FLAGS) --no-timing $(RTL_DEPS) --top aes_compact
.PHONY: lint_aes

lint_ghash:  
	verilator $(WAIVER_FILE) --lint-only $(LINT_FLAGS) --no-timing $(RTL_DEPS) --top ghash
.PHONY: lint_ghash

clean: 
	rm -r ./runs
	rm -r ./*config_merged.yaml
.PHONY:clean

