-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_default_slave_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_default_slave_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario default_slave of tb_sbi_icn, from reset :
--              Accesses to two unmapped addresses : the internal default
--              slave answers at once, reads 0 and ignores the writes ; the
--              external default slave (memory model on the last target port,
--              ID 0, whole address range) stores the written data (tc2)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created (tc2)
-- 2026-11-20  2.0      mrosiere Scenario default_slave (TESTS_LIST)
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

package tb_sbi_icn_default_slave_pkg is

  -- Accesses to two unmapped addresses : the internal default
  -- slave answers at once, reads 0 and ignores the writes ; the
  -- external default slave (memory model on the last target port,
  -- ID 0, whole address range) stores the written data (tc2)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_default_slave_pkg;

package body tb_sbi_icn_default_slave_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_exp  : byte_t := x"00";  -- Internal default slave : read data 0
    variable v_exp1 : byte_t := x"00";
  begin
    if cfg.ds_is_memory
    then
      v_exp  := x"EE";
      v_exp1 := x"11";
    end if;

    wr (0, unsigned(cfg.ds_addr(0)), x"EE" , "write unmapped address"   , clk, sbi_ifs);
    chk(1, unsigned(cfg.ds_addr(0)), v_exp , "read unmapped address"    , clk, sbi_ifs);
    wr (1, unsigned(cfg.ds_addr(1)), x"11" , "write unmapped top address", clk, sbi_ifs);
    chk(0, unsigned(cfg.ds_addr(1)), v_exp1, "read unmapped top address" , clk, sbi_ifs);
  end procedure;

end package body tb_sbi_icn_default_slave_pkg;
