# AXI4 Debug Simulation — Prompt Library

Copy-paste any of these prompts into your AI agent chat after the project has been created with `scripts/create_project.tcl`.

---

## Getting Started

**First-time run (recommended):**
```
Open the axi_master_sim project, list the simulation filesets, and run the sim_bugs testbenches to find and fix AXI protocol violations.
```

**If you know which testbench to start with:**
```
Run tb_axi_master_bug2 from the sim_bugs fileset. Show me the protocol violation and open a waveform.
```

---

## Debug Prompts

**Run all bug testbenches sequentially:**
```
Run each testbench in sim_bugs one at a time. For each one, show me the assertion violation and waveform, then wait for me to say "fix it" before reading RTL.
```

**Single testbench debug:**
```
Run tb_axi_master_bug1 and tell me what AXI protocol violation it has.
```

**Waveform with specific signals:**
```
Run tb_axi_master_bug3 and open a waveform showing the write data channel signals (WVALID, WREADY, WDATA, WLAST, WSTRB).
```

**Deep dive on a specific assertion:**
```
What does AXI4_ERRM_AWVALID_RESET mean? Show me the relevant AXI spec rule.
```

---

## Fix Prompts

**Apply the fix:**
```
Fix it — read the RTL and apply the minimal change to resolve this protocol violation.
```

**Verify after fix:**
```
Re-run the simulation to confirm the fix works. Show me the PASS waveform.
```

**Explain the root cause:**
```
Why did the FSM reset to the wrong state? What's the correct reset behavior for AXI masters?
```

---

## Analysis Prompts

**Run baseline (correct DUT):**
```
Run sim_1 (the baseline testbench with the correct DUT) to verify it passes cleanly.
```

**Compare bugs:**
```
After fixing all bugs, summarize what each bug was and what AXI rule it violated.
```

**Protocol compliance summary:**
```
Generate a summary table of all testbenches: assertion name, failure time, root cause, fix applied, and pass/fail result.
```

---

## Learning Prompts

**AXI protocol basics:**
```
Explain the AXI4 handshake protocol — VALID/READY signaling, channel ordering, and burst semantics.
```

**Protocol Checker explained:**
```
What assertions does the AXI Protocol Checker (PG101) check? Which are the most commonly violated?
```

**AXI VIP usage:**
```
How does the AXI VIP slave memory model work? What does it check beyond the Protocol Checker?
```

**Waveform debugging tips:**
```
What signals should I always add to the waveform when debugging AXI protocol violations?
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
