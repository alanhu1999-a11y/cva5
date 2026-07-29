# Shared setup for the Jasper-native AXI master review framework.

clear -all

set AXI_MASTER_FRAMEWORK_TOP axi_master_proof_framework_wrapper

# Checker Coverage is a separate Coverage App analysis. Instrument only the
# three direct axi_master DUT instances; wrappers and property modules remain
# outside the scored RTL scope. COI is structural checker coverage, not proof
# core or mutation coverage.
set AXI_MASTER_FRAMEWORK_COVERAGE_INSTANCES [list \
    u_read.u_dut \
    u_write.u_dut \
    u_combined.u_dut]
check_cov -init -model {branch statement} -type coi \
    -exclude_instance {*} \
    -include_instance $AXI_MASTER_FRAMEWORK_COVERAGE_INSTANCES

if {[info exists env(JG_ENGINE_MODE)] && $env(JG_ENGINE_MODE) ne ""} {
    set AXI_MASTER_FRAMEWORK_ENGINE_MODE $env(JG_ENGINE_MODE)
} else {
    set AXI_MASTER_FRAMEWORK_ENGINE_MODE auto
}
puts "AXI proof-framework engine mode: $AXI_MASTER_FRAMEWORK_ENGINE_MODE"
set_engine_mode $AXI_MASTER_FRAMEWORK_ENGINE_MODE

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} else {
    set CVA5_ROOT [file normalize [pwd]]
}

set TYPES_DIR [file join $CVA5_ROOT core types_and_interfaces]
source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

set AXI_MASTER_FRAMEWORK_ANALYZE_ARGS {}
if {[info exists env(AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS)] &&
    $env(AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS) eq "1"} {
    puts "AXI_WRITE_INCLUDE_UNDRIVEN_FIELDS=1: compiling optional direct-boundary review properties."
    lappend AXI_MASTER_FRAMEWORK_ANALYZE_ARGS +define+AXI_WRITE_INCLUDE_UNDRIVEN_FIELD_CHECKS
}

analyze -sv [file join $TYPES_DIR cva5_config.sv]
analyze -sv [file join $TYPES_DIR riscv_types.sv]
analyze -sv [file join $TYPES_DIR csr_types.sv]
analyze -sv [file join $TYPES_DIR cva5_types.sv]
analyze -sv [file join $TYPES_DIR fpu_types.sv]
analyze -sv [file join $TYPES_DIR internal_interfaces.sv]
analyze -sv [file join $TYPES_DIR external_interfaces.sv]
analyze -sv [file join $CVA5_ROOT core memory_sub_units axi_master.sv]
analyze -sv {*}$AXI_MASTER_FRAMEWORK_ANALYZE_ARGS \
    [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv [file join $CVA5_ROOT formal models unit_axi_master axi_master_read_formal_wrapper.sv]
analyze -sv {*}$AXI_MASTER_FRAMEWORK_ANALYZE_ARGS \
    [file join $CVA5_ROOT formal models unit_axi_master axi_master_write_formal_wrapper.sv]
analyze -sv {*}$AXI_MASTER_FRAMEWORK_ANALYZE_ARGS \
    [file join $CVA5_ROOT formal models unit_axi_master axi_master_combined_formal_wrapper.sv]
analyze -sv [file join $CVA5_ROOT formal models unit_axi_master axi_master_proof_framework_wrapper.sv]

elaborate -top $AXI_MASTER_FRAMEWORK_TOP

clock clk
reset rst
