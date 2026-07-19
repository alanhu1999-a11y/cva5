GUI ?= 1
TIME_LIMIT ?= 5m
USE_PROVEN_LEMMAS ?= 0
ENGINE_MODE ?= auto
INCLUDE_UNDRIVEN_FIELDS ?= 0

RUN_OPTS = GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=$(ENGINE_MODE)
UNIT_OPTS = $(RUN_OPTS) INCLUDE_UNDRIVEN_FIELDS=0

CVA5_FETCH_LOCAL_LADDER_STAGES = \
	request_alloc \
	attr_push \
	attr_valid_after_push \
	attr_valid_waiting_for_data \
	mem_request_reset_vec \
	mem_ack_reset_vec \
	instruction_response_lui \
	miss_data_lui \
	attr_valid_and_miss_data \
	attr_and_unit_data_same_cycle \
	internal_fetch_complete_lui \
	fetch_complete_lui

CVA5_REACHABILITY_STAGES = \
	reset \
	startup \
	mem_request \
	instruction_mem_request \
	instruction_mem_ack \
	instruction_mem_rvalid \
	instruction_mem_read \
	instruction_fetch \
	axi_arvalid \
	axi_ar \
	axi_r \
	axi_read

CVA5_AXI_DEBUG_LADDER_STAGES = \
	reset \
	startup \
	instruction_mem_read \
	instruction_mem_request_reset_vec \
	instruction_mem_ack_reset_vec \
	instruction_lui_returned_from_reset_vec \
	instruction_program_returned \
	fetch_ready \
	fetch_pc_reset_vec \
	fetch_tlb_ready \
	fetch_pc_id_available \
	fetch_attr_fifo_not_full \
	fetch_no_exception_pending \
	fetch_no_fetch_hold \
	fetch_tlb_request_enable \
	fetch_tlb_request_any \
	fetch_tlb_request_at_reset_pc \
	fetch_tlb_request \
	fetch_tlb_done \
	fetch_icache_subrequest \
	fetch_icache_mem_request \
	fetch_icache_mem_ack \
	fetch_icache_mem_rvalid \
	fetch_icache_line_complete \
	fetch_icache_miss_data_valid \
	fetch_icache_port_valid \
	fetch_icache_port_lui \
	fetch_subunit_valid \
	fetch_subunit_lui \
	fetch_unit_data_valid_any \
	fetch_unit_data_valid_icache \
	fetch_unit_data_lui \
	fetch_attr_fifo_valid \
	fetch_attr_icache \
	fetch_attr_and_unit_data \
	fetch_attr_icache_and_lui_data \
	fetch_attr_to_miss_data \
	fetch_attr_to_lui_data \
	fetch_internal_complete \
	fetch_internal_complete_lui \
	fetch_lui_data_to_internal_complete \
	fetch_no_flush_pending \
	fetch_complete \
	fetch_lui

CVA5_FETCH_GAP_LADDER_STAGES = \
	core_mem_request_icache_reset_vec \
	fbm_mem_ack_icache_reset_vec \
	fbm_response_lui_reset_vec \
	core_icache_rvalid_lui_reset_vec \
	fetch_icache_port_lui_raw \
	fetch_unit_data_lui_raw \
	fetch_instruction_lui_raw \
	fetch_internal_complete_lui_raw \
	fetch_lui_raw

CVA5_REACHABILITY_WRITE_STAGES = \
	axi_aw \
	axi_w \
	axi_b \
	axi_write

CVA5_REACHABILITY_READ_BACKPRESSURE_STAGES = \
	axi_ar_ready_high \
	axi_ar_ready_same \
	axi_ar_wait_1 \
	axi_ar_wait_2 \
	axi_ar_wait_3 \
	axi_ar_wait_16 \
	axi_ar_wait_19

CVA5_REACHABILITY_WRITE_BACKPRESSURE_STAGES = \
	axi_aw_ready_high \
	axi_aw_ready_same \
	axi_aw_wait_1 \
	axi_aw_wait_2 \
	axi_aw_wait_3 \
	axi_aw_wait_16 \
	axi_aw_wait_19 \
	axi_w_ready_high \
	axi_w_ready_same \
	axi_w_wait_1 \
	axi_w_wait_2 \
	axi_w_wait_3 \
	axi_w_wait_16 \
	axi_w_wait_19

