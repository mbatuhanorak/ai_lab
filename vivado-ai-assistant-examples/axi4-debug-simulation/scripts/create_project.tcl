# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# ==============================================================================
# create_project.tcl
#
# Vivado TCL script to create a simulation-only project that verifies custom
# AXI4 Full master DUTs using:
#   - Xilinx AXI VIP (Slave mode with Memory Model)  — PG267
#   - Xilinx AXI Protocol Checker                     — PG101
#
# Usage:
#   Option A — From Vivado GUI:
#     1. Open Vivado
#     2. In the TCL Console: source <path>/scripts/create_project.tcl
#
#   Option B — From command line:
#     vivado -mode batch -source scripts/create_project.tcl
#     vivado -mode batch -source scripts/create_project.tcl -tclargs run_bugs
#     vivado -mode batch -source scripts/create_project.tcl -tclargs run_all
#
# References:
#   - PG267: https://docs.xilinx.com/r/en-US/pg267-axi-vip
#   - PG101: https://docs.xilinx.com/r/en-US/pg101-axi-protocol-checker
#   - UG900: https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation
#   - ARM IHI0022H — AMBA AXI Protocol Specification
# ==============================================================================

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
set project_name  "axi_master_sim"
set part          "xc7a35tcpg236-1"   ;# Artix-7 (Basys3 / Arty A7-35)

set script_dir  [file dirname [file normalize [info script]]]
set repo_dir    [file normalize "$script_dir/.."]
set project_dir [file normalize "$repo_dir/vivado_project"]

puts "============================================================"
puts "  Repository root : $repo_dir"
puts "  Project output  : $project_dir"
puts "  Target part     : $part"
puts "  Protocol        : AXI4 Full"
puts "============================================================"

# --------------------------------------------------------------------------
# Simulation set definitions
#
#   sim_1    — baseline (correct DUT)
#   sim_bugs — 5 buggy DUT variants (bug1, bug2, bug3, bug4, bug5)
# --------------------------------------------------------------------------
set all_simsets {sim_1 sim_bugs}

array set simset_tops {
    sim_1    {tb_axi_master}
    sim_bugs {tb_axi_master_bug1 tb_axi_master_bug2 tb_axi_master_bug3 tb_axi_master_bug4 tb_axi_master_bug5}
}

# --------------------------------------------------------------------------
# 1. Create project
# --------------------------------------------------------------------------
create_project $project_name $project_dir -part $part -force

set_property target_language    Verilog      [current_project]
set_property simulator_language Mixed        [current_project]

# --------------------------------------------------------------------------
# 2. Add RTL design sources (AXI4 Full masters)
# --------------------------------------------------------------------------
puts "Adding design source files..."
add_files -norecurse [list \
    [file normalize "$repo_dir/rtl/axi_master.sv"] \
    [file normalize "$repo_dir/rtl/axi_master_bug1.sv"] \
    [file normalize "$repo_dir/rtl/axi_master_bug2.sv"] \
    [file normalize "$repo_dir/rtl/axi_master_bug3.sv"] \
    [file normalize "$repo_dir/rtl/axi_master_bug4.sv"] \
    [file normalize "$repo_dir/rtl/axi_master_bug5.sv"] \
]
set_property file_type SystemVerilog [get_files "*/rtl/*.sv"]

update_compile_order -fileset sources_1

# --------------------------------------------------------------------------
# 3. Create AXI VIP IP — Slave mode, AXI4 Full, 32-bit, 4-bit ID
#    Reference: PG267 — AXI Verification IP
# --------------------------------------------------------------------------
puts "Creating AXI VIP IP (Slave mode, AXI4 Full)..."

create_ip \
    -name        axi_vip \
    -vendor      xilinx.com \
    -library     ip \
    -version     1.1 \
    -module_name axi_vip_0

