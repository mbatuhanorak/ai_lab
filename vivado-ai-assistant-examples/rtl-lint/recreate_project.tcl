# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# recreate_project.tcl — Create packet_processor project for RTL lint analysis
#
# Usage:
#   cd rtl-lint/
#   vivado -mode batch -source recreate_project.tcl
#
# This creates the project, adds source files and constraints.
# The design is intentionally constructed with lintable issues for the
# RTL lint skill to detect and fix.

set project_name "packet_processor"
set project_dir  [file join [pwd] $project_name]
set part         "xcvu9p-flga2104-2L-e"
set top          "packet_processor"

# Clean up any previous run
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

# Create project
create_project $project_name $project_dir -part $part -force
set_property target_language Verilog [current_project]

# Add source files
add_files -fileset sources_1 [file join [pwd] src packet_processor.sv]

# Add constraints
add_files -fileset constrs_1 [file join [pwd] constraints packet_processor.xdc]

# Set top module
set_property top $top [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "============================================"
puts "Project created: $project_dir/${project_name}.xpr"
puts "Top module: $top"
puts "Part: $part"
puts "============================================"
puts ""
puts "To run RTL lint:"
puts "  synth_design -rtl -name rtl_1 -lint"
puts ""
