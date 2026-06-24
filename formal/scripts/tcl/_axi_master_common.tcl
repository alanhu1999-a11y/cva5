# Shared Jasper setup for unit-level CVA5 AXI master targets.

clear -all
set_engine_mode {B}

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
analyze -sv [file join $CVA5_ROOT formal models axi_master_formal_wrapper.sv]

elaborate -top axi_master_formal_wrapper

clock clk
reset rst

set AXI_MASTER_PROPS <embedded>::axi_master_formal_wrapper.u_axi_props
set AXI_MASTER_HARNESS <embedded>::axi_master_formal_wrapper
