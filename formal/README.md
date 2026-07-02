Formal Verification
===================

This directory contains the JasperGold bring-up flow for CVA5.

Quick start:

```sh
make formal-axi-smoke
make formal-elab
make formal-axi-smoke GUI=1
make formal-axi-master-smoke GUI=0
make formal-axi-master-property PROPERTY=master_arvalid_held_until_ready GUI=0
make formal-axi-master-read-smoke GUI=0
make formal-axi-master-read-property PROPERTY=master_arvalid_held_until_ready GUI=0
make formal-axi-checker-property PROPERTY=helper_read_count_increment GUI=0
```

The same targets can be run from inside this directory without `-C formal`.

Targets:

- `make formal-filelist` regenerates `formal/filelists/cva5_rtl.vfile` from `tools/compile_order`.
- `make formal-elab` runs Jasper analysis/elaboration only.
- `make formal-axi-smoke` runs AXI and startup reachability covers.
- `make formal-axi-property PROPERTY=<label>` proves one AXI assertion or an explicit wildcard group.
- `make formal-axi-master-smoke` checks AXI master reachability without elaborating the full core.
- `make formal-axi-master-property PROPERTY=<label>` proves one AXI assertion against the unit-level master harness.
- `make formal-axi-master-read-smoke` checks read-address reachability in the read-only unit harness.
- `make formal-axi-master-read-property PROPERTY=<label>` proves one read-address assertion in the read-only unit harness.
- `make formal-axi-checker-property PROPERTY=helper_<label>` validates checker bookkeeping with abstract AXI handshakes.

Focused property targets default to `TIME_LIMIT=5m`; override it explicitly for deeper proofs.
- `make formal-list` lists available Tcl targets.
- `make formal-clean` removes generated run directories.

Layout:

- `interfaces/` contains formal property modules.
- `models/` contains formal wrappers and environment models.
- `scripts/tcl/` contains Jasper Tcl targets.
- `scripts/run_jg.sh` creates run directories and launches Jasper.
- `filelists/` contains generated analyzer filelists.
- `runs/` contains generated logs and projects and is not tracked.

Environment:

Ensure `jg` is available in `PATH` before running the Make targets.

Machine-specific setup should stay local. If needed, copy
`set_env.example.sh` to `set_env.sh`, edit it for your site, and source it
before running `make`. The local `set_env.sh` file is ignored by git.
