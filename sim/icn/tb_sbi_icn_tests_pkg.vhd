-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenarios of tb_sbi_icn : names (valid items of TESTS_LIST),
--              configurations where they apply and dispatch (run_test) to
--              the package of each scenario (tb_sbi_icn_<name>_pkg)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created (tb_sbi_icn_suite_pkg)
-- 2026-11-20  2.0      mrosiere Names, test_applies and run_test (TESTS_LIST)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library work;
use     work.tb_sbi_icn_bfm_pkg.all;

package tb_sbi_icn_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "simple,default_slave,exhaustive,arbitration,contention,abort,latency,clock_enable,reset";

  -- false : the scenario name does not apply to the configuration cfg
  function test_applies
    (constant name     : in    string
    ;constant cfg      : in    t_tb_cfg
    ) return boolean;

  -- Run the scenario name
  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   cke      : out   std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_tests_pkg;

package body tb_sbi_icn_tests_pkg is

  function test_applies
    (constant name     : in    string
    ;constant cfg      : in    t_tb_cfg
    ) return boolean is
    variable res : boolean := false;
  begin
    if string_eq(name, "abort")
    then
      -- A memory target with wait states to abort before its ready, and
      -- no sbi_pipe on the master ports (it would hold the request)
      for t in 0 to C_NB_MEM-1 loop
        res := res or cfg.wait_states(t) >= 1;
      end loop;
      return res and not cfg.pipein;
    end if;
    return true;
  end function;

  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   cke      : out   std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    if    string_eq(name, "simple")
    then
      work.tb_sbi_icn_simple_pkg.run       (cfg, clk, sbi_ifs);
    elsif string_eq(name, "default_slave")
    then
      work.tb_sbi_icn_default_slave_pkg.run(cfg, clk, sbi_ifs);
    elsif string_eq(name, "exhaustive")
    then
      work.tb_sbi_icn_exhaustive_pkg.run   (cfg, clk, sbi_ifs);
    elsif string_eq(name, "arbitration")
    then
      work.tb_sbi_icn_arbitration_pkg.run  (cfg, clk, sbi_ifs);
    elsif string_eq(name, "contention")
    then
      work.tb_sbi_icn_contention_pkg.run   (cfg, clk, sbi_ifs);
    elsif string_eq(name, "abort")
    then
      work.tb_sbi_icn_abort_pkg.run        (cfg, clk, sbi_ifs);
    elsif string_eq(name, "latency")
    then
      work.tb_sbi_icn_latency_pkg.run      (cfg, clk, sbi_ifs);
    elsif string_eq(name, "clock_enable")
    then
      work.tb_sbi_icn_clock_enable_pkg.run (cfg, clk, cke, sbi_ifs);
    elsif string_eq(name, "reset")
    then
      work.tb_sbi_icn_reset_pkg.run        (cfg, clk, arst_b, sbi_ifs);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure;

end package body tb_sbi_icn_tests_pkg;
