# JasperGold smoke test for bringing up the legacy CVA5 formal wrapper.
#
# Run from the repository root, or from any directory:
#   jg -tcl formal/scripts/tcl/axi_smoke.tcl
#
# This script is intentionally small: it analyzes the RTL filelist, analyzes the
# formal AXI files, elaborates cva5_formal_wrapper, then treats the AXI
# environment checks as assumptions for a first smoke proof. Filelist generation
# is managed by formal/scripts/run_jg.sh or make formal-filelist.

clear -all
set_engine_mode {B}

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set CVA5_ROOT [file normalize [file join ${SCRIPT_DIR} ../../..]]
set FILELIST_PATH [file join ${CVA5_ROOT} formal filelists cva5_rtl.vfile]
set JG_CVA5_RTL_PATH ${CVA5_ROOT}

analyze -sv -f ${FILELIST_PATH}
analyze -sv [file join ${CVA5_ROOT} formal interfaces axi4_basic_props.sv]
analyze -sv [file join ${CVA5_ROOT} formal models cva5_fbm.sv]
analyze -sv [file join ${CVA5_ROOT} formal models cva5_formal_wrapper.sv]

elaborate -top cva5_formal_wrapper \
    -bbox_a 17000 \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count

clock clk
reset rst

# For the first AXI bring-up pass, use the legacy AXI property module as an
# environment model around the core. The labels in axi4_basic_props.sv use the
# env_* prefix for this purpose.
assume -from_assert <embedded>::cva5_formal_wrapper.u_cva5_fbm.u_ppb_axi.env_*

prove -all
