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
use     asylum.pbi_pkg.all;
use     asylum.pbi_wrapper_target_pkg.all;

entity pbi_icn is
  
  generic (
    NB_TARGET            : positive   := 1;       -- Number of Target Port
    TARGET_ID            : pbi_addrs_t;
    TARGET_ADDR_WIDTH    : naturals_t ;
    TARGET_ADDR_ENCODING : string     ;           -- "binary" / "one_hot"
    ALGO_SEL             : string     := "or"     -- "or" / "mux"
    );

  port (
    clk_i               : in std_logic;           -- Clock
    cke_i               : in std_logic;           -- Clock Enable
    arst_b_i            : in std_logic;           -- Asynchronous Reset Active Low

    -- From Bus
    pbi_ini_i           : in    pbi_ini_t;
    pbi_tgt_o           : out   pbi_tgt_t;

    pbi_inis_o          : out   pbi_inis_t (NB_TARGET-1 downto 0);
    pbi_tgts_i          : in    pbi_tgts_t (NB_TARGET-1 downto 0)
);
end entity pbi_icn;

architecture rtl of pbi_icn is

  constant TGT_ZEROING : boolean := ALGO_SEL = "or";
  
  signal   pbi_tgts    : pbi_tgts_t (NB_TARGET-1 downto 0)(rdata(PBI_DATA_WIDTH -1 downto 0));
  signal   tgt_cs      : std_logic_vector(NB_TARGET-1 downto 0);
  
begin  -- architecture rtl



  gen_algo_sel_or: if ALGO_SEL = "or"
  generate
    
    --pbi_tgt_o <= or(pbi_tgts);
    
    process (pbi_tgts) is
      variable pbi_tgt : pbi_tgt_t(rdata(PBI_DATA_WIDTH -1 downto 0));
    begin  -- process

      pbi_tgt := pbi_tgts(0);
      
      for tgt in 1 to NB_TARGET-1
      loop
        pbi_tgt := pbi_tgt or pbi_tgts(tgt);
      end loop;  -- tgt

      pbi_tgt_o <= pbi_tgt;
    end process;

  end generate gen_algo_sel_or;

  gen_algo_sel_mux: if ALGO_SEL = "mux"
  generate

    process (pbi_tgts, tgt_cs) is
      variable pbi_tgt : pbi_tgt_t(rdata(PBI_DATA_WIDTH -1 downto 0));
    begin  -- process
      
      -- Default slave if no target is selected
      pbi_tgt.busy  := '0'; 
      pbi_tgt.rdata := (others => '0');
      
      for tgt in 0 to NB_TARGET-1
      loop
        if tgt_cs(tgt) = '1'
        then
          pbi_tgt := pbi_tgts(tgt);
        end if;
        
      end loop;  -- tgt
      
      pbi_tgt_o <= pbi_tgt;
    end process;
  end generate gen_algo_sel_mux;
  
  gen_target: for tgt in 0 to NB_TARGET-1
  generate
    
    ins_pbi_wrapper_target : pbi_wrapper_target
      generic map(
        SIZE_DATA      => PBI_DATA_WIDTH ,
        SIZE_ADDR_IP   => TARGET_ADDR_WIDTH(tgt),
        ID             => TARGET_ID        (tgt),
        ADDR_ENCODING  => TARGET_ADDR_ENCODING,
        TGT_ZEROING    => TGT_ZEROING
        )
      port map(
        cs_o           => tgt_cs    (tgt),
        pbi_ini_i      => pbi_ini_i      ,
        pbi_tgt_o      => pbi_tgts  (tgt),     
        pbi_ini_o      => pbi_inis_o(tgt),
        pbi_tgt_i      => pbi_tgts_i(tgt)
        );
    
  end generate gen_target;
  
end architecture rtl;
