-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_simple_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_simple_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario simple of tb_sbi_icn, from reset :
--              Each memory target written by a master and read back by the
--              other one (tc1), then the same offset of every memory target
--              written with a different value and read back (address
--              decoding : an access selects one target only)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created (tc1)
-- 2026-11-20  2.0      mrosiere Scenario simple (TESTS_LIST), decoding check
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

package tb_sbi_icn_simple_pkg is

  -- Each memory target written by a master and read back by the
  -- other one (tc1), then the same offset of every memory target
  -- written with a different value and read back (address
  -- decoding : an access selects one target only)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_simple_pkg;

package body tb_sbi_icn_simple_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    wr (0, taddr(cfg, 0, 0), x"A5", "write T0 offset 0", clk, sbi_ifs);
    chk(0, taddr(cfg, 0, 0), x"A5", "read T0 offset 0" , clk, sbi_ifs);
    wr (1, taddr(cfg, 0, 1), x"5A", "write T0 offset 1", clk, sbi_ifs);
    chk(1, taddr(cfg, 0, 1), x"5A", "read T0 offset 1" , clk, sbi_ifs);
    wr (0, taddr(cfg, 1, 0), x"12", "write T1 offset 0", clk, sbi_ifs);
    chk(1, taddr(cfg, 1, 0), x"12", "read T1 offset 0" , clk, sbi_ifs);
    wr (0, taddr(cfg, 1, 2), x"34", "write T1 offset 2", clk, sbi_ifs);
    chk(1, taddr(cfg, 1, 2), x"34", "read T1 offset 2" , clk, sbi_ifs);
    wr (1, taddr(cfg, 2, 0), x"FF", "write T2 offset 0", clk, sbi_ifs);
    chk(0, taddr(cfg, 2, 0), x"FF", "read T2 offset 0" , clk, sbi_ifs);
    wr (1, taddr(cfg, 2, 3), x"3C", "write T2 offset 3", clk, sbi_ifs);
    chk(0, taddr(cfg, 2, 3), x"3C", "read T2 offset 3" , clk, sbi_ifs);

    -- Same offset, one value per target : a write selects one target only
    for t in 0 to C_NB_MEM-1 loop
      wr (t mod 2    , taddr(cfg, t, 4), std_logic_vector(to_unsigned(16#40#+t, 8)), "write T" & integer'image(t) & " offset 4", clk, sbi_ifs);
    end loop;
    for t in 0 to C_NB_MEM-1 loop
      chk((t+1) mod 2, taddr(cfg, t, 4), std_logic_vector(to_unsigned(16#40#+t, 8)), "read T"  & integer'image(t) & " offset 4, decoding", clk, sbi_ifs);
    end loop;
  end procedure;

end package body tb_sbi_icn_simple_pkg;
