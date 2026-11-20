-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_latency_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_latency_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario latency of tb_sbi_icn, from reset :
--              Each master alone reads every target port and the default
--              slave : number of cycles from the request to ready =
--              2 (arbitration register, then the target answers) + wait
--              states of the target + 2 per sbi_pipe stage (master port,
--              target port ; the internal default slave has no target pipe)
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

package tb_sbi_icn_latency_pkg is

  -- Expected latency of target port t (t = cfg.nb_target : internal
  -- default slave)
  function latency
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ) return natural;

  -- Each master alone reads every target port and the default
  -- slave : number of cycles from the request to ready =
  -- 2 (arbitration register, then the target answers) + wait
  -- states of the target + 2 per sbi_pipe stage (master port,
  -- target port ; the internal default slave has no target pipe)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_latency_pkg;

package body tb_sbi_icn_latency_pkg is

  function latency
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ) return natural is
    variable res : natural := 2;
  begin
    if cfg.pipein
    then
      res := res + 2;
    end if;
    if t < cfg.nb_target
    then
      res := res + cfg.wait_states(t);
      if cfg.pipeout
      then
        res := res + 2;
      end if;
    end if;
    return res;
  end function;

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_cnt  : natural;
    variable v_addr : unsigned(SBI_ADDR_WIDTH-1 downto 0);
    variable v_nb   : natural;
  begin
    -- Target ports, then the internal default slave
    v_nb := cfg.nb_target;
    if not cfg.ds_is_memory
    then
      v_nb := v_nb + 1;
    end if;

    for m in 0 to C_NB_MASTER-1 loop
      for t in 0 to v_nb-1 loop
        if t < C_NB_MEM
        then
          v_addr := taddr(cfg, t, 1);
        else
          v_addr := unsigned(cfg.ds_addr(0));
        end if;
        access_cycles(m, (we => '0', addr => v_addr, data => x"00"), v_cnt, clk, sbi_ifs);
        chk_int(v_cnt, latency(cfg, t), "M" & integer'image(m) & " read @" & to_hstring(v_addr) & " : cycles from the request to ready");
      end loop;
    end loop;
  end procedure;

end package body tb_sbi_icn_latency_pkg;
