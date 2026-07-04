# Milestone 5 Closure: Combined AXI Master Unit Proof

Milestone 5 closes the combined unit-level `axi_master` read/write proof under
the default review policy. The closure run was launched from a clean git state
at commit `50ce3a8`; each `command.txt` records `git_dirty=0`.

## Scope

In scope:

- Unit-level `axi_master` harness only.
- Legal LSU read and write requests in the same harness.
- Cross-mode safety between read and write flows.
- Shared `axi4_basic_props` checker under the combined harness.

Out of scope:

- Full-core proof.
- Wishbone proof.
- AMO proof.
- Default strict checks for currently undriven `AWSIZE`, `AWCACHE`, and `WLAST`.

## Closure Command

```sh
cd /home/v73704/cva5/formal
make formal-axi-master-combined-closure GUI=0 ENGINE_MODE=auto
```

## Clean Closure Results

| Target | Result | Engines Seen | Peak Memory | Run Directory |
|---|---|---|---:|---|
| `formal-axi-master-combined-smoke` | 6/6 covers covered | `Hp` | 0.546 GB | `formal/runs/axi_master_combined_smoke/20260704_182511` |
| `formal-axi-master-combined-cross-safety` | 27/27 assertions proven | `N`, `Mpcustom2`, `Hp` | 0.547 GB | `formal/runs/axi_master_combined_cross_safety/20260704_182528` |
| `formal-axi-master-combined-checker` | 21/21 assertions proven, 7/7 covers covered | `Mpcustom2`, `Hp`, `AM` | 0.549 GB | `formal/runs/axi_master_combined_checker/20260704_182627` |

## Smoke Covers

| Cover | Result |
|---|---|
| `cover_combined_read_request` | covered in 2 cycles |
| `cover_combined_write_request` | covered in 2 cycles |
| `cover_combined_read_lifecycle` | covered in 5 cycles |
| `cover_combined_write_lifecycle` | covered in 6 cycles |
| `cover_read_then_write` | covered in 9 cycles |
| `cover_write_then_read` | covered in 9 cycles |

## Cross-Safety Coverage

The local `dut_*` assertions prove that:

- Legal read and write LSU requests enter the expected FSM paths.
- New LSU requests are accepted only from `READY`.
- The DUT does not drive or accept read and write AXI transactions at the same time.
- Read and write pending trackers do not overlap.
- Busy read/write states keep `ls_if.ready` low until the matching legal response.
- Read completion follows an R response and cannot be completed by a B response.
- Write completion follows a B response and cannot be completed by an R response.
- RDATA maps to the load/store response data on read completion.

## Checker Results

The shared checker properties prove:

- ARVALID/AWVALID/WVALID hold until ready.
- ARADDR/AWADDR/WDATA remain stable while waiting.
- Read, write-address, and write-data outstanding counters increment, decrement,
  and remain stable as expected.
- The combined harness preserves the one-outstanding read/write checker limits.
- Checker-level read and write lifecycle covers remain reachable.

## Assumptions

Reset and warmup:

- `formal_active` gates post-reset checks.
- No LSU request, R response, or B response is allowed during warmup.

LSU request protocol:

- `ls_new_request` is a one-cycle pulse.
- LSU requests are issued only when `ls_if.ready` is high.
- A legal LSU request is either read or write: `ls_if.re ^ ls_if.we`.

AXI slave environment:

- No early `RVALID` before a pending read.
- No early `BVALID` before a pending write.
- Read responses are single-beat in this unit harness (`RLAST=1`).

Cover-only progress:

- The smoke cover wrapper bounds AR/AW/W ready backpressure only to make covers
  reachable.
- Safety proof targets do not assume eventual ready or eventual response.

## Remaining Review Blocker

`AWSIZE`, `AWCACHE`, and `WLAST` strict-field checks remain opt-in because the
current RTL does not drive those fields. The default closure keeps
`INCLUDE_UNDRIVEN_FIELDS=0`. Do not claim full-field write-channel closure until
Lesley or the RTL owner approves and implements the missing field assignments.

