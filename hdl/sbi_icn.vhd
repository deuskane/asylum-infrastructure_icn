-------------------------------------------------------------------------------
-- Title      : Interconnection
-- Project    : 
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2025/03/22  1.0      mrosiere Created
-- 2025/04/08  1.1      mrosiere Add selection algo
-- 2025/05/08  1.2      mrosiere Change to into downto
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;

entity sbi_icn is
  
  generic (
    NB_TARGET            : positive   := 1;       -- Number of Target Port
    TARGET_ID            : sbi_addrs_t;
    TARGET_ADDR_WIDTH    : naturals_t ;
    TARGET_ADDR_ENCODING : string     ;           -- "binary" / "one_hot"
    ALGO_SEL             : string     := "or"     -- "or" / "mux"
    );

  port (
    clk_i               : in std_logic;           -- Clock
    cke_i               : in std_logic;           -- Clock Enable
    arst_b_i            : in std_logic;           -- Asynchronous Reset Active Low

    -- From Bus
    sbi_ini_i           : in    sbi_ini_t;
    sbi_tgt_o           : out   sbi_tgt_t;

    sbi_inis_o          : out   sbi_inis_t (NB_TARGET-1 downto 0);
    sbi_tgts_i          : in    sbi_tgts_t (NB_TARGET-1 downto 0)
);
end entity sbi_icn;

architecture rtl of sbi_icn is

  constant TGT_ZEROING : boolean := ALGO_SEL = "or";
  
  signal   sbi_tgts    : sbi_tgts_t (NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH -1 downto 0));
  signal   tgt_cs      : std_logic_vector(NB_TARGET-1 downto 0);
  
begin  -- architecture rtl



  gen_algo_sel_or: if ALGO_SEL = "or"
  generate
    
    --sbi_tgt_o <= or(sbi_tgts);
    
    process (sbi_tgts) is
      variable sbi_tgt : sbi_tgt_t(rdata(SBI_DATA_WIDTH -1 downto 0));
    begin  -- process

      sbi_tgt := sbi_tgts(0);
      
      for tgt in 1 to NB_TARGET-1
      loop
        sbi_tgt := sbi_tgt or sbi_tgts(tgt);
      end loop;  -- tgt

      sbi_tgt_o <= sbi_tgt;
    end process;

  end generate gen_algo_sel_or;

  gen_algo_sel_mux: if ALGO_SEL = "mux"
  generate

    process (sbi_tgts, tgt_cs) is
      variable sbi_tgt : sbi_tgt_t(rdata(SBI_DATA_WIDTH -1 downto 0));
    begin  -- process
      
      -- Default slave if no target is selected
      sbi_tgt.ready := '1'; 
      sbi_tgt.rdata := (others => '0');
      sbi_tgt.info.name := to_sbi_name("Default");
      for tgt in 0 to NB_TARGET-1
      loop
        if tgt_cs(tgt) = '1'
        then
          sbi_tgt := sbi_tgts(tgt);
        end if;
        
      end loop;  -- tgt
      
      sbi_tgt_o <= sbi_tgt;
    end process;
  end generate gen_algo_sel_mux;
  
  gen_target: for tgt in 0 to NB_TARGET-1
  generate
    
    ins_sbi_wrapper_target : sbi_wrapper_target
      generic map(
        SIZE_DATA      => SBI_DATA_WIDTH ,
        SIZE_ADDR_IP   => TARGET_ADDR_WIDTH(tgt),
        ID             => TARGET_ID        (tgt),
        ADDR_ENCODING  => TARGET_ADDR_ENCODING,
        TGT_ZEROING    => TGT_ZEROING
        )
      port map(
        cs_o           => tgt_cs    (tgt),
        sbi_ini_i      => sbi_ini_i      ,
        sbi_tgt_o      => sbi_tgts  (tgt),     
        sbi_ini_o      => sbi_inis_o(tgt),
        sbi_tgt_i      => sbi_tgts_i(tgt)
        );
    
  end generate gen_target;
  
end architecture rtl;
