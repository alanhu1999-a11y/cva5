CVA5 Formal Verification
========================

This directory contains the JasperGold bring-up flow for CVA5. The current
work focuses on unit-level AXI master proofs and staged full-core reachability.

Run from this directory:

```sh
make formal-filelist
make formal-elab GUI=0 ENGINE_MODE=auto

make formal-axi-master-proof-framework GUI=1 ENGINE_MODE=auto
make formal-axi-master-read-closure GUI=0 ENGINE_MODE=auto
make formal-axi-master-write-closure GUI=0 ENGINE_MODE=auto
make formal-axi-master-combined-closure GUI=0 ENGINE_MODE=auto

make formal-cva5-axi-proof-framework GUI=1 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-axi-load-list-stages
make formal-cva5-axi-load-stage STAGE=instruction_return GUI=0 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-axi-load-reachability GUI=1 TIME_LIMIT=5m ENGINE_MODE=auto
make formal-cva5-reachability-stage STAGE=instruction_fetch GUI=0 TIME_LIMIT=2m ENGINE_MODE=auto
make formal-cva5-reachability GUI=0 TIME_LIMIT=2m
make formal-cva5-reachability-read-backpressure GUI=0 TIME_LIMIT=2m
```

Common targets:

- `formal-filelist`: regenerate `formal/filelists/cva5_rtl.vfile`.
- `formal-elab`: analyze and elaborate the full-core wrapper.
- `formal-axi-master-proof-framework`: launch the Jasper-native unit review project with named tasks, assumption views, Proof Structure, pending-obligation manifests, and branch/statement COI Checker Coverage.
- `formal-axi-master-read-closure`: read-only AXI master smoke, local safety, and checker properties.
- `formal-axi-master-write-closure`: write-only AXI master smoke, local safety, and checker properties.
- `formal-axi-master-combined-closure`: combined read/write unit smoke, cross-safety, and checker properties.
- `formal-cva5-axi-proof-framework`: launch one full-core review project with named assumption, reachability, embedded-AXI safety, lifecycle, and pending-obligation tasks plus a Jasper Proof Structure.
- `formal-cva5-axi-load-stage`: run one anchored full-core LW stage in that same framework.
- `formal-cva5-axi-load-reachability`: run the anchored LW stages in order; stop manually at the first inconclusive stage during debug.
- `formal-cva5-axi-load-list-stages`: list the accepted anchored LW stage names.
- `formal-cva5-reachability-stage`: one full-core reachability cover selected by `STAGE=<name>`.
- `formal-cva5-reachability`: staged full-core reset, startup, instruction-memory, and AXI read reachability.
- `formal-cva5-reachability-write`: optional staged full-core AXI write reachability.
- `formal-cva5-reachability-read-backpressure`: optional full-core AR timing cover stages.
- `formal-cva5-reachability-write-backpressure`: optional full-core AW/W timing cover stages.
- `formal-list`: list available Tcl targets.
- `formal-clean`: remove generated `runs/`.

Important options:

- `GUI=0`: batch mode.
- `ENGINE_MODE=auto`: default engine mode for current full-core and unit flows.
- `TIME_LIMIT=5m`: default focused proof limit; override for staged smoke runs.
- `INCLUDE_UNDRIVEN_FIELDS=1`: opt-in review mode for known AXI field checks.
- `FRAMEWORK_RUN_PROOFS=0`: build the review project and task structure without running the proof roots.
- `CVA5_FRAMEWORK_RUN_PROOFS=0`: build the full-core task/Proof Structure manifest without running assertions.
- `CVA5_FRAMEWORK_RUN_REACHABILITY=1`: opt in to broad reset/startup/fetch covers; focused stage targets are the normal reachability flow.
- `CVA5_FRAMEWORK_RUN_DEEP_RESPONSE=1`: opt in to resource-intensive LSU completion/data assertions.
- `CVA5_LOAD_ORCHESTRATION=off`: default focused-load resource control; `ENGINE_MODE` remains independently overridable.

Project layout:

- `interfaces/`: reusable formal property modules.
- `models/full_core/`: full-core wrappers, FBM, and fetch-local debug wrapper.
- `models/unit_axi_master/`: current read-only, write-only, combined, and review-framework AXI master harnesses.
- `models/legacy/`: retained legacy direct-AXI-master and standalone-checker harnesses.
- `scripts/tcl/`: Jasper Tcl targets.
- `scripts/run_jg.sh`: run-directory creation and Jasper launch wrapper.
- `filelists/`: generated analyzer filelists.
- `runs/`: generated logs and Jasper projects, not tracked.

Environment setup is site-specific. Ensure `jg` is available in `PATH`.
Machine-local setup may be placed in `set_env.sh`, but it is intentionally not
part of the default flow.

See `PROOF_DASHBOARD.md` for current proof status, run commands, assumptions,
run directories, and design-review items.
