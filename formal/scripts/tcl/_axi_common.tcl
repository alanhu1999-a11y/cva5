# Shared Jasper setup for CVA5 AXI formal targets.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set CVA5_AXI_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set CVA5_AXI_ENGINE_MODE auto
}
puts "CVA5 AXI engine mode: $CVA5_AXI_ENGINE_MODE"
set_engine_mode $CVA5_AXI_ENGINE_MODE

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

source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

if {![file exists $FILELIST_PATH]} {
    error "RTL filelist not found: $FILELIST_PATH. Run make formal-filelist first."
}

analyze -sv -f $FILELIST_PATH
analyze -sv [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_fbm.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_formal_wrapper.sv]

elaborate -top cva5_formal_wrapper \
    -bbox_a 17000 \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count

clock clk
reset rst

set WRAPPER <embedded>::cva5_formal_wrapper
set AXI_PROPS ${WRAPPER}.u_cva5_fbm.u_ppb_axi
set FBM ${WRAPPER}.u_cva5_fbm
