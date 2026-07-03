# Milestone 3 Summary: AXI Read-Response Lifecycle

Milestone 3 closes the unit-level AXI read-response lifecycle proof for
`axi_master`. The scope is read-only: LSU read request, AR handshake, legal
single-beat R response, LSU completion/ready, and return to `READY`. Write
channels, Wishbone, and full-core proofs are intentionally out of scope.

## Result

Progress: `[###################] 19/19` properties/covers passed.

| Group | Target | Result | Run directory | Peak memory |
|---|---|---:|---|---:|
| Smoke covers | `formal-axi-master-read-smoke` | 4/4 covered | `formal/runs/axi_master_read_smoke/20260703_163106` | 0.544 GB |
| Local DUT lifecycle | `formal-axi-master-read-lifecycle-safety` | 11/11 proven | `formal/runs/axi_master_read_lifecycle_safety/20260703_162606` | 0.544 GB |
| Checker read outstanding | `formal-axi-master-read-checker` | 5/5 proven, 3/3 covered | `formal/runs/axi_master_read_checker/20260703_163029` | 0.543 GB |

## Key Properties

| Property | Purpose | Result |
|---|---|---:|
| `cover_read_response_lifecycle` | LSU request -> AR accept -> R accept -> LSU completion/ready | covered in 5 cycles |
| `dut_ar_accept_creates_pending_read` | Accepted AR creates tracked pending read | proven |
| `dut_waiting_read_holds_until_rvalid` | DUT stays in `WAITING_READ` until legal R response | proven |
| `dut_r_response_clears_pending_read` | Accepted R clears pending read | proven |
| `dut_r_response_returns_to_ready` | R response returns DUT to `READY` | proven |
| `dut_r_response_completes_lsu` | R response creates LSU completion | proven |
| `dut_rdata_maps_to_ls_data_out` | AXI RDATA maps to LSU data output | proven |
| `master_read_outstanding_limit` | Checker read outstanding count never exceeds one | proven |
| `master_no_second_read_accept` | Checker blocks second read accept while one is outstanding | proven |
| `cover_read_outstanding_lifecycle` | Checker read outstanding set/clear lifecycle | covered in 6 cycles |

## Assumptions

- Reset/warmup: `formal_active` and `env_quiet_during_warmup` avoid checking
  stale startup state as protocol behavior.
- LSU requester: read requests are one-cycle commands and are only issued when
  `ls_if.ready` is high.
- AXI slave: early `RVALID` before an outstanding read is illegal environment
  behavior. The DUT ties `m_axi.rready = 1`, so it cannot reject such a beat.
- Safety proofs do not rely on bounded eventual `ARREADY` or `RVALID`. The
  ARREADY bound is used only in the cover wrapper.

## Waveform Screenshot

For the report, capture `cover_read_response_lifecycle` from:

```sh
csh -fc 'source /CMC/scripts/cadence.jasper26.03.001.csh; cd /home/v73704/cva5/formal; jg -gui -proj formal/runs/axi_master_read_smoke/20260703_163106/jgproject'
```

In the GUI, open `cover_read_response_lifecycle`, view its covered trace, and
save a screenshot showing LSU read request, AR handshake, R handshake,
`ls_if.data_valid`, `ls_if.ready`, and return to `READY`.