CVA5_LISTED_STAGES = $(sort \
	$(CVA5_REACHABILITY_STAGES) \
	$(CVA5_FETCH_LOCAL_LADDER_STAGES) \
	$(CVA5_AXI_DEBUG_LADDER_STAGES) \
	$(CVA5_FETCH_GAP_LADDER_STAGES) \
	$(CVA5_REACHABILITY_WRITE_STAGES) \
	$(CVA5_REACHABILITY_READ_BACKPRESSURE_STAGES) \
	$(CVA5_REACHABILITY_WRITE_BACKPRESSURE_STAGES))

define RUN_CVA5_REACHABILITY_STAGES
	@set -e; \
	for stage in $(1); do \
		echo "==> formal-cva5-reachability-stage STAGE=$$stage"; \
		$(MAKE) formal-cva5-reachability-stage STAGE=$$stage $(RUN_OPTS); \
	done
endef

define RUN_CVA5_FETCH_LOCAL_STAGES
	@set -e; \
	for stage in $(1); do \
		echo "==> formal-cva5-fetch-local-stage STAGE=$$stage"; \
		$(MAKE) formal-cva5-fetch-local-stage STAGE=$$stage $(RUN_OPTS); \
	done
endef

.DEFAULT_GOAL := help

.PHONY: help formal-help
help formal-help:
	@echo "CVA5 formal targets"
	@echo
	@echo "Main unit-level closure commands:"
	@echo "  make formal-axi-master-unit-closure GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-master-read-closure GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-master-write-closure GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-master-combined-closure GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo
	@echo "Single-property debug commands:"
	@echo "  make formal-axi-master-read-property PROPERTY=<name> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-master-write-property PROPERTY=<name> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-master-combined-property PROPERTY=<name> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-axi-checker-property PROPERTY=<helper_name> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo
	@echo "Full-core and fetch reachability:"
	@echo "  make formal-cva5-list-stages"
	@echo "  make formal-cva5-reachability-stage STAGE=<stage> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-cva5-fetch-local-stage STAGE=<stage> GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo "  make formal-cva5-reachability GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto"
	@echo
	@echo "Utilities:"
	@echo "  make formal-elab GUI=0 ENGINE_MODE=auto"
	@echo "  make formal-filelist"
	@echo "  make formal-list"
	@echo
	@echo "Warning: INCLUDE_UNDRIVEN_FIELDS=1 enables review-mode strict AXI field checks at"
	@echo "the direct axi_master proof boundary. Keep the default INCLUDE_UNDRIVEN_FIELDS=0"
	@echo "for normal unit closure until the final AXI proof boundary is reviewed."

.PHONY: formal-axi-smoke
formal-axi-smoke:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_smoke --gui $(GUI)

.PHONY: formal-axi-property
formal-axi-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	@case '$(PROPERTY)' in helper_*) echo "error: use formal-axi-checker-property for helper_* properties" >&2; exit 1;; esac
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_property --gui $(GUI)

.PHONY: formal-cva5-reachability-stage
formal-cva5-reachability-stage:
	@test -n "$(STAGE)" || (echo "error: set STAGE=<stage>; see PROOF_DASHBOARD.md for stage names" >&2; exit 1)
	JG_STAGE='$(STAGE)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target cva5_reachability_stage --gui $(GUI)

.PHONY: formal-cva5-fetch-local-stage
formal-cva5-fetch-local-stage:
	@test -n "$(STAGE)" || (echo "error: set STAGE=<stage>; fetch-local examples: request_alloc, attr_valid_and_miss_data, fetch_complete_lui" >&2; exit 1)
	JG_STAGE='$(STAGE)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target cva5_fetch_local_stage --gui $(GUI)

.PHONY: formal-cva5-fetch-local-ladder
formal-cva5-fetch-local-ladder:
	$(call RUN_CVA5_FETCH_LOCAL_STAGES,$(CVA5_FETCH_LOCAL_LADDER_STAGES))

.PHONY: formal-cva5-reachability
formal-cva5-reachability:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_REACHABILITY_STAGES))

.PHONY: formal-cva5-axi-debug-ladder
formal-cva5-axi-debug-ladder:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_AXI_DEBUG_LADDER_STAGES))

