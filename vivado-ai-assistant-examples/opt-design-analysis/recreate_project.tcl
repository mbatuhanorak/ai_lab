# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# recreate_project.tcl — Create opt_design_demo project and run synth + opt_design
#
# Usage:
#   cd opt-design-analysis/
#   vivado -mode batch -source recreate_project.tcl
#
# This creates the project in ./opt_design_demo/, runs synthesis, then runs
# opt_design twice:
#   1. opt_design -directive ExploreWithRemap            (standard)
#   2. opt_design -directive ExploreWithRemap -debug_log  (with debug detail)
#
# The debug_log output reveals which specific cells/nets are constrained
# (DONT_TOUCH, MARK_DEBUG) and blocking optimization in each phase.

set project_name "opt_design_demo"
set project_dir  [file join [pwd] $project_name]
set part         "xcu200-fsgd2104-2-e"
set top          "opt_design_demo"

# Clean up any previous run
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

# Create project
create_project $project_name $project_dir -part $part -force
set_property target_language Verilog [current_project]

# Add source files (import copies into .srcs)
import_files -fileset sources_1 [list \
    [file join [pwd] src opt_design_demo.v] \
    [file join [pwd] src bram_block.v] \
]

# Add constraints
import_files -fileset constrs_1 [file join [pwd] constraints constraints.xdc]

# Set top module
set_property top $top [current_fileset]
update_compile_order -fileset sources_1

# ============================================
# Run synthesis
# ============================================
puts ""
puts "============================================"
puts "Running synthesis..."
puts "============================================"

launch_runs synth_1 -jobs 4
wait_on_runs synth_1

# Open synthesized design
open_run synth_1

# ============================================
# Run opt_design with -debug_log
# ============================================
puts ""
puts "============================================"
puts "Running opt_design -debug_log..."
puts "============================================"

opt_design -directive ExploreWithRemap -debug_log

# Save the implementation checkpoint
write_checkpoint -force [file join $project_dir "${top}_opt.dcp"]

puts ""
puts "============================================"
puts "opt_design complete."
puts "============================================"
puts ""
puts "Project: [file join $project_dir ${project_name}.xpr]"
puts "Checkpoint: [file join $project_dir ${top}_opt.dcp]"
puts "Log: [file join $project_dir vivado.log]"
