# Shared Jasper setup for CVA5 AXI formal targets.

clear -all
set_engine_mode {B}

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} elseif {[info exists env(JG_CVA5_RTL_PATH)]} {
    set CVA5_ROOT [file normalize $env(JG_CVA5_RTL_PATH)]
} else {
    set SCRIPT_DIR [file dirname [file normalize [info script]]]
    set CVA5_ROOT [file normalize [file join $SCRIPT_DIR ../../..]]
}

set env(JG_CVA5_RTL_PATH) $CVA5_ROOT
set JG_CVA5_RTL_PATH $CVA5_ROOT
set FILELIST_PATH [file join $CVA5_ROOT formal filelists cva5_rtl.vfile]

if {![file exists $FILELIST_PATH]} {
    error "RTL filelist not found: $FILELIST_PATH. Run make formal-filelist first."
}

analyze -sv -f $FILELIST_PATH
analyze -sv [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv [file join $CVA5_ROOT formal models cva5_fbm.sv]
analyze -sv [file join $CVA5_ROOT formal models cva5_formal_wrapper.sv]

elaborate -top cva5_formal_wrapper \
    -bbox_a 17000 \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count

clock clk
reset rst

set AXI_PROPS <embedded>::cva5_formal_wrapper.u_cva5_fbm.u_ppb_axi
set FBM <embedded>::cva5_formal_wrapper.u_cva5_fbm
