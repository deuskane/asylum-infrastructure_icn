-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_arbitration_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_arbitration_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario arbitration of tb_sbi_icn, from reset :
--              The two masters request in the same cycle, after a single
--              access of one of them : "fix" grants master 0 first,
--              "roundrobin" grants first the master that was not granted
--              last (first part of tc4, M1 alone first : the round robin
--              pointer follows the granted master)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-10-17  1.0      mrosiere Created (tc4)
-- 2026-11-20  2.0      mrosiere Scenario arbitration (TESTS_LIST), checks
--                               logged
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.sbi_pkg.all;

library work;
use     work.tb_sbi_icn_bfm_pkg.all;

package tb_sbi_icn_arbitration_pkg is

  -- The two masters request in the same cycle, after a single
  -- access of one of them : "fix" grants master 0 first,
  -- "roundrobin" grants first the master that was not granted
  -- last (first part of tc4)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_arbitration_pkg;

package body tb_sbi_icn_arbitration_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_lists : t_access_lists;
    variable v_order : t_grants;
    variable v_first : natural;
  begin
    -- M1 alone (round robin : M0 has the priority afterwards)
    v_lists(1)(0) := wr_acc(cfg, 0, 6, 16#66#);
    run_concurrent(v_lists, (0, 1), v_order, "M1 alone", clk, sbi_ifs);

    -- M0 and M1 request in the same cycle : M0 first in both modes
    v_lists(0)(0) := wr_acc(cfg, 1, 16, 16#11#);
    v_lists(1)(0) := wr_acc(cfg, 2, 16, 16#22#);
    run_concurrent(v_lists, (1, 1), v_order, "Simultaneous writes", clk, sbi_ifs);
    log(ID_SEQUENCER, "Simultaneous writes, completion order : " & order_image(v_order), C_TB_SCOPE);
    chk_int(v_order(0), 0, "Simultaneous writes : first granted master");
    chk_int(v_order(1), 1, "Simultaneous writes : second granted master");

    -- M0 alone (round robin : M1 has the priority afterwards)
    v_lists(0)(0) := wr_acc(cfg, 0, 5, 16#5A#);
    run_concurrent(v_lists, (1, 0), v_order, "M0 alone", clk, sbi_ifs);

    -- M0 and M1 read in the same cycle the data written by the other one :
    -- "fix" grants M0 first, "roundrobin" grants M1 first
    v_lists(0)(0) := rd_acc(cfg, 2, 16, 16#22#);
    v_lists(1)(0) := rd_acc(cfg, 1, 16, 16#11#);
    run_concurrent(v_lists, (1, 1), v_order, "Simultaneous reads", clk, sbi_ifs);
    log(ID_SEQUENCER, "Simultaneous reads, completion order : " & order_image(v_order), C_TB_SCOPE);
    if cfg.roundrobin then v_first := 1; else v_first := 0; end if;
    chk_int(v_order(0), v_first  , "Simultaneous reads : first granted master");
    chk_int(v_order(1), 1-v_first, "Simultaneous reads : second granted master");
  end procedure;

end package body tb_sbi_icn_arbitration_pkg;
