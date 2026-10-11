# KAMERA_TEST

Minimal Lattice MachXO2 FPGA test project for the KOM ACB23 board. The current
design blinks the FPGA green LED at 1 Hz.

## Hardware and project

- Device: `LCMXO2-7000HC-5TG144`
- Toolchain: Lattice Diamond 3.14 or a compatible installation
- Top-level VHDL entity: `top`
- Clock: 48 MHz
- Reset: active-low external reset
- Output: green FPGA LED

The active pin constraints are in [`KAMERA_TEST_blinky.lpf`](KAMERA_TEST_blinky.lpf).
The original full-board pin map is preserved in
[`KOM_ACB23_4009_ETR.lpf`](KOM_ACB23_4009_ETR.lpf).

## Repository layout

- [`top.vhd`](top.vhd) — clock divider, reset handling, and LED output
- [`KAMERA_TEST.ldf`](KAMERA_TEST.ldf) — Lattice Diamond project definition
- [`KAMERA_TEST1.sty`](KAMERA_TEST1.sty) — implementation strategy
- [`scripts/build`](scripts/build) — synthesis, build, programming, and checks
- [`docs/NEW_PROJECT_SETUP_GUIDE.md`](docs/NEW_PROJECT_SETUP_GUIDE.md) — setup notes for creating a related project
- `impl1/` — generated implementation outputs; ignored by Git

## Prerequisites

Install Lattice Diamond and make `pnmainc.exe` available below the installation
directory. Configure the installation path with either:

```powershell
$env:LATTICE_DIAMOND_HOME = 'C:\lscc\diamond\3.14'
```

or the VS Code setting `lattice.diamondRoot`.

## Build and verify

Run these commands from the repository root:

```powershell
.\scripts\build\build.ps1 -Mode Synthesis
.\scripts\build\build.ps1 -Mode Full
.\scripts\build\check_build.ps1
```

The full build generates the JEDEC programming image and updates the programming
configuration. The build scripts use a temporary workspace under
`C:\Temp\FPGA_Build\KAMERA_TEST\<timestamp>` and copy release artifacts back to
`impl1`.

The minimum programming outputs are:

- `impl1/KAMERA_TEST_impl1.jed` — FPGA configuration image
- `program_xcf.xcf` — programmer configuration

## Programming

Connect the board through JTAG, then run:

```powershell
.\scripts\build\program.ps1
```

The script programs and verifies the generated JEDEC image through the configured
Lattice Diamond programmer tools.

## VS Code tasks

The project also provides tasks for synthesis checking, full build, JEDEC
programming, build-output validation, and opening the Diamond project. See
[`scripts/README.md`](scripts/README.md) for the task names and details.
