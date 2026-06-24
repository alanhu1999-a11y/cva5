# Shared Jasper setup for AXI checker self-tests.

clear -all
set_engine_mode {B}

if {[info exists env(CVA5_ROOT)]} {
    set CVA5_ROOT [file normalize $env(CVA5_ROOT)]
} else {
    set CVA5_ROOT [file normalize [pwd]]
}

source [file join $CVA5_ROOT formal scripts tcl _proof_limits.tcl]

analyze -sv [file join $CVA5_ROOT core types_and_interfaces cva5_config.sv]
analyze -sv [file join $CVA5_ROOT core types_and_interfaces external_interfaces.sv]
analyze -sv [file join $CVA5_ROOT formal interfaces axi4_basic_props.sv]
analyze -sv [file join $CVA5_ROOT formal models axi_checker_formal_wrapper.sv]

elaborate -top axi_checker_formal_wrapper

clock clk
reset rst

set AXI_CHECKER_PROPS <embedded>::axi_checker_formal_wrapper.u_axi_props