set_property -dict [list \
    CONFIG.INTERFACE_MODE {SLAVE}    \
    CONFIG.PROTOCOL       {AXI4}    \
    CONFIG.ADDR_WIDTH     {32}      \
    CONFIG.DATA_WIDTH     {32}      \
    CONFIG.ID_WIDTH       {4}       \
    CONFIG.AWUSER_WIDTH   {0}       \
    CONFIG.ARUSER_WIDTH   {0}       \
    CONFIG.RUSER_WIDTH    {0}       \
    CONFIG.WUSER_WIDTH    {0}       \
    CONFIG.BUSER_WIDTH    {0}       \
    CONFIG.HAS_BURST      {1}       \
    CONFIG.HAS_LOCK       {1}       \
    CONFIG.HAS_CACHE      {1}       \
    CONFIG.HAS_REGION     {0}       \
    CONFIG.HAS_QOS        {1}       \
    CONFIG.HAS_PROT       {1}       \
    CONFIG.HAS_WSTRB      {1}       \
    CONFIG.HAS_BRESP      {1}       \
    CONFIG.HAS_RRESP      {1}       \
] [get_ips axi_vip_0]

generate_target all [get_ips axi_vip_0]

puts "  -> AXI VIP IP generated successfully (AXI4 Full, Slave, Memory Model)"

# --------------------------------------------------------------------------
# 4. Create AXI Protocol Checker IP — AXI4 Full, 32-bit, 4-bit ID
#    Reference: PG101 — AXI Protocol Checker
# --------------------------------------------------------------------------
puts "Creating AXI Protocol Checker IP (AXI4 Full)..."

create_ip \
    -name        axi_protocol_checker \
    -vendor      xilinx.com \
    -library     ip \
    -version     2.0 \
    -module_name axi_pc_0

set_property -dict [list \
    CONFIG.PROTOCOL          {AXI4}        \
    CONFIG.ADDR_WIDTH        {32}          \
    CONFIG.DATA_WIDTH        {32}          \
    CONFIG.ID_WIDTH          {4}           \
    CONFIG.READ_WRITE_MODE   {READ_WRITE}  \
    CONFIG.HAS_SYSTEM_RESET  {0}           \
    CONFIG.MESSAGE_LEVEL     {2}           \
    CONFIG.MAX_AW_WAITS      {0}           \
    CONFIG.MAX_AR_WAITS      {0}           \
    CONFIG.MAX_W_WAITS       {0}           \
    CONFIG.MAX_R_WAITS       {0}           \
    CONFIG.MAX_B_WAITS       {0}           \
] [get_ips axi_pc_0]

generate_target all [get_ips axi_pc_0]

puts "  -> AXI Protocol Checker IP generated successfully (AXI4 Full)"

# --------------------------------------------------------------------------
# 5. Configure sim_1 — baseline (correct DUT)
# --------------------------------------------------------------------------
puts "Configuring sim_1 (baseline)..."
add_files -fileset sim_1 -norecurse [file normalize "$repo_dir/tb/tb_axi_master.sv"]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] "*/tb/tb_axi_master.sv"]
set_property top tb_axi_master [get_filesets sim_1]
update_compile_order -fileset sim_1

# --------------------------------------------------------------------------
# 6. Create sim_bugs — all 5 buggy DUT variants
# --------------------------------------------------------------------------
puts "Creating sim_bugs..."
create_fileset -simset sim_bugs
foreach n {1 2 3 4 5} {
    add_files -fileset sim_bugs -norecurse [file normalize "$repo_dir/tb/tb_axi_master_bug${n}.sv"]
}
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_bugs] "*/tb/*.sv"]
set_property top tb_axi_master_bug1 [get_filesets sim_bugs]
update_compile_order -fileset sim_bugs

# --------------------------------------------------------------------------
# 7. Simulation settings — optimized for speed
#
# Key optimizations (see UG900 and register_options.tcl):
#   - debug_level   = typical  (not "all" — avoids tracing into Xilinx primitives)
#   - mt_level      = auto     (multithreaded elaboration and compilation)
#   - log_all_signals = 0      (skip blanket signal logging)
#   - rangecheck    = 0        (skip runtime VHDL range checks)
#   - runtime       = 50us     (enough for all 12 ops; watchdog fires at ~40us)
# --------------------------------------------------------------------------
puts "Applying simulation optimization settings..."

