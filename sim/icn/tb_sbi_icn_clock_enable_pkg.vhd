-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_clock_enable_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_clock_enable_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario clock_enable of tb_sbi_icn, from reset :
--              cke_i = 0 : a request is not served (no ready for 8 cycles) ;
--              cke_i = 1 again : the access completes with the latency of
--              an idle bus, the written data reached the target ; cke_i = 0
--              during 4 cycles after a grant : the access is delayed by 4
--              cycles (when it still needs a clock edge)
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

package tb_sbi_icn_clock_enable_pkg is

  -- cke_i = 0 : a request is not served (no ready for 8 cycles) ;
  -- cke_i = 1 again : the access completes with the latency of
  -- an idle bus, the written data reached the target ; cke_i = 0
  -- during 4 cycles after a grant : the access is delayed by 4
  -- cycles (when it still needs a clock edge)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   cke      : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_clock_enable_pkg;

package body tb_sbi_icn_clock_enable_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   cke      : out   std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_ready : boolean := false;
    variable v_cnt   : natural;
    variable v_exp   : natural;
    variable v_data  : byte_t := x"00";
    constant C_FREEZE : natural := 4;  -- Cycles with cke_i = 0 after the grant
  begin
    wait until falling_edge(clk);
    cke <= '0';
    drive(0, wr_acc(cfg, 1, 3, 16#3C#), sbi_ifs);
    for i in 1 to 8 loop
      wait until rising_edge(clk);
      v_ready := v_ready or sbi_ifs(0).ready = '1';
    end loop;
    chk_true(not v_ready, "M0 : no ready while cke_i = 0 (8 cycles)");

    wait until falling_edge(clk);
    cke <= '1';
    v_cnt := C_TIMEOUT+1;
    for i in 1 to C_TIMEOUT loop
      wait until rising_edge(clk);
      if sbi_ifs(0).ready = '1'
      then
        v_cnt := i;
        exit;
      end if;
    end loop;
    chk_int(v_cnt, work.tb_sbi_icn_latency_pkg.latency(cfg, 1), "M0 : cycles from cke_i = 1 to ready");
    wait until falling_edge(clk);
    idle(0, sbi_ifs);

    chk(1, taddr(cfg, 1, 3), x"3C", "read back the write done after cke_i = 1", clk, sbi_ifs);

    -- cke_i = 0 during C_FREEZE cycles after the grant of a read of target 2 :
    -- the access is delayed by C_FREEZE cycles, unless it needs no more
    -- clock edge (latency 2 : ready is combinational after the grant)
    v_exp := work.tb_sbi_icn_latency_pkg.latency(cfg, 2);
    if v_exp > 2
    then
      v_exp := v_exp + C_FREEZE;
    end if;
    wr(0, taddr(cfg, 2, 7), x"7E", "write T2 offset 7", clk, sbi_ifs);
    wait until falling_edge(clk);
    drive(1, rd_acc(cfg, 2, 7, 16#7E#), sbi_ifs);
    v_cnt := C_TIMEOUT+1;
    for i in 1 to C_TIMEOUT loop
      wait until rising_edge(clk);
      if sbi_ifs(1).ready = '1'
      then
        v_cnt  := i;
        v_data := sbi_ifs(1).rdata;
        exit;
      end if;
      wait until falling_edge(clk);
      if    i = 1
      then
        cke <= '0';
      elsif i = 1 + C_FREEZE
      then
        cke <= '1';
      end if;
    end loop;
    chk_int(v_cnt, v_exp, "M1 : cycles from the request to ready, cke_i = 0 during " & integer'image(C_FREEZE) & " cycles after the grant");
    chk_true(v_data = x"7E", "M1 : read data of the access delayed by cke_i = 0");
    wait until falling_edge(clk);
    idle(1, sbi_ifs);
    cke <= '1';
  end procedure;

end package body tb_sbi_icn_clock_enable_pkg;
