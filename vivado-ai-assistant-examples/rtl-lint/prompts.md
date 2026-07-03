# RTL Lint — Prompt Library

Copy-paste any of these prompts into your AI agent chat to run the RTL lint workflow on this design.

---

## Getting Started

**First-time run:**
```
Run RTL lint on this design using the rtl-lint skill.
```

**If Vivado isn't connected yet:**
```
Connect to Vivado, open the packet_processor project, and run RTL lint.
```

---

## Analysis Prompts

**Full analysis with report:**
```
Run RTL lint on the packet_processor design. Generate a full report with violation counts, severity breakdown, and fix recommendations.
```

**Focus on critical warnings only:**
```
Run RTL lint and show me only the critical warnings. What are the most urgent issues to fix?
```

**Latch inference deep-dive:**
```
Run RTL lint and explain any inferred latch violations. Show me the exact code causing them and how to fix it.
```

---

## Fix & Iterate

**Analyze and fix all issues:**
```
Run RTL lint, then fix all the violations in the source code. Apply the fixes directly to packet_processor.sv.
```

**Fix and re-verify:**
```
Run RTL lint, apply fixes to the source file, then re-run lint to confirm all violations are resolved.
```

**Fix only specific rule:**
```
Run RTL lint. Fix only the INFER-2 (incomplete case statement) violations and leave everything else as-is.
```

---

## Learning Prompts

**Explain what was found:**
```
What RTL quality issues does this design have? Explain each one and why it matters for FPGA implementation.
```

**Best practices review:**
```
Run RTL lint and provide coding best-practice recommendations based on the results. Reference UG901 where applicable.
```

<p class="sphinxhide" align="center"><sub>Copyright © 2026 Advanced Micro Devices, Inc</sub></p>
<p class="sphinxhide" align="center"><sup><a href="https://www.amd.com/en/corporate/copyright">Terms and Conditions</a></sup></p>
