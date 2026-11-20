-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_reset_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_reset_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset of tb_sbi_icn, from reset :
--              A request held through a reset is served after the release
--              with the latency of an idle bus ; a reset during an access
--              cancels it : the next access to the same target gets its own
--              response with the latency of an idle bus
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created
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

package tb_sbi_icn_reset_pkg is

  -- A request held through a reset is served after the release with the
  -- latency of an idle bus ; a reset during an access cancels it : the next
  -- access to the same target gets its own response with the latency of an
  -- idle bus
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_reset_pkg;

package body tb_sbi_icn_reset_pkg is

  -- Number of rising edges until ready of master m (C_TIMEOUT+1 without
  -- ready), read data at ready
  procedure wait_ready
    (constant m        : in    natural
    ;variable cnt      : out   natural
    ;variable data     : out   byte_t
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    cnt  := C_TIMEOUT+1;
    data := (others => 'X');
    for i in 1 to C_TIMEOUT loop
      wait until rising_edge(clk);
      if sbi_ifs(m).ready = '1'
      then
        cnt  := i;
        data := sbi_ifs(m).rdata;
        exit;
      end if;
    end loop;
  end procedure;

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_tgt  : natural := 0;
    variable v_cnt  : natural;
    variable v_data : byte_t;
  begin
    -- Request of M1 present during the reset, served after the release
    wait until falling_edge(clk);
    arst_b <= '0';
    drive(1, wr_acc(cfg, 0, 9, 16#99#), sbi_ifs);
    cycles(3, clk);
    wait until falling_edge(clk);
    arst_b <= '1';
    wait_ready(1, v_cnt, v_data, clk, sbi_ifs);
    chk_int(v_cnt, work.tb_sbi_icn_latency_pkg.latency(cfg, 0), "M1 request held through the reset : cycles from the release to ready");
    wait until falling_edge(clk);
    idle(1, sbi_ifs);
    chk(0, taddr(cfg, 0, 9), x"99", "read back the write served after the reset", clk, sbi_ifs);

    -- Slowest memory target
    for t in 0 to C_NB_MEM-1 loop
      if work.tb_sbi_icn_latency_pkg.latency(cfg, t) > work.tb_sbi_icn_latency_pkg.latency(cfg, v_tgt)
      then
        v_tgt := t;
      end if;
    end loop;

    -- Read of M0 cancelled by a reset one cycle after its request
    wr(0, taddr(cfg, v_tgt, 2), x"5B", "write T" & integer'image(v_tgt) & " offset 2", clk, sbi_ifs);
    wait until falling_edge(clk);
    drive(0, rd_acc(cfg, v_tgt, 3, 0), sbi_ifs);
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    arst_b <= '0';
    idle(0, sbi_ifs);
    cycles(3, clk);
    wait until falling_edge(clk);
    arst_b <= '1';

    -- Read of M1, same target, after the reset
    wait until falling_edge(clk);
    drive(1, rd_acc(cfg, v_tgt, 2, 16#5B#), sbi_ifs);
    wait_ready(1, v_cnt, v_data, clk, sbi_ifs);
    chk_int(v_cnt, work.tb_sbi_icn_latency_pkg.latency(cfg, v_tgt), "M1 read of target " & integer'image(v_tgt) & " after a reset during an access : cycles from the request to ready");
    chk_true(v_data = x"5B", "M1 read data after a reset during an access");
    wait until falling_edge(clk);
    idle(1, sbi_ifs);
  end procedure;

end package body tb_sbi_icn_reset_pkg;
