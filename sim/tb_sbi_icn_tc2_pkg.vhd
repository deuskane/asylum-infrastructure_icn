-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Test Case 2 for SBI Interconnect Testbench: Default slave access
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.1      mrosiere Updated comments
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

library work;
use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_tc2_pkg is
  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_SCOPE      : in  string
  );
end package tb_sbi_icn_tc2_pkg;

package body tb_sbi_icn_tc2_pkg is
  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_SCOPE      : in  string
  ) is
  begin
    log(ID_LOG_HDR, "Test Case 2: Access to default slave", C_SCOPE);

    sbi_write(addr_value => x"C0", data_value => x"EE", msg => "M0 Write to default slave", clk => clk_i, sbi_if => sbi_ifs(0));
    if C_NB_MASTER > 1 then
      sbi_check(addr_value => x"C0", data_exp   => x"00", msg => "M1 Check default slave",    clk => clk_i, sbi_if => sbi_ifs(1));
    else
      sbi_check(addr_value => x"C0", data_exp   => x"00", msg => "M0 Check default slave",    clk => clk_i, sbi_if => sbi_ifs(0));
    end if;
    sbi_check(addr_value => x"FF", data_exp   => x"00", msg => "M0 Check unmapped top addr",clk => clk_i, sbi_if => sbi_ifs(0));
  end procedure run_test_case;
end package body tb_sbi_icn_tc2_pkg;