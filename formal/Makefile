GUI ?= 1
TIME_LIMIT ?= 5m
USE_PROVEN_LEMMAS ?= 0
ENGINE_MODE ?= B

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
	scripts/run_jg.sh --target axi_master_read_smoke --gui $(GUI) --no-filelist

.PHONY: formal-axi-master-read-property
formal-axi-master-read-property:
	@test -n "$(PROPERTY)" || (echo "error: set PROPERTY=<property label>" >&2; exit 1)
	@case '$(PROPERTY)' in helper_*) echo "error: use formal-axi-checker-property for helper_* properties" >&2; exit 1;; esac
	JG_PROPERTY='$(PROPERTY)' JG_TIME_LIMIT='$(TIME_LIMIT)' JG_ENGINE_MODE='$(ENGINE_MODE)' AXI_READ_USE_PROVEN_LEMMAS='$(USE_PROVEN_LEMMAS)' scripts/run_jg.sh --target axi_master_read_property --gui $(GUI) --no-filelist

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
