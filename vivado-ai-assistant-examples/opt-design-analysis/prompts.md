# Opt Design Log Analysis — Prompt Library

Copy-paste any of these prompts into your AI agent chat after the project has been recreated with `recreate_project.tcl`.

---

## Getting Started

**First-time analysis (recommended):**
```
Analyze the opt_design log for this project and generate a full report.
```

**If the project isn't open yet:**
```
Open the opt_design_demo project, find the implementation log, and analyze what opt_design did.
```

---

## Analysis Prompts

**Quick summary:**
```
Show me the opt_design summary table — how many cells were created, removed, and constrained in each phase?
```

**Full analysis with recommendations:**
```
Run the opt-design-analysis skill on this project. Give me the full report with per-phase breakdown and recommendations.
```

**Directive check:**
```
What opt_design directive was used? Was it appropriate for this design?
```

**Runtime analysis:**
```
How long did opt_design take? Break down the time per phase.
```

---

## DONT_TOUCH / MARK_DEBUG Analysis

**Constraint impact overview:**
```
How many constrained objects are blocking optimization? Which phases are most affected?
```

**debug_log deep-dive:**
```
The log was run with -debug_log. Show me exactly which cells and nets have DONT_TOUCH and how much optimization they are blocking per phase.
```

**Constraint attribution:**
```
Group the [Opt 31-1019] messages by constraint type. Which DONT_TOUCH cells are blocking the most optimization across all phases?
```

**Actionable cleanup:**
```
Which DONT_TOUCH attributes can be safely removed to improve optimization? Are any of them blocking optimization in 4+ phases?
```

---

## Phase-Specific Analysis

**Retarget phase:**
```
What did the retarget phase do? Were any inverters pushed or pulled? Were any blocked by DONT_TOUCH?
```

**Sweep phase:**
```
How many cells did sweep remove? Were any cells skipped due to DONT_TOUCH? Show me the [Opt 31-55] messages.
```

**Constant propagation:**
```
How many constant propagation starting points were found? Did DONT_TOUCH block any propagation?
```

**BUFG insertion:**
```
Were any BUFGs inserted for high-fanout nets? How many loads were on each?
```

**Remap phase:**
```
Did the remap phase optimize any LUTs? How many constrained objects blocked remap?
```

---

## Recommendation Prompts

**What to do next:**
```
Based on the opt_design analysis, what should I do next to improve QoR? Should I re-run with different options?
```

**Directive comparison:**
```
I used ExploreWithRemap. Would a different directive have been better for this design? What about Explore vs ExploreArea?
```

**Re-run with debug_log:**
```
The log shows constrained objects but no detail. Re-run opt_design with -debug_log and analyze the results.
```

**Second pass evaluation:**
```
Should I run opt_design a second time? Would a second pass yield meaningful improvements?
```

---

## Learning Prompts

**Explain the phases:**
```
Walk me through each opt_design phase and explain what it does. Reference the phases that ran in this design.
```

**Understand constrained objects:**
```
What are "constrained objects" in the opt_design summary? Why do DONT_TOUCH and MARK_DEBUG block optimization?
```

**debug_log explained:**
```
What does the -debug_log flag do? How do I interpret [Opt 31-1019] and [Opt 31-1020] messages?
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
