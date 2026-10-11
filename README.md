# KAMERA_TEST

Lattice MachXO2 FPGA bring-up project for the KOM ACB23 board. The source now
includes a camera I2C address probe and J12 UART reporting; this camera build
has **not** been programmed into the connected FPGA.

## Hardware and project

- Device: `LCMXO2-7000HC-4TG144C` (per supplied board schematic)
- Toolchain: Lattice Diamond 3.14 or a compatible installation
- Top-level VHDL entity: `top`
- Clock: 48 MHz
- Reset: active-low external reset
- Output: green FPGA LED

The active pin constraints are in [`KAMERA_TEST_blinky.lpf`](KAMERA_TEST_blinky.lpf).
The original full-board pin map is preserved in
[`KOM_ACB23_4009_ETR.lpf`](KOM_ACB23_4009_ETR.lpf).

## Repository layout

- [`top.vhd`](top.vhd) — LED, camera scanner, and UART reporting
- [`modules/i2c_probe.vhd`](modules/i2c_probe.vhd) — open-drain address probe
- [`modules/camera_scan.vhd`](modules/camera_scan.vhd) — MT9P031 candidate-address scan
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
- `impl1/KAMERA_TEST_impl1.xcf` — programmer configuration refreshed by the build

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

## J12 debug UART

The current top level connects the reusable [`modules/uart.vhd`](modules/uart.vhd)
to the FT4232H USB serial channel on J12. Open the corresponding serial port at
**1,000,000 baud, 8 data bits, no parity, 1 stop bit, no flow control**. Characters
sent from the PC are echoed back. The new source probes camera addresses 0x48
and 0x5D at 100 kHz once per second and sends a line such as
`I2C 48=1 5D=0 ERR=0` (CR/LF). A `1` means address ACK; it does not prove sensor
identity. The green LED continues to blink. The board will continue running
the previously programmed Hello-world image until this new design is
deliberately programmed. Turn off local echo in the terminal to see each typed
character once.

| FPGA port | FPGA package site | FT4232H connection | Direction |
|---|---:|---|---|
| `pFPGA_RX_FTDI` | 143 | DDBUS0, pin 48 | PC to FPGA |
| `pFPGA_TX_FTDI` | 142 | DDBUS1, pin 52 | FPGA to PC |

The UART has byte-level `tx_data`/`tx_valid`/`tx_ready` and
`rx_data`/`rx_valid` signals so future debug logic can send status bytes. The
current top level has a one-byte echo buffer; it is intended for terminal
testing, not sustained streaming. J12 is the USB connector on the board, while
the FPGA sees ordinary 3.3 V UART signals through the FT4232H.

## Camera I2C electrical gate

| Camera net | BU111 contact | FPGA site | HDL behavior |
|---|---:|---:|---|
| KAM_SDATA | 8 | 24 | pull low or release |
| KAM_SCLK | 9 | 25 | pull low or release |

The 3.3 V FPGA bank and camera-side I/O level must be checked before programming
this build. Measure idle KAM_SCLK and KAM_SDATA at the connected, powered camera
interface and confirm pull-ups/level translation. The MT9P031 sensor's VDD_IO
may be 1.8 V or 2.8 V; the supplied board excerpts do not establish the
voltage at the FPGA pins. The current design does not drive KAM_MCLK, so lack
of an ACK may also reflect the camera board's clock/reset requirements. Do not
interpret an ACK alone as proof that the MT9P031 is present.

The Diamond target follows the supplied board schematic's `-4` speed grade.
Check the marking on the populated FPGA if the hardware revision differs.
