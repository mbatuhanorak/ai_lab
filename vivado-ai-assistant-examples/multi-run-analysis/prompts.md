# Multi-Run Analysis — Prompt Library

Copy-paste any of these prompts into your AI agent chat after the project has been recreated with `recreate_project.tcl`.

---

## Getting Started

**First-time run (recommended):**
```
Run the multi-run-analysis skill on this project.
```

**If the project isn't open yet:**
```
Open the multi_channel_proc project and compare the timing results across all implementation runs.
```

---

## Analysis Prompts

**Full QoR comparison with dashboard:**
```
Run the multi-run-analysis skill on this project. Generate the full report with timing comparison, strategy extraction, and the interactive dashboard.
```

**Quick ranking:**
```
Rank all implementation runs by WNS. Which strategy performed best and why?
```

**Timing progression deep-dive:**
```
Show me the timing progression (post-place → phys_opt → post-route) for each run. Where is timing degrading the most?
```

**Strategy impact analysis:**
```
Compare the strategies used across all runs. Which directives had the most positive impact on timing?
```

---

## Focused Analysis

**Congestion comparison:**
```
Compare congestion metrics across all runs. Are any runs congestion-limited?
```

**Utilization comparison:**
```
Compare resource utilization across all runs. Are there significant differences in LUT, FF, or DSP usage?
```

**Find anomalies:**
```
Check all runs for anomalies — incomplete runs, hold violations, or unexpected timing degradation.
```

**Critical path analysis:**
```
Which clock domain is failing? Is it the same across all runs, or does it vary by strategy?
```

---

## Recommendation Prompts

**Next steps:**
```
Based on the multi-run comparison, what implementation strategy should I try next to close timing?
```

**Directive exploration:**
```
The best run used Performance_Explore. What additional directives or sub-directives should I try to improve WNS further?
```

**Pipeline insertion guidance:**
```
The design has structural timing violations. Where should I add pipeline registers to close the gap?
```

---

## Learning Prompts

**Explain the results:**
```
Explain the multi-run comparison results. Why does one strategy outperform another? What does timing progression tell us?
```

**Strategy best practices:**
```
Based on these results, what are the best practices for choosing implementation strategies in Vivado? Reference UG904 where applicable.
```

**Dashboard walkthrough:**
```
Walk me through each tab of the dashboard. What should I look for in each chart?
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
