# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# recreate_project.tcl
# Recreates the multi-channel processor project and runs 6 implementation strategies.
#
# Usage:
#   vivado -mode batch -source recreate_project.tcl
#
# This script will:
#   1. Create a Vivado project targeting xcvu9p
#   2. Add RTL source files and constraints
#   3. Run synthesis
#   4. Configure 6 implementation runs with different strategies
#   5. Launch all implementations and wait for completion
#   6. Report timing results for each run
#
# Estimated runtime: ~20-30 minutes (depends on machine)

# -----------------------------------------------------------------
# Configuration — change these if needed
# -----------------------------------------------------------------
set project_name  "multi_channel_proc"
set project_dir   [file join [pwd] $project_name]
set part          "xcvu9p-flga2104-3-e"
set num_jobs      8

# -----------------------------------------------------------------
# Step 1: Create project
# -----------------------------------------------------------------
puts "============================================"
puts "Step 1: Creating project..."
puts "============================================"

if {[file exists $project_dir]} {
    puts "WARNING: Project directory exists. Removing..."
    file delete -force $project_dir
}

create_project $project_name $project_dir -part $part

# -----------------------------------------------------------------
# Step 2: Add source files
# -----------------------------------------------------------------
puts "============================================"
puts "Step 2: Adding source files..."
puts "============================================"

set src_dir [file join [pwd] src]
import_files -fileset sources_1 [glob $src_dir/*.sv]
import_files -fileset constrs_1 [file join [pwd] constraints multi_channel_processor.xdc]
update_compile_order -fileset sources_1
set_property top multi_channel_processor [current_fileset]

# -----------------------------------------------------------------
# Step 3: Run synthesis
# -----------------------------------------------------------------
puts "============================================"
puts "Step 3: Running synthesis..."
puts "============================================"

launch_runs synth_1 -jobs $num_jobs
wait_on_runs synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"
if {[string match "*ERROR*" $synth_status]} {
    puts "ERROR: Synthesis failed. Check logs."
    exit 1
}

# -----------------------------------------------------------------
# Step 4: Configure implementation runs
# -----------------------------------------------------------------
puts "============================================"
puts "Step 4: Configuring 6 implementation runs..."
puts "============================================"

# impl_1 already exists with default strategy
puts "  impl_1: Vivado Implementation Defaults"

# impl_2 — Performance_Explore
create_run impl_2 -parent_run synth_1 -flow {Vivado Implementation 2025}
set_property strategy Performance_Explore [get_runs impl_2]
puts "  impl_2: Performance_Explore"

# impl_3 — Performance_ExtraTimingOpt
create_run impl_3 -parent_run synth_1 -flow {Vivado Implementation 2025}
set_property strategy Performance_ExtraTimingOpt [get_runs impl_3]
puts "  impl_3: Performance_ExtraTimingOpt"

# impl_4 — Performance_NetDelay_high
create_run impl_4 -parent_run synth_1 -flow {Vivado Implementation 2025}
set_property strategy Performance_NetDelay_high [get_runs impl_4]
puts "  impl_4: Performance_NetDelay_high"

# impl_5 — Congestion_SpreadLogic_high
create_run impl_5 -parent_run synth_1 -flow {Vivado Implementation 2025}
set_property strategy Congestion_SpreadLogic_high [get_runs impl_5]
puts "  impl_5: Congestion_SpreadLogic_high"

# impl_6 — Area_ExploreWithRemap
create_run impl_6 -parent_run synth_1 -flow {Vivado Implementation 2025}
set_property strategy Area_ExploreWithRemap [get_runs impl_6]
puts "  impl_6: Area_ExploreWithRemap"

# -----------------------------------------------------------------
# Step 5: Launch all implementations
# -----------------------------------------------------------------
puts "============================================"
puts "Step 5: Launching all implementations..."
puts "============================================"

launch_runs [get_runs impl_*] -jobs $num_jobs
wait_on_runs [get_runs impl_*]

# -----------------------------------------------------------------
# Step 6: Report results
# -----------------------------------------------------------------
puts "============================================"
puts "Step 6: Results"
puts "============================================"
puts ""
puts [format "%-10s %-35s %-10s %-15s" "Run" "Strategy" "WNS(ns)" "TNS(ns)"]
puts [string repeat "-" 75]

foreach run [get_runs impl_*] {
    set status   [get_property STATUS $run]
    set strategy [get_property strategy $run]

    # Open the run's timing summary to extract WNS/TNS
    set run_dir [get_property DIRECTORY $run]
    set rpts [glob -nocomplain [file join $run_dir *timing_summary*.rpt]]
    set wns "N/A"
    set tns "N/A"
    if {[llength $rpts] > 0} {
        set rpt [lindex $rpts end]
        set fp [open $rpt r]
        set content [read $fp]
        close $fp
        # Find the data line after "WNS(ns)"
        if {[regexp {WNS\(ns\).*\n\s+[-]+.*\n\s+([-\d.]+)\s+([-\d.]+)} $content match w t]} {
            set wns $w
            set tns $t
        }
    }
    puts [format "%-10s %-35s %-10s %-15s" $run $strategy $wns $tns]
}

puts ""
puts "============================================"
puts "All runs complete. Open the project to run"
puts "the multi-run-analysis skill."
puts "============================================"
puts ""
puts "Project: [file join $project_dir ${project_name}.xpr]"
