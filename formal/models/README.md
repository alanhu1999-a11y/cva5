# Formal Model Layout

This directory is organized by the proof boundary that a model elaborates.

- `full_core/`: one CVA5 core, its formal bus model, the full-core AXI review
  wrapper, and the focused fetch-local wrapper.
- `unit_axi_master/`: direct `axi_master` read-only, write-only, combined, and
  Jasper-native review-framework harnesses.
- `legacy/`: older direct-`axi_master` and standalone AXI-checker harnesses.

The active full-core framework elaborates
`full_core/cva5_axi_proof_framework_wrapper.sv`, which instantiates
`full_core/cva5_formal_wrapper.sv` and `full_core/cva5_fbm.sv`. The unit-level
wrappers are separate proof tops and are not instantiated by that hierarchy.
