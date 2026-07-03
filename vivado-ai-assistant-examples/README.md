<!-- Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved. -->
<!-- SPDX-License-Identifier: MIT -->

# Vivado AI Assistant Examples

Example designs and AI agent skills for the Vivado MCP Server. Each example includes source files, a prompt library, and most include a bundled skill.

## Examples

| Example | Category | Description | Vivado Session? |
|---------|----------|-------------|------------------|
| **rtl-lint/** | Design Analysis | Run `synth_design -lint` to catch RTL issues before synthesis | Yes |
| **opt-design-analysis/** | Design Analysis | Parse `opt_design -debug_log` for constraint attribution | No (parses logs) |
| **axi4-debug-simulation/** | Design Analysis | Debug AXI4 protocol violations through XSim simulation | Yes |
| **timing-closure-prototype/** | Design Closure | 3-phase timing closure: analyze → generate constraints → rerun | Yes |
| **design-creation-prototype/** | Design Capture | Build a complete block design from a hardware specification | Yes |
| **ila-insertion-flow/** | Hardware Debug | Insert System ILA into block design to debug AXI-Stream data path | Yes |

## Quick Start

1. **Open** one example folder as your workspace in VS Code / Cursor
2. **Build** the design (see each example's `README.md` for instructions)
3. **Configure** MCP server (see EA Lounge Getting Started guide)
4. **Prompt** the AI agent — see `prompts.md` in each example folder

## Prerequisites

- **Vivado 2025.2** or later
- **Vivado MCP Server** configured for your AI tool
- **AI agent** with MCP support (GitHub Copilot in VS Code, Cursor, Claude Code, etc.)

## Structure

Each example follows a similar structure:

```
example-name/
├── README.md                    # Instructions
├── prompts.md                   # Copy-paste prompt library
├── recreate_project.tcl         # Build script (most examples)
├── src/ or rtl/                 # Design source files
├── constraints/                 # Timing/placement constraints (if applicable)
├── spec/                        # Hardware specification (if applicable)
└── .claude/skills/example-name/ # Bundled agent skill (most examples)
    └── SKILL.md                 # Skill instructions
```

## Version

This is version **0.6.7** of the Vivado AI Assistant Examples.