foreach simset $all_simsets {
    # Compilation: multithreaded
    set_property -name {xsim.compile.xsc.mt_level}       -value {auto}    -objects [get_filesets $simset]

    # Elaboration: typical debug, multithreaded
    set_property -name {xsim.elaborate.debug_level}      -value {typical} -objects [get_filesets $simset]
    set_property -name {xsim.elaborate.mt_level}         -value {auto}    -objects [get_filesets $simset]
    set_property -name {xsim.elaborate.rangecheck}       -value {0}       -objects [get_filesets $simset]

    # Simulation: minimal logging, bounded runtime
    set_property -name {xsim.simulate.runtime}           -value {50us}    -objects [get_filesets $simset]
    set_property -name {xsim.simulate.log_all_signals}   -value {0}       -objects [get_filesets $simset]
}

# --------------------------------------------------------------------------
# 8. Summary
# --------------------------------------------------------------------------
puts ""
puts "============================================================"
puts "  Project created successfully!"
puts ""
puts "  Project file: $project_dir/${project_name}.xpr"
puts ""
puts "  Protocol: AXI4 Full (bursts, IDs, WLAST)"
puts ""
puts "  Simulation sets:"
puts "    sim_1    : tb_axi_master                                    (baseline)"
puts "    sim_bugs : tb_axi_master_bug{1,2,3,4,5}                    (5 bugs)"
puts ""
puts "  Optimization:"
puts "    debug_level    = typical  (skip Xilinx primitive tracing)"
puts "    mt_level       = auto     (multithreaded elaboration)"
puts "    log_all_signals = off     (skip blanket logging)"
puts "    rangecheck     = off      (no VHDL range checks)"
puts ""
puts "  Batch usage:"
puts "    vivado -mode batch -source scripts/create_project.tcl -tclargs run_sim"
puts "    vivado -mode batch -source scripts/create_project.tcl -tclargs run_bugs"
puts "    vivado -mode batch -source scripts/create_project.tcl -tclargs run_all"
puts "============================================================"

# --------------------------------------------------------------------------
# Helper: run all tops in a simset sequentially
# --------------------------------------------------------------------------
proc run_simset {simset top_list project_dir repo_dir} {
    foreach top $top_list {
        puts "\n------------------------------------------------------------"
        puts "  Simulating: $top  (fileset: $simset)"
        puts "------------------------------------------------------------"
        set_property top $top [get_filesets $simset]
        current_fileset -simset [get_filesets $simset]
        launch_simulation
        close_sim
        puts "  $top finished."
    }
}

# --------------------------------------------------------------------------
# 9. (Optional) Launch simulation(s) automatically
#
#    -tclargs run_sim   -> run sim_1 only (baseline)
#    -tclargs run_bugs  -> run sim_bugs   (bug1, bug2, bug3, bug4, bug5)
#    -tclargs run_all   -> run both sim sets
# --------------------------------------------------------------------------
if {[llength $::argv] > 0} {
    set run_mode [lindex $::argv 0]

    if {$run_mode eq "run_sim"} {
        puts "\nRunning sim_1 (baseline)..."
        run_simset sim_1 $simset_tops(sim_1) $project_dir $repo_dir
        puts "\n  sim_1 complete."

    } elseif {$run_mode eq "run_bugs"} {
        puts "\n============================================================"
        puts "  Running sim_bugs: $simset_tops(sim_bugs)"
        puts "============================================================"
        run_simset sim_bugs $simset_tops(sim_bugs) $project_dir $repo_dir
        puts "\n  sim_bugs complete."

    } elseif {$run_mode eq "run_all"} {
        foreach ss $all_simsets {
            run_simset $ss $simset_tops($ss) $project_dir $repo_dir
        }
        puts "\n============================================================"
        puts "  All simulations complete."
        puts "============================================================"
    }
}
