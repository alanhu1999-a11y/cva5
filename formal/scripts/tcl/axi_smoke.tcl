# JasperGold smoke test for bringing up the legacy CVA5 formal wrapper.
#
# Run from the repository root, or from any directory:
#   jg -tcl formal/scripts/tcl/axi_smoke.tcl
#
# This script is intentionally small: it analyzes the RTL filelist, analyzes the
# formal AXI files, elaborates cva5_formal_wrapper, then proves only the AXI
# smoke properties. Filelist generation is managed by formal/scripts/run_jg.sh
# or make formal-filelist.

if {[info exists env(CVA5_ROOT)]} {
    set COMMON_TCL [file join $env(CVA5_ROOT) formal scripts tcl _axi_common.tcl]
} else {
    set COMMON_TCL [file join [pwd] formal scripts tcl _axi_common.tcl]
}
source $COMMON_TCL

prove -property ${AXI_PROPS}.cover_*
prove -property ${FBM}.cover_*
