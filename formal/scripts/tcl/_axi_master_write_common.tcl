# Shared Jasper setup for write-only unit-level CVA5 AXI master targets.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set AXI_MASTER_WRITE_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set AXI_MASTER_WRITE_ENGINE_MODE auto
}
puts "AXI write engine mode: $AXI_MASTER_WRITE_ENGINE_MODE"
set_engine_mode $AXI_MASTER_WRITE_ENGINE_MODE

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} else {
    set CVA5_ROOT [file normalize [pwd]]
}

set TYPES_DIR [file join $CVA5_ROOT core types_and_interfaces]

source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

set AXI_MASTER_WRITE_ANALYZE_ARGS {}
if {[info exists env(AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS)] && $env(AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS) eq "1"} {
    puts "AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS=1: compiling review-only full-field checks."
    lappend AXI_MASTER_WRITE_ANALYZE_ARGS +define+AXI_WRITE_INCLUDE_UNDRIVEN_FIELD_CHECKS
}

analyze -sv [file join $TYPES_DIR cva5_config.sv]
analyze -sv [file join $TYPES_DIR riscv_types.sv]
analyze -sv [file join $TYPES_DIR csr_types.sv]
analyze -sv [file join $TYPES_DIR cva5_types.sv]
analyze -sv [file join $TYPES_DIR fpu_types.sv]
analyze -sv [file join $TYPES_DIR internal_interfaces.sv]
analyze -sv [file join $TYPES_DIR external_interfaces.sv]
analyze -sv [file join $CVA5_ROOT core memory_sub_units axi_master.sv]
analyze -sv {*}$AXI_MASTER_WRITE_ANALYZE_ARGS [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv {*}$AXI_MASTER_WRITE_ANALYZE_ARGS [file join $CVA5_ROOT formal models unit_axi_master axi_master_write_formal_wrapper.sv]

if {![info exists AXI_MASTER_WRITE_TOP]} {
    error "AXI_MASTER_WRITE_TOP must be set before sourcing _axi_master_write_common.tcl"
}

elaborate -top $AXI_MASTER_WRITE_TOP

clock clk
reset rst

set AXI_MASTER_WRITE_HARNESS <embedded>::${AXI_MASTER_WRITE_TOP}.u_harness
set AXI_MASTER_WRITE_PROPS ${AXI_MASTER_WRITE_HARNESS}.u_axi_props
