-------------------------------------------------------------------------------
-- Title      : SBI Interconnect Mux
-- Project    : 
-------------------------------------------------------------------------------
-- Description: Multiplexing of SBI target responses
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026/05/22  1.0      mrosiere Created
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;

entity sbi_icn_mux_tgt is
  generic (
    NAME         : string   := "sbi_icn";
    NB_TARGET    : positive := 1;
    TARGET_SEL   : string   := "or"
  );
  port (
    sbi_tgts_i   : in  sbi_tgts_t(NB_TARGET-1 downto 0);
    sbi_tgt_ds_i : in  sbi_tgt_t;
    tgt_cs_i     : in  std_logic_vector(NB_TARGET-1 downto 0);
    sbi_tgt_o    : out sbi_tgt_t
  );
end entity sbi_icn_mux_tgt;

architecture rtl of sbi_icn_mux_tgt is
begin

  gen_algo_sel_or: if TARGET_SEL = "or" generate
    process (sbi_tgts_i, sbi_tgt_ds_i) is
      variable v_sbi_tgt : sbi_tgt_t(rdata(sbi_tgt_o.rdata'range));
    begin
      -- Initialisation avec la réponse de l'esclave par défaut
      v_sbi_tgt := sbi_tgt_ds_i;
      for tgt in 0 to NB_TARGET-1 loop
        v_sbi_tgt := v_sbi_tgt or sbi_tgts_i(tgt);
      end loop;
      v_sbi_tgt.info.name := to_sbi_name(NAME);
      sbi_tgt_o <= v_sbi_tgt;
    end process;
  end generate gen_algo_sel_or;

  gen_algo_sel_mux: if TARGET_SEL = "mux" generate
    process (sbi_tgts_i, tgt_cs_i, sbi_tgt_ds_i) is
      variable v_sbi_tgt : sbi_tgt_t(rdata(sbi_tgt_o.rdata'range));
    begin
      -- Par défaut, prendre la réponse de l'esclave par défaut
      v_sbi_tgt := sbi_tgt_ds_i;
      for tgt in 0 to NB_TARGET-1 loop
        if tgt_cs_i(tgt) = '1' then
          v_sbi_tgt := sbi_tgts_i(tgt);
        end if;
      end loop;
      v_sbi_tgt.info.name := to_sbi_name(NAME);
      sbi_tgt_o <= v_sbi_tgt;
    end process;
  end generate gen_algo_sel_mux;

end architecture rtl;