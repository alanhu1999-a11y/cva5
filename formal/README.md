Formal Verification
===================

This directory contains the JasperGold bring-up flow for CVA5.

Quick start:

```sh
make -C formal formal-axi-smoke
make -C formal formal-axi-smoke GUI=1
```

The same targets can be run from inside this directory without `-C formal`.

Targets:

- `make formal-filelist` regenerates `formal/filelists/cva5_rtl.vfile` from `tools/compile_order`.
- `make formal-axi-smoke` runs `formal/scripts/tcl/axi_smoke.tcl`.
- `make formal-list` lists available Tcl targets.
- `make formal-clean` removes generated run directories.

Layout:

- `interfaces/` contains formal property modules.
- `models/` contains formal wrappers and environment models.
- `scripts/tcl/` contains Jasper Tcl targets.
- `scripts/run_jg.sh` creates run directories and launches Jasper.
- `filelists/` contains generated analyzer filelists.
- `runs/` contains generated Jasper logs and projects and is not tracked.

Environment:

Ensure `jg` is available in `PATH` before running the Make targets.

Machine-specific setup should stay local. If needed, copy
`set_env.example.sh` to `set_env.sh`, edit it for your site, and source it
before running `make`. The local `set_env.sh` file is ignored by git.
