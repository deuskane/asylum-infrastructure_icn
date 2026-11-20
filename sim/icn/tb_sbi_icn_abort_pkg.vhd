-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_abort_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_abort_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario abort of tb_sbi_icn, from reset :
--              The granted master releases cs before ready (protocol
--              violation, e.g. a CPU reset while blocked on a stalled
--              target) : the interconnect releases the bus, the other master
--              is not locked out (tc5). Needs a memory target with at least
--              1 wait state and no sbi_pipe on the master ports (it would
--              hold the request) : test_applies. M1 gets the bus one cycle
--              after the abort.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-17  1.0      mrosiere Created (tc5)
-- 2026-11-20  2.0      mrosiere Scenario abort (TESTS_LIST)
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

package tb_sbi_icn_abort_pkg is

  -- The granted master releases cs before ready (protocol
  -- violation, e.g. a CPU reset while blocked on a stalled
  -- target) : the interconnect releases the bus, the other master
  -- is not locked out (tc5). Needs a memory target with at least
  -- 1 wait state and no sbi_pipe on the master ports (it would
  -- hold the request) : test_applies. M1 gets the bus one cycle
  -- after the abort.
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_abort_pkg;

package body tb_sbi_icn_abort_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_tgt  : natural := 0;
    variable v_cnt  : natural;
  begin
    -- Slowest memory target
    for t in 0 to C_NB_MEM-1 loop
      if cfg.wait_states(t) > cfg.wait_states(v_tgt)
      then
        v_tgt := t;
      end if;
    end loop;

    -- Master 0 : read of the slow target, aborted one cycle after the grant
    wait until falling_edge(clk);
    drive(0, rd_acc(cfg, v_tgt, 0, 0), sbi_ifs);
    wait until rising_edge(clk);   -- grant (bus idle)
    wait until falling_edge(clk);
    chk_true(sbi_ifs(0).ready = '0', "M0 transfer to target " & integer'image(v_tgt) & " pending");
    idle(0, sbi_ifs);

    -- Master 1 : write to target 0, must complete
    drive(1, wr_acc(cfg, 0, 0, 16#C5#), sbi_ifs);
    v_cnt := C_TIMEOUT+1;
    for i in 1 to C_TIMEOUT loop
      wait until rising_edge(clk);
      if sbi_ifs(1).ready = '1'
      then
        v_cnt := i;
        exit;
      end if;
    end loop;
    -- One cycle to release the bus, then the latency of an idle bus
    chk_int(v_cnt, 1 + work.tb_sbi_icn_latency_pkg.latency(cfg, 0), "M1 not locked out after the abort of M0 : cycles from the request to ready");
    wait until falling_edge(clk);
    idle(1, sbi_ifs);

    -- The write of master 1 really reached target 0
    chk(0, taddr(cfg, 0, 0), x"C5", "read back the write of M1", clk, sbi_ifs);
  end procedure;

end package body tb_sbi_icn_abort_pkg;