.PHONY: formal-cva5-fetch-gap-ladder
formal-cva5-fetch-gap-ladder:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_FETCH_GAP_LADDER_STAGES))

.PHONY: formal-cva5-reachability-write
formal-cva5-reachability-write:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_REACHABILITY_WRITE_STAGES))

.PHONY: formal-cva5-reachability-read-backpressure
formal-cva5-reachability-read-backpressure:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_REACHABILITY_READ_BACKPRESSURE_STAGES))

.PHONY: formal-cva5-reachability-write-backpressure
formal-cva5-reachability-write-backpressure:
	$(call RUN_CVA5_REACHABILITY_STAGES,$(CVA5_REACHABILITY_WRITE_BACKPRESSURE_STAGES))

.PHONY: formal-axi-master-smoke
formal-axi-master-smoke:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-property
formal-axi-master-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	@case '$(PROPERTY)' in helper_*) echo "error: use formal-axi-checker-property for helper_* properties" >&2; exit 1;; esac
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_property --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-smoke
formal-axi-master-read-smoke:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_read_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-property
formal-axi-master-read-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' AXI_READ_USE_PROVEN_LEMMAS='$(USE_PROVEN_LEMMAS)' scripts/run_jg.sh --target axi_master_read_property --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-lifecycle-safety
formal-axi-master-read-lifecycle-safety:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_read_lifecycle_safety --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-checker
formal-axi-master-read-checker:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_read_checker --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-closure
formal-axi-master-read-closure:
	$(MAKE) formal-axi-master-read-smoke $(RUN_OPTS)
	$(MAKE) formal-axi-master-read-lifecycle-safety $(RUN_OPTS)
	$(MAKE) formal-axi-master-read-checker $(RUN_OPTS)

.PHONY: formal-axi-master-write-smoke
formal-axi-master-write-smoke:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_write_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-write-property
formal-axi-master-write-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_write_property --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-write-lifecycle-safety
formal-axi-master-write-lifecycle-safety:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_write_lifecycle_safety --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-write-checker
formal-axi-master-write-checker:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_write_checker --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-write-closure
formal-axi-master-write-closure:
	$(MAKE) formal-axi-master-write-smoke $(UNIT_OPTS)
	$(MAKE) formal-axi-master-write-lifecycle-safety $(UNIT_OPTS)
	$(MAKE) formal-axi-master-write-checker $(UNIT_OPTS)

.PHONY: formal-axi-master-combined-smoke
formal-axi-master-combined-smoke:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-combined-property
formal-axi-master-combined-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_property --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-combined-cross-safety
formal-axi-master-combined-cross-safety:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_cross_safety --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-combined-checker
formal-axi-master-combined-checker:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_checker --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-combined-all-safety
formal-axi-master-combined-all-safety:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_all_safety --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-combined-closure
formal-axi-master-combined-closure:
	$(MAKE) formal-axi-master-combined-smoke $(UNIT_OPTS)
	$(MAKE) formal-axi-master-combined-cross-safety $(UNIT_OPTS)
	$(MAKE) formal-axi-master-combined-checker $(UNIT_OPTS)

.PHONY: formal-axi-master-unit-closure
formal-axi-master-unit-closure:
	$(MAKE) formal-axi-master-read-closure $(RUN_OPTS)
	$(MAKE) formal-axi-master-write-closure $(UNIT_OPTS)
	$(MAKE) formal-axi-master-combined-closure $(UNIT_OPTS)

.PHONY: formal-axi-checker-property
formal-axi-checker-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<helper property label>" >&2; exit 1)
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_checker_property --gui $(GUI) --no-filelist

.PHONY: formal-elab
formal-elab:
	JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target formal_elab --gui $(GUI)

.PHONY: formal-filelist
formal-filelist:
	scripts/populate_cva5_rtl_vfile.sh

.PHONY: formal-clean
formal-clean:
	rm -rf runs

.PHONY: formal-list
formal-list:
	@find scripts/tcl -maxdepth 1 -name '*.tcl' ! -name '_*' -printf '%f\n' | sed 's/\.tcl$$//'

.PHONY: formal-cva5-list-stages
formal-cva5-list-stages:
	@echo "STAGE values referenced by full-core and fetch-local ladder targets:"
	@printf '  %s\n' $(CVA5_LISTED_STAGES)
