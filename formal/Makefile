GUI ?= 1
TIME_LIMIT ?= 5m
USE_PROVEN_LEMMAS ?= 0
ENGINE_MODE ?= auto
INCLUDE_UNDRIVEN_FIELDS ?= 0

.PHONY: formal-axi-smoke
formal-axi-smoke:
	scripts/run_jg.sh --target axi_smoke --gui $(GUI)

.PHONY: formal-axi-property
formal-axi-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	@case '$(PROPERTY)' in helper_*) echo "error: use formal-axi-checker-property for helper_* properties" >&2; exit 1;; esac
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' scripts/run_jg.sh --target axi_property --gui $(GUI)

.PHONY: formal-axi-master-smoke
formal-axi-master-smoke:
	scripts/run_jg.sh --target axi_master_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-property
formal-axi-master-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	@case '$(PROPERTY)' in helper_*) echo "error: use formal-axi-checker-property for helper_* properties" >&2; exit 1;; esac
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' scripts/run_jg.sh --target axi_master_property --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-smoke
formal-axi-master-read-smoke:
	JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_read_smoke --gui $(GUI) --no-filelist

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
	$(MAKE) formal-axi-master-read-smoke GUI=$(GUI) ENGINE_MODE=auto
	$(MAKE) formal-axi-master-read-lifecycle-safety GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto
	$(MAKE) formal-axi-master-read-checker GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto

.PHONY: formal-axi-master-write-smoke
formal-axi-master-write-smoke:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_write_smoke --gui $(GUI) --no-filelist

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
	$(MAKE) formal-axi-master-write-smoke GUI=$(GUI) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0
	$(MAKE) formal-axi-master-write-lifecycle-safety GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0
	$(MAKE) formal-axi-master-write-checker GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0

.PHONY: formal-axi-master-combined-smoke
formal-axi-master-combined-smoke:
	AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS='$(INCLUDE_UNDRIVEN_FIELDS)' JG_ENGINE_MODE='$(ENGINE_MODE)' scripts/run_jg.sh --target axi_master_combined_smoke --gui $(GUI) --no-filelist

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

.PHONY: formal-axi-master-combined-closure
formal-axi-master-combined-closure:
	$(MAKE) formal-axi-master-combined-smoke GUI=$(GUI) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0
	$(MAKE) formal-axi-master-combined-cross-safety GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0
	$(MAKE) formal-axi-master-combined-checker GUI=$(GUI) TIME_LIMIT=$(TIME_LIMIT) ENGINE_MODE=auto INCLUDE_UNDRIVEN_FIELDS=0

.PHONY: formal-axi-checker-property
formal-axi-checker-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<helper property label>" >&2; exit 1)
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' scripts/run_jg.sh --target axi_checker_property --gui $(GUI) --no-filelist

.PHONY: formal-elab
formal-elab:
	scripts/run_jg.sh --target formal_elab --gui $(GUI)

.PHONY: formal-filelist
formal-filelist:
	scripts/populate_cva5_rtl_vfile.sh

.PHONY: formal-clean
formal-clean:
	rm -rf runs

.PHONY: formal-list
formal-list:
	@find scripts/tcl -maxdepth 1 -name '*.tcl' ! -name '_*' -printf '%f\n' | sed 's/\.tcl$$//'
