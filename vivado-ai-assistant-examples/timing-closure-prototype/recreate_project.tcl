# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# recreate_project.tcl
# ============================================================================
# Recreate the top_design project for xcvu5p-flva2104-2-e.
#
# Usage:
#   cd <this_directory>
#   vivado -mode batch -source recreate_project.tcl
#
# Produces:  top_design/top_design.runs/impl_1/top_design.dcp
# ============================================================================

set script_dir  [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir top_design]

# Remove old project if it exists
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

# ---- Create project --------------------------------------------------------
create_project top_design $project_dir -part xcvu5p-flva2104-2-e -force

# ---- Add RTL source --------------------------------------------------------
add_files -norecurse [file join $script_dir src top_design.sv]
set_property file_type SystemVerilog [get_files top_design.sv]

# ---- Add constraints --------------------------------------------------------
add_files -fileset constrs_1 -norecurse [file join $script_dir constraints top_design.xdc]

# ---- Create Clocking Wizard IPs --------------------------------------------

# MMCM1: sys_clk (100 MHz) → clk_a (333.333 MHz)
#                            + clk_slr (500 MHz)
#                            + clk_combo (500 MHz)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name mmcm1_ip

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ        {100.000} \
    CONFIG.CLKOUT1_USED        {true} \
    CONFIG.CLKOUT2_USED        {true} \
    CONFIG.CLKOUT3_USED        {true} \
    CONFIG.CLK_OUT1_PORT       {clk_a} \
    CONFIG.CLK_OUT2_PORT       {clk_slr} \
    CONFIG.CLK_OUT3_PORT       {clk_combo} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {333.333} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {500.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {500.000} \
    CONFIG.USE_LOCKED          {true} \
    CONFIG.USE_RESET           {true} \
    CONFIG.RESET_TYPE          {ACTIVE_LOW} \
] [get_ips mmcm1_ip]

generate_target all [get_ips mmcm1_ip]

# MMCM2: clk_b_ref (100 MHz) → clk_b (350 MHz)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 \
    -module_name mmcm2_ip

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ        {100.000} \
    CONFIG.CLKOUT1_USED        {true} \
    CONFIG.CLK_OUT1_PORT       {clk_b} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {350.000} \
    CONFIG.USE_LOCKED          {true} \
    CONFIG.USE_RESET           {true} \
    CONFIG.RESET_TYPE          {ACTIVE_LOW} \
] [get_ips mmcm2_ip]

generate_target all [get_ips mmcm2_ip]

# ---- Set top module --------------------------------------------------------
set_property top top_design [current_fileset]

# ---- Synthesize -------------------------------------------------------------
puts "INFO: Launching synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis failed — check logs."
}

# ---- Implement (place + route) ----------------------------------------------
puts "INFO: Launching implementation..."
launch_runs impl_1 -to_step route_design -jobs 8
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] ne "route_design Complete!"} {
    puts "WARNING: Implementation finished with status: [get_property STATUS [get_runs impl_1]]"
}

puts "INFO: Done.  DCP: $project_dir/top_design.runs/impl_1/top_design.dcp"
