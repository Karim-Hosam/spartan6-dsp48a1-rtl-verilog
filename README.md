# Project 1: Spartan-6 DSP48A1 — Verilog RTL Design & Verification

> **Course:** Digital Design Using Verilog & FPGA Flow Using Vivado  
> **Instructor:** Eng. Kareem Waseem  
> **Author:** Karim Hosam  
> **Target FPGA:** Xilinx xc7a200tffg1156-3 (Artix-7 200T)  
> **Simulation Tool:** Siemens QuestaSim / ModelSim  
> **Synthesis Tool:** AMD Xilinx Vivado

---

## Table of Contents

1. [Course & Training Context](#1-course--training-context)
2. [Project Overview](#2-project-overview)
3. [What Is DSP48A1?](#3-what-is-dsp48a1)
4. [Assignment Requirements](#4-assignment-requirements)
5. [Design Implementation](#5-design-implementation)
6. [Testbench & Verification](#6-testbench--verification)
7. [QuestaSim Simulation Flow](#7-questasim-simulation-flow)
8. [Vivado FPGA Design Flow](#8-vivado-fpga-design-flow)
9. [Constraint File](#9-constraint-file)
10. [Results Summary](#10-results-summary)
11. [Repository Structure](#11-repository-structure)
12. [Lessons Learned](#12-lessons-learned)

---

## 1. Course & Training Context

This project was completed as part of the **"Digital Design Using Verilog & FPGA Flow Using Vivado"** training program taught by **Eng. Kareem Waseem**. The course covers a broad range of topics in classical and modern digital design, including:

- RTL design and Verilog HDL modeling (combinational and sequential circuits)
- Finite State Machines (FSMs) and memories
- Testbench development and self-checking verification
- Siemens QuestaSim simulation and Tcl scripting
- Static Timing Analysis (STA) and pipelining
- Clock Domain Crossing (CDC) best practices
- QuestaLint and formal verification
- Vivado design flow: Elaboration → Synthesis → Implementation
- Timing and physical constraints (XDC)
- FPGA prototyping on Xilinx devices

---

## 2. Project Overview

**Project 1** requires designing the behavioral model of the **DSP48A1 slice** found in Xilinx Spartan-6 FPGAs. The Spartan-6 family offers a high ratio of DSP48A1 slices to general-purpose logic, making it ideal for math-intensive applications such as digital filtering, multiply-accumulate (MAC) operations, and signal processing.

The goal is to:

1. Implement the full DSP48A1 data path in synthesizable Verilog.
2. Write a self-checking testbench using directed test patterns.
3. Simulate the design in QuestaSim using a `.do` file.
4. Run the complete Vivado flow (elaboration, synthesis, implementation) with no design-check errors.
5. Run linting and confirm zero errors.
6. Document all results with snippets.

---

## 3. What Is DSP48A1?

The **DSP48A1** is a dedicated Digital Signal Processing (DSP) hard macro embedded in Xilinx Spartan-6 FPGAs. Each slice provides:

- An **18×18 unsigned/signed multiplier**
- A **pre-adder/subtracter** (18-bit) that can optionally combine the D and B inputs before the multiplier
- A **post-adder/subtracter** (48-bit) with carry-in and carry-out for wide accumulation
- A **48-bit C port** for direct injection into the post-adder
- **Configurable pipeline registers** at every stage (A0/A1, B0/B1, C, D, M, P, OPMODE, CARRYIN, CARRYOUT) controlled by parameters
- **Dynamic OPMODE control** (8-bit) that selects the X-MUX input, Z-MUX input, pre-adder mode, carry-in source, and add/subtract operation on every clock cycle
- **Cascade ports** (BCIN/BCOUT, PCIN/PCOUT) for chaining multiple DSP slices
- **Configurable reset type** (synchronous or asynchronous) controlled by the `RSTTYPE` parameter

The slice architecture allows a single DSP48A1 to perform multiply, multiply-accumulate, multiply-add, wide addition, and barrel-shift operations — all reconfigurable at run time via OPMODE.

---

## 4. Assignment Requirements

As specified in the project description:

| # | Requirement |
|---|---|
| 1 | Design the DSP48A1 slice in Verilog |
| 2 | Write a self-checking testbench with directed test patterns |
| 3 | Use a `.do` file to automate the QuestaSim simulation flow |
| 4 | Run Vivado elaboration, synthesis, and implementation with no errors |
| 5 | Use a constraint file with a 100 MHz timing constraint on pin W5 |
| 6 | Target FPGA part: **xc7a200tffg1156-3** (to accommodate large I/O count) |
| 7 | Capture waveform snippets from QuestaSim |
| 8 | Capture schematic snippets after elaboration and synthesis |
| 9 | Capture utilization and timing reports after synthesis and implementation |
| 10 | Capture the "Messages" tab showing no critical warnings or errors |
| 11 | Run linting with the default methodology and goals — no errors |

### Deliverable Report Sections

The final PDF report is organized into 9 sections:

1. RTL code
2. Testbench code
3. Do file
4. QuestaSim Snippets
5. Constraint File
6. Elaboration (Messages + Schematic)
7. Synthesis (Messages + Utilization + Timing + Schematic)
8. Implementation (Messages + Utilization + Timing + Device)
9. Linting (no errors)

---

## 5. Design Implementation

The design is implemented in a single Verilog file ([`src/DSP48A1.v`](src/DSP48A1.v)) that contains 7 modules:

### 5.1 Sub-Modules

| Module | Purpose | Key Parameters |
|--------|---------|---------------|
| `REG_MUX` | Parameterized register-with-bypass. When `NO_PIPELINES=1`, the output is the registered value; when `NO_PIPELINES=0`, the output bypasses the register and passes D through directly. Supports SYNC or ASYNC reset via `RSTTYPE`. | `WIDTH`, `RSTTYPE`, `NO_PIPELINES` |
| `MUX_2_1` | Parameterized 2-to-1 multiplexer (combinational) | `WIDTH` |
| `MUX_4_1` | Parameterized 4-to-1 multiplexer (combinational) | `WIDTH` |
| `Adder_Subtracter_WithOUT_CI_CO` | 18-bit pre-adder/subtracter (no carry I/O). SEL=0 → add, SEL=1 → subtract | `WIDTH` |
| `Adder_Subtracter_With_CI_CO` | 48-bit post-adder/subtracter with carry-in and carry-out. SEL=0 → Z+X+CIN, SEL=1 → Z−(X+CIN) | `WIDTH` |
| `Multiplier` | 18×18 unsigned multiplier producing a 36-bit product | `WIDTH` |

### 5.2 Top-Level Module: `DSP48A1`

The top-level module instantiates all sub-modules and wires them according to the DSP48A1 block diagram. The data flow is:

```
 D ──→ [DREG] ──→ Pre-Adder ──┐
                               ├──→ [Pre-Adder MUX] ──→ [B1REG] ──→ Multiplier ──→ [MREG]
 B ──→ [B0 MUX] ──→ [B0REG] ──┘                                                      │
                                                                                       ▼
 A ──→ [A0REG] ──→ [A1REG] ──────────────────────────────────────→ Multiplier     X-MUX ──→ Post-Adder ──→ [PREG] ──→ P
                                                                                       ▲
 C ──→ [CREG] ────────────────────────────────────────────────────────────────→ Z-MUX ──┘
                                                                                       ▲
 PCIN ─────────────────────────────────────────────────────────────────────────→ Z-MUX ──┘
```

**Key design decisions:**
- Configuration-time parameters (`A0REG`, `B0REG`, etc.) are implemented as the `NO_PIPELINES` parameter of `REG_MUX`, selecting between registered and bypassed paths.
- The `B_INPUT` parameter selects between direct B input and cascaded BCIN input via a compile-time MUX.
- The `CARRYINSEL` parameter selects between the CARRYIN port and OPMODE[5] at compile time.
- OPMODE[7:0] is dynamically controlled and has its own optional register stage.

---

## 6. Testbench & Verification

The testbench ([`tb/DSP48A1_tb.v`](tb/DSP48A1_tb.v)) uses **directed test patterns** with **self-checking** logic. It instantiates the DUT with the default parameter set specified in the project requirements.

### Test Sequence

| Test | OPMODE | What It Verifies | Expected Key Outputs |
|------|--------|-------------------|---------------------|
| **Reset** | Random | All outputs are 0 after synchronous reset | P=0, M=0, BCOUT=0, CARRYOUT=0 |
| **Path 1** | `8'b11011101` | Pre-subtraction (D−B), multiplier, C-port post-subtraction (C − M) | BCOUT=`'hf`, M=`'h12c`, P=`'h32` |
| **Path 2** | `8'b00010000` | Pre-addition (D+B), zeros through X & Z MUX, post-addition | BCOUT=`'h23`, M=`'h2bc`, P=`0` |
| **Path 3** | `8'b00001010` | No pre-add, P-feedback through both X & Z MUX (accumulation path) | BCOUT=`'ha`, M=`'hc8`, P=past P value |
| **Path 4** | `8'b10100111` | No pre-add, D:A:B concat through X, PCIN through Z, post-subtraction | BCOUT=`'h6`, M=`'h1e`, P=`'hfe6fffec0bb1`, CARRYOUT=1 |

Each test waits the appropriate number of clock edges for data to propagate through the pipeline registers, then compares every output against the expected value. If any mismatch occurs, the testbench prints a failure message and halts (`$stop`).

**Inputs A, B, C, D:** Set to specific values per test case.  
**Inputs BCIN, PCIN, CARRYIN:** Driven with `$random` (they are irrelevant for the selected OPMODE paths).

---

## 7. QuestaSim Simulation Flow

The simulation is automated via a `.do` file ([`simulation/Run_DSP48A1.do`](simulation/Run_DSP48A1.do)):

```tcl
vlib work
vlog ../src/DSP48A1.v ../tb/DSP48A1_tb.v
vsim -voptargs=+acc work.DSP48A1_tb
add wave *
run -all
```

**Steps:**
1. Create the `work` library.
2. Compile both the RTL and testbench source files.
3. Load the testbench module into the simulator with optimization access (`+acc`) for full waveform visibility.
4. Add all signals to the waveform viewer.
5. Run the simulation to completion.

**How to use:**
1. Open QuestaSim / ModelSim.
2. Navigate to the `simulation/` directory.
3. Execute: `do Run_DSP48A1.do`

---

## 8. Vivado FPGA Design Flow

The project was run through the complete Vivado design flow:

### 8.1 Project Setup
- **Part:** xc7a200tffg1156-3 (Artix-7 200T, 1156-pin FFBGA, speed grade -3)
- **Source file:** `src/DSP48A1.v`
- **Constraint file:** `constraints/Constraints_basys3.xdc`
- **Top module:** `DSP48A1`

### 8.2 Elaboration
- RTL elaboration was run successfully.
- The elaborated schematic shows the DSP48A1 block with all internal sub-modules (multiplexers, registers, adder/subtracter, multiplier).
- The "Messages" tab confirmed no critical warnings or errors.

### 8.3 Synthesis
- Synthesis was run successfully.
- The synthesized schematic shows the design mapped to FPGA primitives including DSP cells.
- Utilization and timing reports were captured.

### 8.4 Implementation
- Implementation (place & route) was run successfully.
- Utilization, timing, and device view snippets were captured.
- No critical warnings or errors in the "Messages" tab.

### 8.5 Linting
- QuestaLint was run with default methodology and goals.
- No errors were reported.

---

## 9. Constraint File

The constraint file ([`constraints/Constraints_basys3.xdc`](constraints/Constraints_basys3.xdc)) is based on the standard Basys3 Rev-B XDC template with only two active constraints:

```tcl
# 100 MHz clock on pin W5
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Reset button on pin U18
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst]
```

**Why xc7a200tffg1156-3?**  
The DSP48A1 design has a large number of I/O ports (18-bit A, 18-bit B, 48-bit C, 18-bit D, 48-bit PCIN, 8-bit OPMODE, 8 resets, 8 clock enables, plus outputs). The Basys3 board (xc7a35t) does not have enough I/O pins. The xc7a200tffg1156-3 with its 1156-pin BGA package provides sufficient I/O to accommodate all design ports.

---

## 10. Results Summary

| Metric | Result |
|--------|--------|
| All 5 testbench checks | **PASSED** |
| Vivado Elaboration | **No errors or critical warnings** |
| Vivado Synthesis | **Successful** |
| Vivado Implementation | **Successful** |
| Timing (100 MHz) | **Met** |
| Linting | **No errors** |

---

## 11. Repository Structure

```
Project_1_DSP48A1/
├── src/
│   └── DSP48A1.v                     # RTL: all design modules
├── tb/
│   └── DSP48A1_tb.v                  # Self-checking testbench
├── simulation/
│   ├── Run_DSP48A1.do                # QuestaSim automation script
│   ├── Project1_DSP48A1.mpf          # QuestaSim project file
│   ├── Project1_DSP48A1.cr.mti       # QuestaSim cache
│   ├── test.prj                      # Visualizer project file
│   ├── .visualizer/                  # Visualizer config
│   ├── work/                         # Compiled simulation library
│   └── qcache/                       # QuestaSim cache
├── constraints/
│   └── Constraints_basys3.xdc        # Vivado timing & I/O constraints
├── docs/
│   ├── Karim_Hosam_Project1.pdf      # Final submission report
│   └── img/                          # Screenshots & snippets
│       ├── code1–4.png               # RTL code snippets
│       ├── RTL.png, RTL1–4.png       # Schematic snippets
│       ├── TB.png                    # Testbench waveform snippet
│       ├── MUX2.png, MUX4.png        # Module schematic snippets
│       ├── Mult.png                  # Multiplier schematic snippet
│       ├── Pre adder.png             # Pre-adder schematic snippet
│       ├── Post Adder.png            # Post-adder schematic snippet
│       ├── Register with MUX Module.png  # REG_MUX schematic
│       └── Do File.png               # Do file execution screenshot
├── DSP48A1_All_Source.v              # Consolidated source code file
├── DSP48A1.pdf                       # DSP48A1 datasheet reference
├── DSP_TB_Description.pdf            # Testbench stimulus description
├── README.md                         # This file
├── TECHNICAL_DOCUMENTATION.md        # Detailed technical documentation
└── .gitignore                        # Git ignore rules
```

---

## 12. Lessons Learned

1. **Parameterized design:** Using a single `REG_MUX` module with a `NO_PIPELINES` parameter to serve as both a registered and bypassed path greatly reduced code duplication across all pipeline stages.

2. **Self-checking testbenches:** Embedding expected values and comparison logic directly in the testbench catches bugs immediately during simulation, rather than requiring manual waveform inspection.

3. **OPMODE dynamics:** The 8-bit OPMODE field provides remarkable flexibility — a single DSP slice can perform multiply, accumulate, add, subtract, or concatenation operations just by changing OPMODE at run time.

4. **Pipeline latency awareness:** Each test case must wait the correct number of clock cycles (matching the number of enabled pipeline registers on the critical path) before checking outputs. This is a common source of testbench bugs.

5. **FPGA part selection:** The large I/O count of the full DSP48A1 interface (200+ pins) exceeded the Basys3 board's capacity, requiring selection of a larger FPGA package (xc7a200tffg1156-3).

6. **Timing closure at 100 MHz:** The design met timing at 100 MHz, demonstrating that the pipeline registers effectively break long combinational paths (multiplier + adder chains) into manageable segments.

7. **Linting discipline:** Running QuestaLint before synthesis catches common RTL issues (undriven signals, width mismatches, inferred latches) early in the design cycle.

---

*This project demonstrates the complete FPGA design flow from RTL modeling through verification, synthesis, implementation, and linting — a workflow used daily in professional digital design.*
