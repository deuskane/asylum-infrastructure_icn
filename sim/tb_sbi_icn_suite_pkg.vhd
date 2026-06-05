-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_suite_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Test suite for SBI Interconnect Testbench
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_suite_pkg is

  -- Main test suite procedure
  procedure run_test_suite (
    signal clk_i          : in  std_logic;
    signal arst_b_i       : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_TARGET_MEM_SIZE : in  naturals_t;
    constant C_CLK_PERIOD : in  time;
    constant C_SCOPE      : in  string
  );

end package tb_sbi_icn_suite_pkg;

library work;

package body tb_sbi_icn_suite_pkg is

  procedure run_test_suite (
    signal clk_i          : in  std_logic;
    signal arst_b_i       : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_NB_TARGET  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_TARGET_MEM_SIZE : in  naturals_t;
    constant C_CLK_PERIOD : in  time;
    constant C_SCOPE      : in  string
  ) is
  begin
    -- Initialisation des logs UVVM
    report_global_ctrl (VOID);
    report_msg_id_panel(VOID);

    enable_log_msg (ALL_MESSAGES);

    for m in 0 to C_NB_MASTER-1 loop
      sbi_ifs(m).cs    <= '0';
      sbi_ifs(m).addr  <= (others => '0');
      sbi_ifs(m).wena  <= '0';
      sbi_ifs(m).rena  <= '0';
      sbi_ifs(m).wdata <= (others => '0');
    end loop;

    wait until arst_b_i = '1'; -- Wait for reset to de-assert
    wait for C_CLK_PERIOD;
    log(ID_LOG_HDR, "Simulation Started", C_SCOPE);

    -- Execute Test Cases from separate packages
    work.tb_sbi_icn_tc1_pkg.run_test_case(
      clk_i         => clk_i,
      sbi_ifs       => sbi_ifs,
      C_NB_MASTER   => C_NB_MASTER,
      C_NB_TARGET   => C_NB_TARGET,
      C_TARGET_ID   => C_TARGET_ID,
      C_SCOPE       => C_SCOPE
    );

    work.tb_sbi_icn_tc2_pkg.run_test_case(
      clk_i         => clk_i,
      sbi_ifs       => sbi_ifs,
      C_NB_MASTER   => C_NB_MASTER,
      C_SCOPE       => C_SCOPE
    );

    work.tb_sbi_icn_tc3_pkg.run_test_case(
      clk_i         => clk_i,
      sbi_ifs       => sbi_ifs,
      C_NB_MASTER   => C_NB_MASTER,
      C_NB_TARGET   => C_NB_TARGET,
      C_TARGET_ID   => C_TARGET_ID,
      C_TARGET_MEM_SIZE => C_TARGET_MEM_SIZE,
      C_SCOPE       => C_SCOPE
    );

    log(ID_LOG_HDR, "Simulation Finished. All tests passed.", C_SCOPE);
    report_alert_counters(FINAL);
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    -- Finish the simulation
    std.env.stop;
  end procedure run_test_suite;

end package body tb_sbi_icn_suite_pkg;
