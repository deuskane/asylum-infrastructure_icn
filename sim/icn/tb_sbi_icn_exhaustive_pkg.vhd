-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_exhaustive_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_exhaustive_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Scenario exhaustive of tb_sbi_icn, from reset :
--              Every address of every memory target written by master 0
--              and read back by master 1, then accesses switching from one
--              target to the other (tc3)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created (tc3)
-- 2026-11-20  2.0      mrosiere Scenario exhaustive (TESTS_LIST), target 2
--                               too, read back by master 1
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

package tb_sbi_icn_exhaustive_pkg is

  -- Every address of every memory target written by master 0
  -- and read back by master 1, then accesses switching from one
  -- target to the other (tc3)
  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

end package tb_sbi_icn_exhaustive_pkg;

package body tb_sbi_icn_exhaustive_pkg is

  procedure run
    (constant cfg      : in    t_tb_cfg
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_data : byte_t;
  begin
    for t in 0 to C_NB_MEM-1 loop
      for i in 0 to 2**cfg.width(t)-1 loop
        v_data := std_logic_vector(to_unsigned(i + 1 + 64*t, 8));
        wr (0, taddr(cfg, t, i), v_data, "exhaustive write T" & integer'image(t), clk, sbi_ifs);
      end loop;
      for i in 0 to 2**cfg.width(t)-1 loop
        v_data := std_logic_vector(to_unsigned(i + 1 + 64*t, 8));
        chk(1, taddr(cfg, t, i), v_data, "exhaustive read T"  & integer'image(t), clk, sbi_ifs);
      end loop;
    end loop;

    -- Accesses switching from one target to the other
    wr (0, taddr(cfg, 0, 0), x"AA", "switch write T0", clk, sbi_ifs);
    wr (0, taddr(cfg, 1, 0), x"BB", "switch write T1", clk, sbi_ifs);
    chk(0, taddr(cfg, 0, 0), x"AA", "switch read T0" , clk, sbi_ifs);
    chk(0, taddr(cfg, 1, 0), x"BB", "switch read T1" , clk, sbi_ifs);
  end procedure;

end package body tb_sbi_icn_exhaustive_pkg;
