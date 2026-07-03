# Hardware Specification: VCK190 PL-Only Streaming Pipeline

## 1. Target Platform

| Parameter        | Value                                    |
|------------------|------------------------------------------|
| Board            | AMD Versal VCK190 Evaluation Kit         |
| FPGA Part        | xcvc1902-vsva2197-2MP-e-S (Versal AI Core) |
| Board Part       | xilinx.com:vck190:part0:3.4              |
| Vivado Version   | 2025.2                                   |

## 2. Design Overview

### 2.1 Purpose

A **PL-only** free-running AXI-Stream pipeline for demonstrating ILA and VIO
debug insertion skills. The design intentionally avoids PS-to-PL data paths
(no NoC, no SmartConnect, no DMA, no address mapping) to keep the build simple
and reliable. CIPS provides only the PL reference clock and debug infrastructure.

### 2.2 Data Path

```
axis_stream_source (RTL) ──AXIS──▶ axis_filter (RTL) ──AXIS──▶ AXI4-Stream Data FIFO (IP)
         ▲                              ▲                              │
    VIO outputs:                  VIO outputs:                   VIO inputs:
    - stream_enable               - bypass_enable                - FIFO fill level
    - pattern_sel[1:0]                                           - packet_count
    - reset                                                      - error flags
```

- **axis_stream_source**: Free-running counter-based AXI-Stream source. Generates
  configurable data patterns (counter, walking-1, PRBS-like, constant). VIO controls
  enable, pattern select, and reset. VIO monitors packet count and error flags.
- **axis_filter**: Passthrough filter with VIO-controllable bypass enable.
- **AXI4-Stream Data FIFO**: Standard Xilinx FIFO IP that sinks the stream.
  Provides a natural backpressure point and FIFO fill levels for VIO monitoring.

### 2.3 Debug Infrastructure

| Debug Core | Purpose | Typical Insertion |
|---|---|---|
| **AXIS-ILA** (`axis_ila:1.3`) | Capture AXI-Stream waveforms between source→filter or filter→FIFO | ILA insertion skill demo |
| **AXIS-VIO** (`axis_vio:1.0`) | Control stream_enable/pattern_sel/reset, monitor packet_count/FIFO fill | VIO insertion skill demo |
| **AXI Debug Hub** (`axi_dbg_hub:2.0`) | Bridge debug cores to JTAG via CIPS | Required for Versal |

### 2.4 No External I/O

No GPIO, no LEDs, no pin constraints. All interaction is through JTAG debug cores.

## 3. Custom RTL Modules

### 3.1 `axis_stream_source` (New Module)

Free-running AXI-Stream data source with VIO-controllable behavior.

| Port             | Direction | Width | Description                          |
|------------------|-----------|-------|--------------------------------------|
| aclk             | input     | 1     | AXI clock                            |
| aresetn          | input     | 1     | Active-low reset                     |
| stream_enable    | input     | 1     | Enable stream output (from VIO)      |
| pattern_sel      | input     | 2     | Data pattern: 00=counter, 01=walking-1, 10=PRBS-like, 11=constant |
| m_axis_tdata     | output    | 64    | Master data output                   |
| m_axis_tkeep     | output    | 8     | Byte enables (all 1s)                |
| m_axis_tvalid    | output    | 1     | Valid when enabled and not in reset   |
| m_axis_tlast     | output    | 1     | Asserted every 256 beats (packet boundary) |
| m_axis_tready    | input     | 1     | Backpressure from downstream         |
| packet_count     | output    | 32    | Number of complete packets sent (to VIO) |

**Behavior:**
- When `stream_enable=0`: `m_axis_tvalid=0`, counters hold.
- When `stream_enable=1`: generates continuous stream with `tlast` every 256 beats.
- `pattern_sel` selects data content: incrementing counter, walking-1 pattern,
  XOR-feedback pseudo-random, or constant `0xDEADBEEF_CAFEBABE`.
- `packet_count` increments on each `tlast && tvalid && tready`.

