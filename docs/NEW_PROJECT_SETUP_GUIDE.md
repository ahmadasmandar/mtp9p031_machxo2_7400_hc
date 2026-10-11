# Lattice FPGA Project Setup Guide

This guide explains how to create a new Lattice Diamond FPGA project using the
same workflow as `KAMERA_TEST`.

The workflow is:

```text
source files + LPF + Diamond project
        ↓
temporary out-of-tree Diamond build
        ↓
JEDEC and reports copied to impl1/
        ↓
program_xcf.xcf updated with JEDEC path/checksum
        ↓
JTAG program and verify
```

## 1. Confirm the hardware

Before creating files, record:

- FPGA family and exact device
- package and speed grade
- oscillator frequency
- reset polarity
- LED or test-output pins
- JTAG cable type and port

For this project the confirmed device is:

```text
Device:       LCMXO2-7000HC-5TG144C
Family:       MachXO2
Clock:        48 MHz on package site 49
Reset:        active-low on package site 55
Green LED:    package site 128
Diamond:      C:\lscc\diamond\3.14
```

Do not copy these values to another board without checking its schematic,
pinout, and oscillator frequency.

## 2. Create the minimum project files

Create this structure:

```text
NEW_PROJECT/
├── .gitignore
├── .vscode/
│   ├── settings.json
│   └── tasks.json
├── docs/
│   └── NEW_PROJECT_SETUP_GUIDE.md
├── impl1/                         # generated outputs only
├── scripts/build/
│   ├── build.ps1
│   ├── build-program-temp.ps1
│   ├── check_build.ps1
│   ├── program.ps1
│   ├── run_build.tcl
│   └── update_xcf.ps1
├── top.vhd
├── NEW_PROJECT.ldf
├── NEW_PROJECT.sty
├── NEW_PROJECT.lpf
└── program_xcf.xcf
```

The required source-controlled inputs are:

- `top.vhd` — top-level entity and architecture
- `NEW_PROJECT.lpf` — physical pins, I/O standards, and clock constraint
- `NEW_PROJECT.ldf` — Diamond project and implementation definition
- `NEW_PROJECT.sty` — Diamond strategy
- `program_xcf.xcf` — canonical programmer configuration
- `scripts/build/` — reproducible build/program scripts
- `.vscode/` — editor tasks and Diamond path
- `.gitignore` — excludes generated outputs

`impl1/` is an output directory. Do not use it as the source of a new design.

## 3. Write the top-level VHDL

The entity port names must exactly match the LPF component names.

Example:

```vhdl
library ieee;
use ieee.std_logic_1164.all;

entity top is
    generic (
        G_CLOCK_HZ : positive := 48_000_000
    );
    port (
        pClock          : in  std_logic;
        pnReset         : in  std_logic;
        pFPGA_LED_Green : out std_logic
    );
end entity top;
```

Keep the top entity name consistent with the `.ldf` top-module setting.

For a first hardware test, use one clock, one reset, and one visible output.
Add the remaining interfaces only after the basic image programs and runs.

## 4. Create the LPF

Use the board schematic to assign every used port:

```lpf
rvl_alias "pClock" "pClock";

LOCATE COMP "pClock" SITE "49";
LOCATE COMP "pnReset" SITE "55";
LOCATE COMP "pFPGA_LED_Green" SITE "128";

IOBUF ALLPORTS IO_TYPE=LVCMOS33 PULLMODE=NONE;
FREQUENCY PORT "pClock" 48.000 MHz;
USE PRIMARY NET "pClock";
```

Important:

- Use the exact VHDL port spelling and capitalization.
- Add a frequency constraint matching the real oscillator.
- Do not use the complete production LPF for a small test design unless the
  top-level VHDL also contains all constrained ports. Otherwise Diamond emits
  warnings for every unused constraint.
- Keep a separate full-board LPF if it is needed later.

## 5. Create the Diamond implementation file

The `.ldf` must identify the device, implementation, top entity, VHDL source,
and LPF:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<BaliProject version="3.2" title="NEW_PROJECT"
    device="LCMXO2-7000HC-5TG144C" default_implementation="impl1">
    <Options/>
    <Implementation title="impl1" dir="impl1"
        description="impl1" synthesis="lse" default_strategy="Strategy1">
        <Options def_top="top" top="top"/>
        <Source name="top.vhd" type="VHDL" type_short="VHDL">
            <Options top_module="top"/>
        </Source>
        <Source name="NEW_PROJECT.lpf"
            type="Logic Preference" type_short="LPF">
            <Options/>
        </Source>
    </Implementation>
    <Strategy name="Strategy1" file="NEW_PROJECT.sty"/>
