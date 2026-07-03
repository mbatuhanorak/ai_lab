# RTL Lint

**Category:** Design Analysis
Run `synth_design -lint` to catch RTL issues before full synthesis.

## Overview

RTL linting identifies design issues early — before you spend time on full synthesis. This example runs the Vivado RTL linter through an AI agent that categorizes findings, prioritizes them by severity, and recommends specific fixes.

The included design — a packet processor with header parsing, CRC checking, and an output FSM — contains realistic coding patterns that trigger multiple lint rule categories.

## What's Included

```
rtl-lint/
├── src/
│   └── packet_processor.sv                # SystemVerilog source (intentional lint issues)
├── constraints/
│   └── packet_processor.xdc               # Timing constraints
├── recreate_project.tcl                    # Build script (works with any Vivado version)
├── prompts.md                              # Prompt library (copy-paste examples)
└── .claude/skills/rtl-lint/                # Bundled agent skill
    ├── SKILL.md
    ├── parse_lint_report.py
    └── resolution/                         # 20 rule-specific fix guides
```

## Step-by-Step Instructions

### Step 1 — Open the example

Open the `rtl-lint/` folder as your workspace in VS Code, Cursor, or `cd` into it for CLI tools.

### Step 2 — Verify MCP server is configured

Make sure your MCP configuration points to the Vivado MCP server.

### Step 3 — Build the project

Create the Vivado project from source (works with any Vivado version):

```bash
cd rtl-lint/
vivado -mode batch -source recreate_project.tcl
```

### Step 4 — Run the RTL lint skill

Open your AI agent chat and use one of these prompts:

**Basic:**
```
Run RTL lint on this design using the rtl-lint skill.
```

**With fixes:**
```
Run RTL lint on the packet_processor design, then fix all violations in the source file.
```

**Fix and re-verify:**
```
Run RTL lint, apply fixes to packet_processor.sv, then re-run lint to confirm all issues are resolved.
```

> **Tip:** See `prompts.md` for a full library of beginner → advanced prompts.

### Step 5 — What to expect

The agent will:

1. Open the `packet_processor` project
2. Run `synth_design -top packet_processor -part xcvu9p-flga2104-2L-e -lint`
3. Parse the lint report using the bundled `parse_lint_report.py`
4. Look up each violation in the `resolution/` guides (ASSIGN-3, ASSIGN-6, INFER-1, INFER-2)
5. Generate a structured report with severity, source location, and fix recommendations
6. Optionally apply fixes directly to `packet_processor.sv`

### Step 6 — Review the report

The agent produces a markdown report under `vivado_agentic_ai_reports/rtl-lint/` with:

- **Summary table** — violation counts by rule ID and severity
- **Per-violation details** — source code context, root cause, and recommended fix
- **Hotspot analysis** — which files/modules have the most issues

## Expected Violations

This design triggers **8 violations across 4 rule types**:

| Rule | Severity | Count | What It Catches |
|------|----------|-------|-----------------|
| **ASSIGN-3** | CRITICAL WARNING | 1 | Shift amount exceeds operand width |
| **ASSIGN-6** | WARNING | 1 | Signal assigned but never read |
| **INFER-1** | CRITICAL WARNING | 4 | Unintended latch inference |
| **INFER-2** | CRITICAL WARNING | 2 | Case statement missing default branch |

## What You'll Learn

- How **natural language prompts** drive complete Vivado workflows — you describe what you want, the agent skill translates it into the right sequence of Tcl commands
- How a single prompt like *"Run RTL lint and fix all issues"* triggers a multi-step workflow: project discovery → linter execution → report parsing → resolution guide lookup → code fixes
- How **skills** bridge the gap between your intent and Vivado expertise
- The iterative fix → re-lint loop, driven entirely by conversational prompts

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
