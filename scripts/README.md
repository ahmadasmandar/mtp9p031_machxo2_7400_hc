# FPGA tools

For creating another project from this structure, read
`docs/NEW_PROJECT_SETUP_GUIDE.md` first.

The project targets the Lattice MachXO2-7000HC-5TG144C defined in
`KAMERA_TEST.ldf`.

Set the Diamond installation through `LATTICE_DIAMOND_HOME` or the VS Code
setting `lattice.diamondRoot` (default: `C:/lscc/diamond/3.14`).

VS Code tasks:

- `FPGA: Synthesis Check` — compile and synthesize the active VHDL.
- `FPGA: Build` — run an out-of-tree build, copy release artifacts into `impl1`, update `program_xcf.xcf`, and skip programming.
- `FPGA: Program JEDEC` — program and verify the generated JEDEC through JTAG.
- `FPGA: Check Build Outputs` — verify the minimum JEDEC/XCF/report set and zero errors.
- `FPGA: Open Diamond Project` — open the `.ldf` in Diamond.

The original full-board pin map is preserved in `KOM_ACB23_4009_ETR.lpf`.
The active standalone test uses `KAMERA_TEST_blinky.lpf`, which constrains only
the 48 MHz clock, active-low reset, and green LED. The test design blinks the
green LED at 1 Hz.

## Minimum programming outputs

After `FPGA: Build`, the minimum files needed for programming are:

- `impl1/KAMERA_TEST_impl1.jed` — generated FPGA configuration image.
- `impl1/KAMERA_TEST_impl1.xcf` — programmer configuration, updated with the JEDEC path, timestamp, and checksum.

The build is performed under `C:\Temp\FPGA_Build\KAMERA_TEST\<timestamp>`;
only the release artifacts and reports are copied into `impl1`.