</BaliProject>
```

The source paths are relative to the `.ldf` directory. If the project name or
source names change, update every matching entry.

## 6. Configure the Diamond strategy

The strategy must enable:

- Lattice Synthesis Engine (LSE)
- VHDL-2008
- the correct device family, package, and speed grade
- the intended target frequency

The build script also applies these settings at build time:

```tcl
prj_strgy set_value -strategy Strategy1 lse_vhdl2008=True
prj_strgy set_value -strategy Strategy1 lse_frequency=48
```

Change `48` when the new board uses another clock frequency.

## 7. Create the programmer XCF

`program_xcf.xcf` is the canonical programmer file. It must contain:

- `Family` — for example `MachXO2`
- `Name` — exact FPGA family/device
- `IDCode` — exact JTAG ID
- `Operation` — normally `FLASH Erase,Program,Verify`
- `CableName` and `PortAdd`
- a `<File>` pointing to the generated JEDEC

Do not invent the ID code. Obtain it from Diamond’s Programmer device
database or the device documentation.

The XCF must be written as UTF-8 **without a BOM**. Diamond can reject an XCF
with the message `Opening XCF file... Failed!` when a BOM is present.

`update_xcf.ps1` updates the JEDEC path, file time, and JEDEC checksum after a
successful build. The root `program_xcf.xcf` is then used for programming.

## 8. Configure VS Code

In `.vscode/settings.json`, set the Diamond installation:

```json
{
  "lattice.diamondRoot": "C:/lscc/diamond/3.14",
  "files.associations": {
    "*.vhd": "vhdl",
    "*.vhdl": "vhdl",
    "*.lpf": "plaintext",
    "*.ldf": "xml"
  }
}
```

Do not add `files.exclude` or `search.exclude`. All project files and folders
must remain visible.

Add tasks for:

1. Build only: `build-program-temp.ps1 -SkipProgram`
2. Build and program: `build-program-temp.ps1`
3. Program existing image: `program.ps1`
4. Check reports: `check_build.ps1`
5. Open Diamond: `pnmain.exe NEW_PROJECT.ldf`

## 9. Use the temporary build workflow

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build\build-program-temp.ps1 `
  -DiamondRoot C:\lscc\diamond\3.14 `
  -SkipProgram
```

The script:

1. Creates `C:\Temp\FPGA_Build\NEW_PROJECT\<timestamp>`.
2. Copies only source inputs into that directory.
3. Runs a forced Diamond build there.
4. Checks synthesis, mapping, PAR, and timing reports.
5. Copies selected release artifacts into repository `impl1/`.
6. Updates the root `program_xcf.xcf`.

The temporary workspace is the build workspace. The repository `impl1/`
directory contains only the selected release artifacts and reports.

## 10. Minimum build outputs

The minimum files needed to confirm a valid build are:

```text
impl1/NEW_PROJECT_impl1.jed
impl1/NEW_PROJECT_impl1.par
impl1/NEW_PROJECT_impl1.twr
impl1/NEW_PROJECT_impl1.mrp
program_xcf.xcf
```

The report gate must show:

```text
PAR completed
0 unrouted connections
0 PAR errors
0 setup errors
0 hold errors
0 cumulative negative slack
```

## 11. Program the FPGA

After the build succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build\program.ps1 `
  -DiamondRoot C:\lscc\diamond\3.14 `
  -XcfFile .\program_xcf.xcf
```

The programmer uses `pgrcmd.exe` and the XCF’s JEDEC reference:

```text
C:\lscc\diamond\3.14\bin\nt64\pgrcmd.exe
```

Expected first-stage output:

```text
Argument check - OK
Loading Programmer Device Database... Done.
Opening XCF file... Done.
```

Programming and verification additionally require the board, JTAG cable,
correct cable port, powered hardware, and the correct device in the scan
chain.

## 12. Verify the blinky

After programming:

1. Assert and release reset according to the board polarity.
2. Confirm the selected LED is physically connected to the assigned pin.
3. Confirm the LED toggles at the expected visible rate.
4. If it does not blink, check clock frequency, LED active polarity, reset
   polarity, LPF site numbers, and the JEDEC checksum.

## 13. Files to change for the next project

At minimum, change these items:

| File | Change |
|---|---|
| `top.vhd` | New entity ports and RTL |
| `NEW_PROJECT.lpf` | Exact board pin assignments and clock |
| `NEW_PROJECT.ldf` | Project name, device, top, source names |
| `NEW_PROJECT.sty` | Device strategy and target frequency |
| `program_xcf.xcf` | Family, device, ID code, cable, JEDEC reference |
| `scripts/build/build-program-temp.ps1` | Project name and copied source list |
| `scripts/build/build.ps1` | Output/project names if not parameterized |
| `scripts/build/check_build.ps1` | Expected report and artifact names |
| `.vscode/tasks.json` | Project script paths if directory layout changes |
| `.gitignore` | Keep source files visible and ignore generated outputs |

Search for the old project name in all scripts before the first build:

```powershell
rg -n "KAMERA_TEST|KAMERA_TEST_impl1|KAMERA_TEST_blinky" .
```

## 14. Recommended first-project sequence

```text
1. Confirm device, package, clock, reset, LED, and JTAG cable.
2. Create top.vhd with one clock, reset, and LED.
3. Create a minimal LPF with only those used ports.
4. Create the LDF and strategy.
5. Create a valid BOM-free programmer XCF.
6. Run Synthesis Check.
7. Run Build with -SkipProgram.
8. Run Check Build Outputs.
9. Inspect the JEDEC and XCF paths/checksum.
10. Program with program_xcf.xcf.
11. Confirm the physical LED behavior.
12. Add real modules one at a time with focused verification.
```
