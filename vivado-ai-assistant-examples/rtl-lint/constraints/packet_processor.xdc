# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

## packet_processor.xdc
## Constraints for the packet processor example design

# Clock definition - 100 MHz
create_clock -period 10.000 -name sys_clk [get_ports clk]

# I/O delay constraints
set_input_delay -clock sys_clk -max 3.0 [get_ports rx_data[*]]
set_input_delay -clock sys_clk -min 1.0 [get_ports rx_data[*]]
set_input_delay -clock sys_clk -max 3.0 [get_ports rx_valid]
set_input_delay -clock sys_clk -min 1.0 [get_ports rx_valid]
set_input_delay -clock sys_clk -max 3.0 [get_ports mode_sel[*]]
set_input_delay -clock sys_clk -min 1.0 [get_ports mode_sel[*]]
set_input_delay -clock sys_clk -max 3.0 [get_ports base_addr[*]]
set_input_delay -clock sys_clk -min 1.0 [get_ports base_addr[*]]

set_output_delay -clock sys_clk -max 3.0 [get_ports tx_data[*]]
set_output_delay -clock sys_clk -min 1.0 [get_ports tx_data[*]]
set_output_delay -clock sys_clk -max 3.0 [get_ports tx_valid]
set_output_delay -clock sys_clk -min 1.0 [get_ports tx_valid]
set_output_delay -clock sys_clk -max 3.0 [get_ports rx_ready]
set_output_delay -clock sys_clk -min 1.0 [get_ports rx_ready]
set_output_delay -clock sys_clk -max 3.0 [get_ports tx_addr[*]]
set_output_delay -clock sys_clk -min 1.0 [get_ports tx_addr[*]]