### 3.2 `axis_filter` (Updated Module)

Passthrough filter with VIO-controllable bypass.

| Port             | Direction | Width | Description                          |
|------------------|-----------|-------|--------------------------------------|
| aclk             | input     | 1     | AXI clock                            |
| aresetn          | input     | 1     | Active-low reset                     |
| bypass_enable    | input     | 1     | When 1, pass all data; when 0, gate tvalid off |
| s_axis_tdata     | input     | 64    | Slave data input                     |
| s_axis_tkeep     | input     | 8     | Slave byte enables                   |
| s_axis_tvalid    | input     | 1     | Slave valid                          |
| s_axis_tlast     | input     | 1     | Slave last beat                      |
| s_axis_tready    | output    | 1     | Slave ready                          |
| m_axis_tdata     | output    | 64    | Master data output                   |
| m_axis_tkeep     | output    | 8     | Master byte enables                  |
| m_axis_tvalid    | output    | 1     | Master valid                         |
| m_axis_tlast     | output    | 1     | Master last beat                     |
| m_axis_tready    | input     | 1     | Master ready                         |

**Behavior:**
- `bypass_enable=1` (default): all signals forwarded directly (passthrough).
- `bypass_enable=0`: `m_axis_tvalid` forced to 0 (blocks data flow),
  `s_axis_tready` remains connected to `m_axis_tready`.

## 4. PS Configuration (Versal CIPS)

CIPS provides **only** clock and debug — no AXI data path to PL.

| CIPS Setting               | Value       | Purpose                     |
|----------------------------|-------------|-----------------------------|
| PL0_REF_CLK                | 100 MHz     | PL fabric clock             |
| PL Resets                  | 1           | pl_resetn0 for PL logic     |
| PMC to NoC                 | Enabled     | Required for Debug Hub only |
| FPD AXI NOC                | Disabled    | No PS-PL data path          |
| LPD AXI NOC                | Disabled    | No PS-PL data path          |

## 5. PL IP Configuration

### 5.1 Processor System Reset (`proc_sys_reset`)

| Parameter   | Value     | Rationale                        |
|-------------|-----------|----------------------------------|
| (defaults)  | —         | Synchronizes CIPS pl_resetn0     |

### 5.2 AXI4-Stream Data FIFO (`axis_data_fifo`)

| Parameter             | Value | Rationale                        |
|-----------------------|-------|----------------------------------|
| TDATA_NUM_BYTES       | 8     | 64-bit data width (8 bytes)      |
| FIFO_DEPTH            | 1024  | Provides backpressure buffer     |
| HAS_TKEEP             | 1     | Match source tkeep               |
| HAS_TLAST             | 1     | Preserve packet boundaries       |

### 5.3 AXI Debug Hub (`axi_dbg_hub:2.0`)

Required for Versal debug. Connected to CIPS via NoC for JTAG access. The
AXI NoC used here is **only** for the debug hub path — no user data flows
through it.

### 5.4 AXI NoC (Debug Path Only)

A minimal NoC instance to bridge CIPS PMC-to-NoC to the Debug Hub. One slave
input (from CIPS), one master output (to Debug Hub), one clock.

## 6. Clock and Reset

| Signal          | Source                  | Destination              |
|-----------------|------------------------|--------------------------|
| pl0_ref_clk     | CIPS                   | All PL IPs, RTL modules  |
| pl_resetn0      | CIPS                   | proc_sys_reset ext_reset |
| peripheral_aresetn | proc_sys_reset      | RTL aresetn, FIFO aresetn |

## 7. Build Notes

- **Versal PDI**: Build generates a `.pdi` file (not `.bit`)
- **JTAG programming**: VCK190 has built-in USB-C JTAG — program PDI directly via Hardware Manager
- **Versal ILA**: Use AXIS-ILA (`axis_ila`), not System ILA. Requires AXI Debug Hub.
- **Versal VIO**: Use AXIS-VIO (`axis_vio`), not VIO v3.0. Shares the same Debug Hub as ILA.

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
