# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# constraints.xdc — Timing and I/O constraints for opt_design_demo
# Target: xcu200-fsgd2104-2-e (Alveo U200)

# Primary clock — 200 MHz
create_clock -period 5.000 -name sys_clk [get_ports clk]

# I/O delays (nominal)
set_input_delay  -clock sys_clk 1.0 [get_ports {data_in[*] sel[*] en_global wr_en addr[*] rst_n rst_p}]
set_output_delay -clock sys_clk 1.0 [get_ports {data_out[*] bram_rdata[*] accum_out[*] carry_out dead_port[*]}]

# Async reset — false path from reset to all sequential elements
set_false_path -from [get_ports rst_n]
