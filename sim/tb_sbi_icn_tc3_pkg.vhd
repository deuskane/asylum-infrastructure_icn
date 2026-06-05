-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Test Case 3 for SBI Interconnect Testbench: Exhaustive access
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.1      mrosiere Updated comments and exhaustive loops
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;
use     asylum.convert_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

library work;
use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_tc3_pkg is
  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_TARGET_MEM_SIZE : in  naturals_t;
    constant C_SCOPE      : in  string
  );
end package tb_sbi_icn_tc3_pkg;

package body tb_sbi_icn_tc3_pkg is
  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_TARGET_MEM_SIZE : in  naturals_t;
    constant C_SCOPE      : in  string
  ) is
  begin
    log(ID_LOG_HDR, "Test Case 3: Exhaustive access (more comprehensive)", C_SCOPE);

    -- Exhaustive write and check for Target 0
    for i in 0 to C_TARGET_MEM_SIZE(0) - 1 loop
      sbi_write(addr_value => unsigned(C_TARGET_ID(0)) + i, data_value => to_slv(i + 1, SBI_DATA_WIDTH), msg => "M0 Exhaustive write T0", clk => clk_i, sbi_if => sbi_ifs(0));
    end loop;
    if C_NB_MASTER > 1 then
      for i in 0 to C_TARGET_MEM_SIZE(0) - 1 loop
        sbi_check(addr_value => unsigned(C_TARGET_ID(0)) + i, data_exp => to_slv(i + 1, SBI_DATA_WIDTH), msg => "M1 Exhaustive check T0", clk => clk_i, sbi_if => sbi_ifs(1));
      end loop;
    else
      for i in 0 to C_TARGET_MEM_SIZE(0) - 1 loop
        sbi_check(addr_value => unsigned(C_TARGET_ID(0)) + i, data_exp => to_slv(i + 1, SBI_DATA_WIDTH), msg => "M0 Exhaustive check T0", clk => clk_i, sbi_if => sbi_ifs(0));
      end loop;
    end if;

    -- Exhaustive write and check for Target 1
    if C_NB_TARGET > 1 then
      for i in 0 to C_TARGET_MEM_SIZE(1) - 1 loop
        sbi_write(addr_value => unsigned(C_TARGET_ID(1)) + i, data_value => to_slv(i + 10, SBI_DATA_WIDTH), msg => "Write T1", clk => clk_i, sbi_if => sbi_ifs(0));
      end loop;
      for i in 0 to C_TARGET_MEM_SIZE(1) - 1 loop
        sbi_check(addr_value => unsigned(C_TARGET_ID(1)) + i, data_exp => to_slv(i + 10, SBI_DATA_WIDTH), msg => "Check T1", clk => clk_i, sbi_if => sbi_ifs(0));
      end loop;
    end if;

    -- Sequential access to different targets to verify switching
    log(ID_SEQUENCER, "Testing sequential bursts to different targets", C_SCOPE);
    sbi_write(addr_value => unsigned(C_TARGET_ID(0)) + unsigned'(x"00"), data_value => x"AA", msg => "Burst write T0", clk => clk_i, sbi_if => sbi_ifs(0));
    if C_NB_TARGET > 1 then
      sbi_write(addr_value => unsigned(C_TARGET_ID(1)) + unsigned'(x"00"), data_value => x"BB", msg => "Burst write T1", clk => clk_i, sbi_if => sbi_ifs(0));
    end if;
    sbi_check(addr_value => unsigned(C_TARGET_ID(0)) + unsigned'(x"00"), data_exp => x"AA", msg => "Burst check T0", clk => clk_i, sbi_if => sbi_ifs(0));
    if C_NB_TARGET > 1 then
      sbi_check(addr_value => unsigned(C_TARGET_ID(1)) + unsigned'(x"00"), data_exp => x"BB", msg => "Burst check T1", clk => clk_i, sbi_if => sbi_ifs(0));
    end if;
  end procedure run_test_case;
end package body tb_sbi_icn_tc3_pkg;