-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_contention_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_contention_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario contention of tb_sbi_icn, from reset :
--              Sustained contention, back-to-back accesses of both masters
--              (writes : M0 to target 1, M1 to target 2 ; then reads : each
--              master reads back the data written by the other one) :
--              "roundrobin" serves the masters alternately, "fix" keeps
--              master 0 on the bus while it requests (second part of tc4)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-10-17  1.0      mrosiere Created (tc4)
-- 2026-11-20  2.0      mrosiere Scenario contention (TESTS_LIST), checks
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

package tb_sbi_icn_contention_pkg is

  -- Sustained contention, back-to-back accesses of both masters
  -- (writes : M0 to target 1, M1 to target 2 ; then reads : each
  -- master reads back the data written by the other one) :
  -- "roundrobin" serves the masters alternately, "fix" keeps
  -- master 0 on the bus while it requests (second part of tc4)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_contention_pkg;

package body tb_sbi_icn_contention_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_lists : t_access_lists;
    variable v_order : t_grants;
  begin
    for phase in 0 to 1 loop
      for k in 0 to C_MAX_ACCESS-1 loop
        if phase = 0
        then
          v_lists(0)(k) := wr_acc(cfg, 1, 8+k, 16#A0#+k);
          v_lists(1)(k) := wr_acc(cfg, 2, 8+k, 16#B0#+k);
        else
          v_lists(0)(k) := rd_acc(cfg, 2, 8+k, 16#B0#+k);
          v_lists(1)(k) := rd_acc(cfg, 1, 8+k, 16#A0#+k);
        end if;
      end loop;
      run_concurrent(v_lists, (C_MAX_ACCESS, C_MAX_ACCESS), v_order, "Sustained contention " & integer'image(phase), clk, sbi_ifs);
      log(ID_SEQUENCER, "Sustained contention " & integer'image(phase) & ", completion order : " & order_image(v_order), C_TB_SCOPE);

      -- From reset (round robin : after a grant of M1), M0 first
      chk_int(v_order(0), 0, "First granted master");
      if cfg.roundrobin
      then
        -- Masters served alternately
        for j in 1 to 2*C_MAX_ACCESS-1 loop
          chk_true(v_order(j) /= v_order(j-1), "Round robin : access " & integer'image(j) & " not granted twice in a row to the same master");
        end loop;
      else
        -- Without input pipe, M0 requests again in the cycle following its completion and keeps the bus
        -- (with an input pipe, its request drops for a few cycles and M1 is granted in between)
        if not cfg.pipein
        then
          for j in 0 to C_MAX_ACCESS-1 loop
            chk_int(v_order(j), 0, "Fixed priority : M0 keeps the bus while it requests (access " & integer'image(j) & ")");
          end loop;
        end if;
      end if;
    end loop;
  end procedure;

end package body tb_sbi_icn_contention_pkg;
