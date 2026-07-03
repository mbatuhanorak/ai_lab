# Hardware Specification: KV260 DMA Loopback Design

## 1. Target Platform

| Parameter        | Value                                    |
|------------------|------------------------------------------|
| Board            | AMD Kria KV260 Vision AI Starter Kit     |
| SOM              | K26 SOM (K26C commercial grade)          |
| FPGA Part        | xck26-sfvc784-2LV-c (ZynqUS+ MPSoC)     |
| Board Part       | xilinx.com:kv260_som:part0:1.4           |
| Vivado Version   | 2025.2                                   |

## 2. Design Requirements

### 2.1 Functional Overview

Create an AXI DMA loopback design for the Kria KV260 with a custom AXI-Stream
filter module in the data path. DMA buffers reside in PL BRAM (not PS DDR) so
that verification requires only `devmem2` — no kernel drivers, no DMA-capable
memory allocators, and no restrictions from CONFIG_STRICT_DEVMEM.

- **DMA loopback via BRAM**: CPU writes test data into BRAM source region →
  DMA MM2S reads from BRAM → data passes through a custom RTL filter →
  DMA S2MM writes to BRAM destination region → CPU reads and verifies.
- **Timer**: AXI Timer for interval timing and interrupt generation.
- **No external I/O**: No GPIO, no LEDs, no pin constraints. Verification is
  entirely register-based via `devmem2`.

### 2.2 Custom RTL Module — `axis_filter`

A simple AXI-Stream passthrough filter with the following interface:

| Port       | Direction | Width | Description                |
|------------|-----------|-------|----------------------------|
| aclk       | input     | 1     | AXI clock                  |
| aresetn    | input     | 1     | Active-low AXI reset       |
| s_axis_tdata  | input  | 64    | Slave data input           |
| s_axis_tkeep  | input  | 8     | Slave byte enables         |
| s_axis_tlast  | input  | 1     | Slave last beat marker     |
| s_axis_tvalid | input  | 1     | Slave valid                |
| s_axis_tready | output | 1     | Slave ready (backpressure) |
| m_axis_tdata  | output | 64    | Master data output         |
| m_axis_tkeep  | output | 8     | Master byte enables        |
| m_axis_tlast  | output | 1     | Master last beat marker    |
| m_axis_tvalid | output | 1     | Master valid               |
| m_axis_tready | input  | 1     | Master ready               |

Initial implementation: wire-through passthrough (all outputs = corresponding
inputs). This module exists at `src/axis_filter.v`.

### 2.3 PS Configuration

| PS Interface       | Direction | Purpose                           |
|--------------------|-----------|-----------------------------------|
| M_AXI_HPM0_FPD     | PS→PL     | Control + data path to PL IPs     |
| pl_ps_irq0         | PL→PS     | Interrupt input (3 sources)       |
| pl_clk0            | PS→PL     | 100 MHz PL fabric clock           |
| pl_resetn0         | PS→PL     | Active-low reset                  |

All other PS-PL interfaces must be **disabled** (M_AXI_HPM1_FPD, S_AXI_HPC0_FPD,
S_AXI_HP0_FPD, etc.) to avoid validation errors from unconnected clocks.

**Note**: No HP/HPC slave ports are needed because DMA reads/writes go to PL BRAM,
not PS DDR. All traffic flows through M_AXI_HPM0_FPD.

## 3. PL IP Configuration

### 3.1 AXI DMA (`axi_dma`)

| Parameter                            | Value    | Rationale                    |
|--------------------------------------|----------|------------------------------|
| c_include_sg                         | 0        | Simple mode, no scatter-gather |
| c_sg_length_width                    | 14       | Max transfer: 16 KB (BRAM-sized) |
| c_m_axi_mm2s_data_width              | 64       | Match BRAM controller width  |
| c_m_axi_s2mm_data_width              | 64       | Match BRAM controller width  |
| c_m_axis_mm2s_tdata_width            | 64       | Match axis_filter width     |
| c_s_axis_s2mm_tdata_width            | 64       | Match axis_filter width     |
| c_include_mm2s_dre                   | 1        | Data realignment engine      |
| c_include_s2mm_dre                   | 1        | Data realignment engine      |

### 3.2 AXI BRAM Controller (`axi_bram_ctrl`)

| Parameter              | Value | Rationale                          |
|------------------------|-------|------------------------------------|
| DATA_WIDTH             | 64    | Match DMA data width               |
| SINGLE_PORT_BRAM       | 1     | One BRAM port (single AXI slave)   |

### 3.3 Block Memory Generator (`blk_mem_gen`)

| Parameter              | Value     | Rationale                          |
|------------------------|-----------|------------------------------------|
| Memory Type            | True Dual Port RAM | Pairs with BRAM controller |
| Write Width A          | 64        | Match BRAM controller              |
| Write Depth A          | 2048      | 16 KB total (2048 × 8 bytes)       |

The BRAM controller IP will auto-configure the Block Memory Generator when
connected via the BRAM interface. Use the BRAM controller defaults.

### 3.4 AXI Timer (`axi_timer`)

Default configuration. Provides two 32-bit timer/counters with interrupt.

### 3.5 Interconnect

