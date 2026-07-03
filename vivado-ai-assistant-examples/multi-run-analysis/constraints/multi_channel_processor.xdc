# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

## multi_channel_processor.xdc
## Clock constraint targeting 275 MHz — aggressive enough to differentiate strategies

# 275 MHz clock — creates borderline timing closure across different strategies
create_clock -period 3.636 -name sys_clk [get_ports clk]

# I/O constraints — tight to push timing pressure inward
set_input_delay -clock sys_clk -max 0.8 [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_input_delay -clock sys_clk -min 0.1 [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay -clock sys_clk -max 0.8 [get_ports -filter {DIRECTION == OUT}]
set_output_delay -clock sys_clk -min 0.1 [get_ports -filter {DIRECTION == OUT}]
