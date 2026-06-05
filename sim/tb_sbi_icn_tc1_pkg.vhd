library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_tc1_pkg is

  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_SCOPE      : in  string
  );

end package tb_sbi_icn_tc1_pkg;

package body tb_sbi_icn_tc1_pkg is

  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_SCOPE      : in  string
  ) is
  begin
    log(ID_LOG_HDR, "Test Case 1: Simple access to each target", C_SCOPE);

    -- Target 0 (base address 0x00)
    sbi_write(addr_value => x"00", data_value => x"A5", msg => "M0 Write T0",          clk => clk_i, sbi_if => sbi_ifs(0));
    sbi_check(addr_value => x"00", data_exp   => x"A5", msg => "M0 Check T0",          clk => clk_i, sbi_if => sbi_ifs(0));
    if C_NB_MASTER > 1 then
      sbi_write(addr_value => x"01", data_value => x"5A", msg => "M1 Write T0 offset 1", clk => clk_i, sbi_if => sbi_ifs(1));
      sbi_check(addr_value => x"01", data_exp   => x"5A", msg => "M1 Check T0 offset 1", clk => clk_i, sbi_if => sbi_ifs(1));
    end if;

    -- Target 1 (base address 0x40)
    if C_NB_TARGET > 1 then
      sbi_write(addr_value => x"40", data_value => x"12", msg => "M0 Write T1",          clk => clk_i, sbi_if => sbi_ifs(0));
      if C_NB_MASTER > 1 then
        sbi_check(addr_value => x"40", data_exp   => x"12", msg => "M1 Check T1",          clk => clk_i, sbi_if => sbi_ifs(1));
      else
        sbi_check(addr_value => x"40", data_exp   => x"12", msg => "M0 Check T1",          clk => clk_i, sbi_if => sbi_ifs(0));
      end if;
      sbi_write(addr_value => x"42", data_value => x"34", msg => "M0 Write T1 offset 2", clk => clk_i, sbi_if => sbi_ifs(0));
      if C_NB_MASTER > 1 then
        sbi_check(addr_value => x"42", data_exp   => x"34", msg => "M1 Check T1 offset 2", clk => clk_i, sbi_if => sbi_ifs(1));
      else
        sbi_check(addr_value => x"42", data_exp   => x"34", msg => "M0 Check T1 offset 2", clk => clk_i, sbi_if => sbi_ifs(0));
      end if;
    end if;

    -- Target 2 (base address 0x80)
    if C_NB_TARGET > 2 then
      if C_NB_MASTER > 1 then
        sbi_write(addr_value => x"80", data_value => x"FF", msg => "M1 Write T2",          clk => clk_i, sbi_if => sbi_ifs(1));
        sbi_check(addr_value => x"80", data_exp   => x"FF", msg => "M0 Check T2",          clk => clk_i, sbi_if => sbi_ifs(0));
        sbi_write(addr_value => x"83", data_value => x"00", msg => "M1 Write T2 offset 3", clk => clk_i, sbi_if => sbi_ifs(1));
        sbi_check(addr_value => x"83", data_exp   => x"00", msg => "M0 Check T2 offset 3", clk => clk_i, sbi_if => sbi_ifs(0));
      else
        sbi_write(addr_value => x"80", data_value => x"FF", msg => "M0 Write T2",          clk => clk_i, sbi_if => sbi_ifs(0));
        sbi_check(addr_value => x"80", data_exp   => x"FF", msg => "M0 Check T2",          clk => clk_i, sbi_if => sbi_ifs(0));
        sbi_write(addr_value => x"83", data_value => x"00", msg => "M0 Write T2 offset 3", clk => clk_i, sbi_if => sbi_ifs(0));
        sbi_check(addr_value => x"83", data_exp   => x"00", msg => "M0 Check T2 offset 3", clk => clk_i, sbi_if => sbi_ifs(0));
      end if;
    end if;
  end procedure run_test_case;

end package body tb_sbi_icn_tc1_pkg;