| Component            | Configuration              | Purpose                             |
|----------------------|----------------------------|--------------------------------------|
| AXI SmartConnect     | 3 SI, 3 MI                 | PS + DMA_MM2S + DMA_S2MM → DMA regs, Timer, BRAM |
| Proc Sys Reset       | 1 instance                 | Synchronize pl_resetn0               |
| Concat (xlconcat)    | 3 inputs                   | DMA mm2s_irq, s2mm_irq, timer_irq → pl_ps_irq0  |

Masters connecting to SmartConnect:
- SI[0]: PS M_AXI_HPM0_FPD (CPU access to all peripherals)
- SI[1]: DMA M_AXI_MM2S (reads source data from BRAM)
- SI[2]: DMA M_AXI_S2MM (writes result data to BRAM)

Slaves connecting to SmartConnect:
- MI[0]: AXI DMA S_AXI_LITE (control registers)
- MI[1]: AXI Timer S_AXI
- MI[2]: AXI BRAM Controller S_AXI (data buffer)

## 4. Address Map

All peripherals are in the PS M_AXI_HPM0_FPD address space and accessible
by CPU, DMA MM2S, and DMA S2MM masters:

| Peripheral      | Base Address  | Size   | Accessed By           |
|-----------------|---------------|--------|-----------------------|
| AXI DMA         | 0xA000_0000   | 64 KB  | CPU only              |
| AXI Timer       | 0xA001_0000   | 64 KB  | CPU only              |
| AXI BRAM Ctrl   | 0xA002_0000   | 16 KB  | CPU + DMA MM2S + S2MM |

**BRAM layout** (within AXI BRAM Controller address range):

| Region          | Offset       | Size  | Purpose               |
|-----------------|-------------|-------|------------------------|
| Source buffer   | 0x0000      | 4 KB  | CPU writes test data   |
| Destination buf | 0x1000      | 4 KB  | DMA writes results     |

DMA source address = BRAM base + 0x0000 = 0xA002_0000
DMA destination address = BRAM base + 0x1000 = 0xA002_1000

## 5. Pin Constraints

**None.** This design has no external I/O pins. All verification is via
register access through `/dev/mem`.

## 6. Clocking

| Clock     | Frequency | Source   | Domain                  |
|-----------|-----------|----------|-------------------------|
| pl_clk0   | 100 MHz   | PS PLL   | All PL logic            |

Single clock domain — no CDC required.

## 7. Data Path

```
CPU (devmem2)
    ↓ write test data
[M_AXI_HPM0_FPD] → SmartConnect → AXI BRAM Controller → BRAM (source region)
    ↓ start DMA
AXI DMA MM2S ← SmartConnect ← AXI BRAM Controller ← BRAM (source region)
    ↓ AXI-Stream (64-bit)
axis_filter (passthrough)
    ↓ AXI-Stream (64-bit)
AXI DMA S2MM → SmartConnect → AXI BRAM Controller → BRAM (dest region)
    ↓ read results
CPU (devmem2) ← SmartConnect ← AXI BRAM Controller ← BRAM (dest region)
```

## 8. Verification Plan

> **Important:** The BRAM controller uses 64-bit data width. Use **8-byte
> aligned addresses only** (0x0, 0x8, 0x10, …) when accessing BRAM with
> `devmem2`. Accesses to 4-byte-only-aligned addresses (0x4, 0xC, …)
> will cause a Bus Error.

### 8.1 Write Test Data to BRAM Source Region
```bash
sudo devmem2 0xA0020000 w 0xDEADBEEF   # word @ offset 0x00
sudo devmem2 0xA0020008 w 0x12345678   # word @ offset 0x08
sudo devmem2 0xA0020010 w 0xCAFEBABE   # word @ offset 0x10
sudo devmem2 0xA0020018 w 0xA5A5A5A5   # word @ offset 0x18
```

### 8.2 Start DMA Transfer
```bash
# Reset DMA
sudo devmem2 0xA0000000 w 0x00000004   # MM2S control: reset
sudo devmem2 0xA0000030 w 0x00000004   # S2MM control: reset

# Start MM2S and S2MM channels
sudo devmem2 0xA0000000 w 0x00000001   # MM2S control: run
sudo devmem2 0xA0000030 w 0x00000001   # S2MM control: run

# Set destination address (S2MM)
sudo devmem2 0xA0000048 w 0xA0021000   # S2MM dest addr = BRAM dest region

# Set source address (MM2S)
sudo devmem2 0xA0000018 w 0xA0020000   # MM2S source addr = BRAM source region

# Set transfer lengths (triggers transfer)
sudo devmem2 0xA0000058 w 32           # S2MM length = 32 bytes
sudo devmem2 0xA0000028 w 32           # MM2S length = 32 bytes (starts xfer)
```

### 8.3 Check DMA Status
```bash
sudo devmem2 0xA0000004 w              # MM2S status (expect bit 1 = Idle)
sudo devmem2 0xA0000034 w              # S2MM status (expect bit 1 = Idle)
```

### 8.4 Read Results from BRAM Destination Region
```bash
sudo devmem2 0xA0021000 w              # expect 0xDEADBEEF
sudo devmem2 0xA0021008 w              # expect 0x12345678
sudo devmem2 0xA0021010 w              # expect 0xCAFEBABE
sudo devmem2 0xA0021018 w              # expect 0xA5A5A5A5
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
