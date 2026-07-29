# JasperGold elaboration-only smoke test for the CVA5 formal wrapper.
#
# This target uses the same analyzer and elaboration options as axi_smoke.tcl,
# but stops before clocks, resets, assumptions, covers, or proofs are applied.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set CVA5_ELAB_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set CVA5_ELAB_ENGINE_MODE auto
}
puts "CVA5 elab engine mode: $CVA5_ELAB_ENGINE_MODE"
set_engine_mode $CVA5_ELAB_ENGINE_MODE

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
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_fbm.sv]
analyze -sv [file join $CVA5_ROOT formal models full_core cva5_formal_wrapper.sv]

elaborate -top cva5_formal_wrapper \
    -bbox_a 17000 \
    -bbox_mul 67 \
    -bbox_m sixinput_pop_count
