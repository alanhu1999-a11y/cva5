GUI ?= 0

.PHONY: formal-axi-smoke
formal-axi-smoke:
	scripts/run_jg.sh --target axi_smoke --gui $(GUI)

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
	@find scripts/tcl -maxdepth 1 -name '*.tcl' -printf '%f\n' | sed 's/\.tcl$$//'
