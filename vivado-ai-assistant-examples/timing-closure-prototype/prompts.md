# Timing Closure Prototype — Prompt Library

Copy-paste any of these prompts into your AI agent chat after building the design.

---

## Recommended Flow (Two Skills)

**Step 1 — Analyze & visualize (post-route-dcp-analysis skill):**
```
Open the routed DCP top_design/top_design.runs/impl_1/top_design_routed.dcp and run the post-route-dcp-analysis skill to classify and highlight the failing paths.
```

**Step 2 — Fix & iterate (timing-closure-prototype skill):**
```
Now run the timing-closure-prototype skill to generate constraints and close timing.
```

---

## Analysis Prompts (Skill 1: post-route-dcp-analysis)

**Classify and highlight:**
```
Open the routed DCP and classify all failing timing paths. Highlight one representative path per category in the Vivado GUI.
```

**Show all categories together:**
```
Show all highlighted categories in a composite view with the color legend.
```

**Focus on one category:**
```
Just show me the CDC violations — highlight the worst CDC path in the device view.
```

---

## Getting Started (Skill 2: timing-closure-prototype)

**Full timing closure flow (if skipping Skill 1):**
```
Open the routed DCP top_design/top_design.runs/impl_1/top_design_routed.dcp and run the timing-closure-prototype skill to analyze and fix timing violations.
```

**If Vivado is already running:**
```
Run the timing-closure-prototype skill on the current design. Classify the failing paths and generate fix constraints.
```

---

## Analysis Prompts

**Baseline capture:**
```
Open top_design/top_design.runs/impl_1/top_design.dcp and tell me: what's the WNS, TNS, and how many paths are failing?
```

**Classification breakdown:**
```
Classify all failing timing paths into categories: CDC, SLR crossing, high fanout, and long logic. Show me a summary table.
```

**Worst paths per category:**
```
Show me the worst failing path in each violation category with the clock pair, logic levels, and slack.
```

---

## Fix Generation Prompts

**Generate constraints:**
```
Generate timing_fixes.xdc with constraints for all classified violations. Show me the file before applying.
```

**Category-specific fixes:**
```
Focus only on the CDC violations. What constraints would fix the async clock crossings?
```

**SLR crossing fixes:**
```
What SLR crossing violations exist? Should I use register slicing, Pblock adjustments, or Laguna flops?
```

**High fanout analysis:**
```
Which nets have high fanout causing timing failures? What's the recommended MAX_FANOUT constraint?
```

---

## Iteration Prompts

**Rerun implementation:**
```
Apply the timing_fixes.xdc and rerun implementation. Compare results against the baseline.
```

**Continue iterating:**
```
The first iteration improved WNS but timing still isn't met. Continue to iteration 2.
```

**Validate results:**
```
Compare the current WNS/TNS against the baseline and each iteration. Are we converging?
```

---

## Learning Prompts

**Explain the flow:**
```
Walk me through the timing closure methodology. Why do we classify paths before generating constraints?
```

**Constraint best practices:**
```
What are the guardrails for timing constraints? What mistakes should I avoid with DONT_TOUCH and set_clock_groups?
```

**Rerun strategies:**
```
When should I do a property-only rerun vs. a full re-implementation? What's the tradeoff?
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
