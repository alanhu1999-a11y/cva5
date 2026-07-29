# Shared Jasper setup for read-only unit-level CVA5 AXI master targets.

clear -all

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set AXI_MASTER_READ_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set AXI_MASTER_READ_ENGINE_MODE auto
}
puts "AXI read engine mode: $AXI_MASTER_READ_ENGINE_MODE"
set_engine_mode $AXI_MASTER_READ_ENGINE_MODE

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} else {
    set CVA5_ROOT [file normalize [pwd]]
}

set TYPES_DIR [file join $CVA5_ROOT core types_and_interfaces]

source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

analyze -sv [file join $TYPES_DIR cva5_config.sv]
analyze -sv [file join $TYPES_DIR riscv_types.sv]
analyze -sv [file join $TYPES_DIR csr_types.sv]
analyze -sv [file join $TYPES_DIR cva5_types.sv]
analyze -sv [file join $TYPES_DIR fpu_types.sv]
analyze -sv [file join $TYPES_DIR internal_interfaces.sv]
analyze -sv [file join $TYPES_DIR external_interfaces.sv]
analyze -sv [file join $CVA5_ROOT core memory_sub_units axi_master.sv]
analyze -sv [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]

set AXI_MASTER_READ_WRAPPER [file join $CVA5_ROOT formal models unit_axi_master axi_master_read_formal_wrapper.sv]
analyze -sv $AXI_MASTER_READ_WRAPPER

if {![info exists AXI_MASTER_READ_TOP]} {
    error "AXI_MASTER_READ_TOP must be set before sourcing _axi_master_read_common.tcl"
}

elaborate -top $AXI_MASTER_READ_TOP

clock clk
reset rst

set AXI_MASTER_READ_HARNESS <embedded>::${AXI_MASTER_READ_TOP}.u_harness
set AXI_MASTER_READ_PROPS ${AXI_MASTER_READ_HARNESS}.u_axi_props

if {[info exists env(AXI_READ_USE_PROVEN_LEMMAS)] && $env(AXI_READ_USE_PROVEN_LEMMAS) eq "1"} {
    set AXI_READ_FROM_ASSERT_CUT0 [assume -from_assert ${AXI_MASTER_READ_HARNESS}.dut_arvalid_backpressure_implies_requesting_read]
    set AXI_READ_FROM_ASSERT_CUT1 [assume -from_assert ${AXI_MASTER_READ_HARNESS}.dut_requesting_read_holds_arvalid]
    assert -disable ${AXI_MASTER_READ_HARNESS}.dut_arvalid_backpressure_implies_requesting_read
    assert -disable ${AXI_MASTER_READ_HARNESS}.dut_requesting_read_holds_arvalid

    puts "Converted independently proven ARVALID assertions into assumptions:"
    puts "  ${AXI_READ_FROM_ASSERT_CUT0} <= ${AXI_MASTER_READ_HARNESS}.dut_arvalid_backpressure_implies_requesting_read"
    puts "  ${AXI_READ_FROM_ASSERT_CUT1} <= ${AXI_MASTER_READ_HARNESS}.dut_requesting_read_holds_arvalid"
    puts "Disabled the source assertions in this cut-mode run; prove them independently with USE_PROVEN_LEMMAS=0."
}
