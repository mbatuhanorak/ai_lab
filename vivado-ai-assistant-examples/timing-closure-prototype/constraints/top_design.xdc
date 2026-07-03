# Copyright (C) 2026, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# top_design.xdc
# ============================================================================
# Constraints for multi-clock domain datapath design on xcvu5p.
# ============================================================================

# =============================================================================
# CLOCK DEFINITIONS
# =============================================================================

create_clock -period 10.000 -name sys_clk   [get_ports sys_clk]
create_clock -period 10.000 -name clk_b_ref [get_ports clk_b_ref]

# =============================================================================
# CLOCK RELATIONSHIPS
# =============================================================================

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins mmcm1_inst/inst/mmcme4_adv_inst/CLKOUT1]] \
    -group [get_clocks -include_generated_clocks clk_b_ref]

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins mmcm1_inst/inst/mmcme4_adv_inst/CLKOUT2]] \
    -group [get_clocks -include_generated_clocks clk_b_ref]

# =============================================================================
# BLOCK A PLACEMENT
# =============================================================================

create_pblock pblock_cdc_src
resize_pblock pblock_cdc_src -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y0}
set_property IS_SOFT FALSE [get_pblocks pblock_cdc_src]
add_cells_to_pblock [get_pblocks pblock_cdc_src] [get_cells cdc_src]

create_pblock pblock_cdc_dst
resize_pblock pblock_cdc_dst -add {CLOCKREGION_X5Y4:CLOCKREGION_X5Y4}
set_property IS_SOFT FALSE [get_pblocks pblock_cdc_dst]
add_cells_to_pblock [get_pblocks pblock_cdc_dst] [get_cells cdc_dst]

# =============================================================================
# BLOCK B PLACEMENT
# =============================================================================

create_pblock pblock_slr0_src
resize_pblock pblock_slr0_src -add {CLOCKREGION_X0Y3:CLOCKREGION_X1Y4}
set_property IS_SOFT FALSE [get_pblocks pblock_slr0_src]
add_cells_to_pblock [get_pblocks pblock_slr0_src] [get_cells -hierarchical -filter {NAME =~ "slr0_*"}]

create_pblock pblock_slr1_dst
resize_pblock pblock_slr1_dst -add {CLOCKREGION_X4Y5:CLOCKREGION_X5Y6}
set_property IS_SOFT FALSE [get_pblocks pblock_slr1_dst]
add_cells_to_pblock [get_pblocks pblock_slr1_dst] [get_cells -hierarchical -filter {NAME =~ "slr1_*"}]

# =============================================================================
# BLOCK C PLACEMENT
# =============================================================================

create_pblock pblock_fanout_bl
resize_pblock pblock_fanout_bl -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y0}
set_property IS_SOFT FALSE [get_pblocks pblock_fanout_bl]
add_cells_to_pblock [get_pblocks pblock_fanout_bl] [get_cells -hierarchical -filter {NAME =~ "fanout_corner[0].*"}]

create_pblock pblock_fanout_br
resize_pblock pblock_fanout_br -add {CLOCKREGION_X5Y0:CLOCKREGION_X5Y0}
set_property IS_SOFT FALSE [get_pblocks pblock_fanout_br]
add_cells_to_pblock [get_pblocks pblock_fanout_br] [get_cells -hierarchical -filter {NAME =~ "fanout_corner[1].*"}]

create_pblock pblock_fanout_tl
resize_pblock pblock_fanout_tl -add {CLOCKREGION_X0Y4:CLOCKREGION_X0Y4}
set_property IS_SOFT FALSE [get_pblocks pblock_fanout_tl]
add_cells_to_pblock [get_pblocks pblock_fanout_tl] [get_cells -hierarchical -filter {NAME =~ "fanout_corner[2].*"}]

create_pblock pblock_fanout_tr
resize_pblock pblock_fanout_tr -add {CLOCKREGION_X5Y4:CLOCKREGION_X5Y4}
set_property IS_SOFT FALSE [get_pblocks pblock_fanout_tr]
add_cells_to_pblock [get_pblocks pblock_fanout_tr] [get_cells -hierarchical -filter {NAME =~ "fanout_corner[3].*"}]

# =============================================================================
# BLOCK D PLACEMENT
# =============================================================================

create_pblock pblock_combo_slr1
resize_pblock pblock_combo_slr1 -add {CLOCKREGION_X2Y5:CLOCKREGION_X3Y6}
set_property IS_SOFT FALSE [get_pblocks pblock_combo_slr1]
add_cells_to_pblock [get_pblocks pblock_combo_slr1] [get_cells -hierarchical -filter {NAME =~ "combo_*"}]
add_cells_to_pblock [get_pblocks pblock_combo_slr1] [get_cells -hierarchical -filter {NAME =~ "chain_*"}]

# =============================================================================
# RESET
# =============================================================================

set_false_path -from [get_ports rst_n]
