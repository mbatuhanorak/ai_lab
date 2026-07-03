# Timing Closure Prototype

**Category:** Design Closure
Iterative timing analysis, constraint generation, and re-implementation — fully AI-driven.

## Overview

Timing closure is the most challenging and time-consuming phase of FPGA design. This example includes **two complementary agent skills** that work together as a complete methodology:

1. **`post-route-dcp-analysis`** — Opens a routed DCP, classifies all failing timing paths by root cause (CDC, SLR crossing, high fanout, long logic), and walks you through each category interactively — highlighting one representative critical path per category in the Vivado GUI with distinct colors. This gives you a clear visual understanding of *what's wrong* and *where* before applying any fixes.

2. **`timing-closure-prototype`** — Takes the classified violations and generates a `timing_fixes.xdc` constraint file with real design names, reruns implementation, and validates — iterating up to 3 times until timing closes or escalation is needed.

The recommended workflow is: **analyze first** (skill 1), then **fix** (skill 2).

The included design — `top_design` — is intentionally constructed with multiple categories of timing violations on an SSI (multi-SLR) device, making it an ideal training ground for the full timing closure methodology.

> **Note:** This skill requires a **running Vivado MCP server** to open DCPs, run reports, apply constraints, and rerun implementation interactively.

## What's Included

```
timing-closure-prototype/
├── src/
│   └── top_design.sv                                       # Multi-clock datapath (SystemVerilog)
├── constraints/
│   └── top_design.xdc                                      # Placement & clock constraints
├── recreate_project.tcl                                     # Build script (creates IPs, runs synth+impl)
├── timing_fixes.xdc                                         # Reference: generated fixes from a successful run
├── prompts.md                                               # Prompt library (copy-paste examples)
└── .claude/skills/
    ├── post-route-dcp-analysis/                             # Skill 1: Analyze & visualize
    │   ├── SKILL.md                                         # Two-phase analysis + GUI highlighting
    │   └── reference/
    │       ├── classification.md                            # Path classification rules & Tcl
    │       └── highlighting.md                              # Color-coded highlighting procedure
    └── timing-closure-prototype/                            # Skill 2: Fix & iterate
        ├── SKILL.md                                         # Three-phase iterative fix flow
        └── reference/
            ├── classification.md                            # Path classification rules & Tcl
            ├── cdc-fixes.md                                 # CDC constraint patterns
            ├── slr-fixes.md                                 # SLR crossing fix escalation
            ├── fanout-fixes.md                              # High fanout constraint patterns
            ├── logic-fixes.md                               # Long logic fix patterns
            ├── rerun-strategy.md                            # Rerun approach selection
            └── validate.md                                  # Result validation & iteration logic
```

## Two-Skill Workflow

```
┌─────────────────────────────────────────────────────────┐
│  SKILL 1: post-route-dcp-analysis                       │
│                                                         │
│  Phase 1: ANALYZE                                       │
│  • Open routed DCP                                      │
│  • Capture baseline (WNS, TNS, failing path count)      │
│  • Classify paths: CDC / SLR / Fanout / Logic           │
│  • DONT_TOUCH census                                    │
│  ──── USER GATE 1: Review classification ────           │
│                                                         │
│  Phase 2: HIGHLIGHT (Interactive)                       │
│  • Walk through each category one at a time             │
│  • Highlight representative critical path in Vivado GUI │
│  • Color-coded: Red=CDC, Blue=SLR, Orange=Fanout,       │
│    Green=Long Logic                                     │
│  • Show report_timing for each path                     │
│  ──── USER GATE per category ────                       │
│  • Optional: composite view with all categories         │
├─────────────────────────────────────────────────────────┤
│  SKILL 2: timing-closure-prototype                      │
│                                                         │
│  Phase 1: GENERATE CONSTRAINTS                          │
│  • Read category-specific reference files               │
│  • Generate timing_fixes.xdc with real names            │
│  • Verify constraints parse without errors              │
│  ──── USER GATE: Review constraints ────                │
│                                                         │
│  Phase 2: RERUN & VALIDATE                              │
│  • Select rerun strategy (property/constraint/full)     │
│  • Rerun implementation                                 │
│  • Compare against baseline                             │
│  • If improved but failing: iterate (max 3)             │
│  • If timing met: report success                        │
│  • If regression: escalate with RTL recommendations     │
└─────────────────────────────────────────────────────────┘
```

## Step-by-Step Instructions

### Step 1 — Build the design

