# Sweep readouts - evidence

Branch `feat/sweep-readouts` at 87ab8c5, on origin/main 1bb1a0f.
Screenshots from `tools/play.sh playtests/readout.play` (windowed, 1280x720).

| Frame | What it shows |
|---|---|
| readout_0_unread.png | Beside the FUEL TANK's cut, nothing read: no Section ping on the minimap |
| readout_1_tap.png | A tap: `MOUNT / FUEL TANK` typed bottom right, the name blooming over the cut |
| readout_2_charged.png | A 3 s charge: tier 3 rows, and the ring reached the other two Mounts; SOLAR ARRAY's echo hides behind the dashboard |
| readout_3_records.png | Log > RECORDS: the H A R D W A R E group, rows down to the deepest tier read |
| readout_4_gate.png | A Gate: read, but undecipherable - glyph noise in the Titan's purple |

## Results
- `tools/test.sh`: Overall Summary: 937 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
- `tools/smoke.sh`: SMOKE: OK (300 frames)
- Playtests passed: readout, restore_sr7, boot_log, records, gate, gate_identify, freight_track, core_cold_start, minimap, log, new_game
