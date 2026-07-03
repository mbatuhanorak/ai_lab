# ILA & VIO Insertion Flow — Prompt Library

---

## Step 1 — Build PL-Only Streaming Pipeline

```
Build the VCK190 project from spec/hardware_spec_vck190.md with RTL sources
from src/. Run through synthesis only.
```

---

## Step 2 — Insert VIO

```
Insert an AXIS-VIO to control and monitor the streaming pipeline.
Output probes: stream_enable (1-bit, init 0), pattern_sel (2-bit, init 0),
bypass_enable (1-bit, init 1). Input probe: packet_count (32-bit).
Validate the design.
```

---

## Step 3 — Insert ILA

```
Insert an AXIS-ILA on the AXI-Stream interface between axis_filter and the
FIFO. Use 1024 sample depth. Validate the design.
```

---

## Step 4 — Build Through PDI

```
Generate output products, implement, and generate PDI. Report timing.
```

---

## Full End-to-End

```
Build the VCK190 project from spec/hardware_spec_vck190.md with RTL from src/.
Insert AXIS-VIO (stream_enable, pattern_sel, bypass_enable outputs; packet_count input).
Insert AXIS-ILA on the filter→FIFO AXI-Stream interface, 1024 depth.
Build through PDI and report timing.
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