Build the project from source (creates Clocking Wizard IPs, runs synthesis and implementation):

```bash
cd timing-closure-prototype/
vivado -mode batch -source recreate_project.tcl
```

This produces a routed DCP at `top_design/top_design.runs/impl_1/top_design_routed.dcp`.

### Step 2 — Verify MCP server is configured

Ensure your MCP configuration is set up.

> **Important:** This example requires a running Vivado MCP server. The agent uses `vivado_start` and `vivado_execute` to open DCPs, run timing reports, apply constraints, and rerun implementation.

### Step 3 — Analyze and visualize (Skill 1)

Run the post-route-dcp-analysis skill to understand and see the timing violations:

```
Open the routed DCP top_design/top_design.runs/impl_1/top_design_routed.dcp and run the post-route-dcp-analysis skill to classify and highlight the failing paths.
```

The agent will:
- Classify all failing paths by root cause
- Walk you through each category interactively, highlighting one representative critical path per category in the Vivado GUI with distinct colors (Red=CDC, Blue=SLR, Orange=Fanout, Green=Long Logic)
- Show `report_timing` for each highlighted path

### Step 4 — Fix timing violations (Skill 2)

Once you understand the violations, run the timing-closure-prototype skill to fix them:

```
Now run the timing-closure-prototype skill to generate constraints and close timing.
```

The agent will:
- Generate `timing_fixes.xdc` with category-specific constraints using real cell/net/clock names
- Present the constraints for review (user gate)
- Rerun implementation and compare against baseline
- Iterate up to 3 times until timing closes

### Step 5 — What to expect

**Skill 1 (post-route-dcp-analysis):**

1. **Start Vivado** via MCP and open the routed DCP
2. **Capture baseline** — WNS, TNS, and total failing path count
3. **Run reports** — `report_timing_summary`, `report_clock_interaction`, `report_cdc`, `report_design_analysis`
4. **DONT_TOUCH census** — count sequential/combinational/net DONT_TOUCH properties
5. **Classify every failing path** into exactly one category using priority rules
6. **Present analysis** (USER GATE) — summary table with category counts and color legend
7. **Interactive walkthrough** — highlight one representative path per category in the Vivado GUI, one at a time, with `report_timing` for each
8. **Composite view** (optional) — all categories highlighted together

**Skill 2 (timing-closure-prototype):**

9. **Generate `timing_fixes.xdc`** — category-specific constraints using real cell/net/clock names
10. **Present constraints** (USER GATE) — full XDC file for review
11. **Rerun implementation** — apply constraints, re-place, re-route
12. **Validate** — compare WNS/TNS/failing paths against baseline

> **Human-in-the-Loop:** Both skills enforce mandatory user gates. The agent pauses at each decision point, waiting for your explicit approval before proceeding.

> **Tip:** See `prompts.md` for a full library of prompts for both skills.

## Path Classification

| Priority | Category | Color | Condition | Fix Approach |
|----------|----------|-------|-----------|-------------|
| 1 | **CDC** | 🔴 Red | Different source/destination clocks, unsafe interaction | `set_false_path` or `set_max_delay -datapath_only` |
| 2 | **SLR Crossing** | 🔵 Blue | Different SLRs, same clock domain | Register slicing, Pblock, or Laguna flops |
| 3 | **High Fanout** | 🟠 Orange | Fanout > 1000, route delay > 80% | `MAX_FANOUT` constraint, driver replication |
| 4 | **Long Logic** | 🟢 Green | Logic levels exceed frequency threshold | `LUT_REMAP`, pipeline insertion, `opt_design -remap` |

## Reference Output

The included `timing_fixes.xdc` shows the constraints from a successful run that closed all timing (WNS improved from **-0.753 ns** to **+0.824 ns**, eliminating all 2,348 failing endpoints). Compare your agent's output against this reference.

## What You'll Learn

- How to **visually identify** timing violations in the Vivado GUI with color-coded path highlighting
- How a **two-skill workflow** (analyze & visualize → fix & iterate) provides full visibility before taking action
- How to classify failing paths by root cause — CDC crossings, SLR boundaries, high fanout nets, and deep logic levels
- How the skill generates **real XDC constraints** (not templates) using actual cell/net/clock names
- How **DONT_TOUCH properties** interact with optimization — why removing DT from both **cells AND nets** is critical for remap
- How **user gates** keep you in control — the agent presents analysis and constraints for review before applying changes
- How to evaluate convergence across iterations and decide when to escalate to RTL changes

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
