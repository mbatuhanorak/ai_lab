# Multi-Run Analysis

**Category:** Design Analysis
Compare results across multiple implementation runs to find the best strategy.

## Overview

When exploring implementation strategies, you often run multiple configurations — different placement directives, physical optimization settings, or congestion strategies. This example uses an AI agent to compare results across 6 implementation runs, rank them by QoR, and explain *why* one strategy outperforms another.

The included design — an 8-channel DSP pipeline processor with crossbar routing, per-channel statistics engines, and a configuration register bank — is constrained at 275 MHz on a `-3` speed grade part. The mix of DSPs (128), BRAMs (8 histograms), wide crossbar routing, and high-fanout config registers creates genuine differentiation between strategies.

## What's Included

```
multi-run-analysis/
├── recreate_project.tcl                   # Tcl script to build project & run all 6 implementations
├── src/
│   ├── dsp_pipeline.sv                    # 16-tap FIR filter with pre-adder
│   ├── multi_channel_processor.sv         # 8-channel top-level with crossbar + config regs
│   └── stats_engine.sv                    # Per-channel statistics with BRAM histogram
├── constraints/
│   └── multi_channel_processor.xdc        # 275 MHz clock constraint
├── prompts.md                             # Prompt library (copy-paste examples)
└── .claude/skills/multi-run-analysis/     # Bundled agent skill
    ├── SKILL.md                           # Skill instructions
    ├── TEMPLATES.md                       # Report & JSON schema templates
    └── DASHBOARD_TEMPLATE.html            # Interactive Chart.js dashboard
```

## Step-by-Step Instructions

### Step 1 — Recreate the project and run implementations

This script creates the Vivado project, runs synthesis, and launches 6 implementation runs with different strategies:

```bash
cd multi-run-analysis/
vivado -mode batch -source recreate_project.tcl
```

> **Note:** This takes approximately 20–30 minutes. The script runs synthesis + 6 implementations in parallel.

The script creates a project targeting `xcvu9p-flga2104-3-e` and configures these 6 runs:

| Run | Strategy | Description |
|-----|----------|-------------|
| impl_1 | Vivado Implementation Defaults | Baseline — default directives |
| impl_2 | Performance_Explore | Explore directives across all phases |
| impl_3 | Performance_ExtraTimingOpt | ExtraTimingOpt placement + NoTimingRelaxation routing |
| impl_4 | Performance_NetDelay_high | Focus on reducing high-delay nets |
| impl_5 | Congestion_SpreadLogic_high | AltSpreadLogic_high + AggressiveExplore + AlternateCLBRouting |
| impl_6 | Area_ExploreWithRemap | Minimize area with LUT remapping (may sacrifice timing) |

### Step 2 — Verify MCP server is configured

Ensure your MCP configuration is set up.

> **Note:** No live Vivado session is needed. The analysis skill parses existing report files — it does not require a running Vivado session.

### Step 3 — Run the multi-run-analysis skill

Open the project folder in your IDE and start the AI agent:

**Full analysis:**
```
Run the multi-run-analysis skill on this project.
```

**Quick comparison:**
```
Compare all implementation runs and rank them by WNS. Which strategy performed best?
```

**Timing progression:**
```
Show me the timing progression (post-place → phys_opt → post-route) for each run. Where is timing degrading?
```

> **Tip:** See `prompts.md` for a full library of analysis prompts.

### Step 4 — What to expect

The agent will:

1. Discover all `impl_*` run directories under the project's `.runs/` folder
2. Extract timing QoR (WNS, TNS, WHS, THS) from each run's timing summary report
3. Extract strategies and directives from each run's Tcl scripts
4. Extract utilization metrics (LUT, FF, DSP) from utilization reports
5. Extract timing progression data (post-place → phys_opt → post-route)
6. Extract congestion metrics from placement logs
7. Detect anomalies (incomplete runs, hold issues, timing reversals)
8. Generate three output files under `vivado_agentic_ai_reports/multi-run-analysis/`:
    - `REPORT.md` — executive dashboard, ranked comparison, and recommendations
    - `report_data.json` — structured data for visualization
    - `dashboard.html` — interactive Chart.js dashboard (5 tabs)

### Step 5 — View the dashboard

After the skill completes, start a local HTTP server to view the interactive dashboard:

```bash
cd multi_channel_proc/vivado_agentic_ai_reports/multi-run-analysis
python3 -m http.server 8080
```

Then open `http://localhost:8080/dashboard.html` in a browser.

The dashboard has **5 tabs**:

| Tab | What It Shows |
|-----|---------------|
| **Timing** | WNS/TNS bar charts + full comparison table |
| **PnR Progression** | Post-place → phys_opt → post-route WNS waterfall per run |
| **Strategy Impact** | Grouped strategy analysis with verdict |
| **Congestion** | Per-direction congestion heatmap |
| **Run Details** | Anomalies, next steps, and full data table |

## Expected Results

With the 275 MHz constraint on the `-3` speed grade, the 6 runs will show meaningful variation in timing results. The larger design (128 DSPs + 8 BRAMs + wide crossbar + config fanout) creates genuine competition between strategies:

- **Performance-focused strategies** (Explore, ExtraTimingOpt, NetDelay_high) optimize the DSP accumulator chains and crossbar timing differently
- **Congestion-focused** (SpreadLogic_high) reduces routing pressure from the 8×8 crossbar but may relax critical paths
- **Area-focused** (ExploreWithRemap) packs logic tighter, which can help or hurt timing depending on routing congestion
- The **default** strategy provides the baseline to measure improvement or regression

You should see WNS spread of 0.3–0.8 ns across the 6 runs — enough for meaningful ranking and strategy recommendations.

## What You'll Learn

- How **natural language prompts** drive a multi-step analysis workflow — the agent reads implementation reports, extracts metrics, and generates ranked comparisons without you writing any Tcl
- How to structure multi-run strategy sweeps in Vivado for design space exploration
- How the skill parses existing report files (no live Vivado session needed for analysis)
- How to interpret **timing progression** to understand whether timing degrades during placement, phys_opt, or routing
- How to use the interactive dashboard for visual comparison across runs

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
