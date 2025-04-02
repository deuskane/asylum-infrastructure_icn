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
-------------------------------------------------------------------------------


library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library work;
use     work.pbi_pkg.all;

entity pci_icn is
  
  generic (
    NB_TARGET         : positive   := 1;          -- Number of Target Port
    TARGET_ID         : pbi_addrs_t;
    TARGET_ADDR_WIDTH : pbi_naturals_t
    );

  port (
    clk_i               : in std_logic;           -- Clock
    cke_i               : in std_logic;           -- Clock Enable
    arst_b_i            : in std_logic;           -- Asynchronous Reset Active Low

    -- From Bus
    pbi_ini_i           : in    pbi_ini_t;
    pbi_tgt_o           : out   pbi_tgt_t;

    pbi_inis_o          : out   pbi_inis_t (0 to NB_TARGET-1);
    pbi_tgts_i          : in    pbi_tgts_t (0 to NB_TARGET-1)
);
end entity pci_icn;

architecture rtl of pci_icn is

  signal pbi_tgts : pbi_tgts_t (0 to NB_TARGET-1)(rdata(PBI_DATA_WIDTH -1 downto 0));
  
begin  -- architecture rtl

  
  pbi_tgt_o <= or(pbi_tgts);  
  
  gen_target: for tgt in pbi_inis_o'range
  generate

    ins_pbi_wrapper_target : entity work.pbi_wrapper_target(rtl)
      generic map(
        SIZE_DATA      => PBI_DATA_WIDTH ,
        SIZE_ADDR_IP   => TARGET_ADDR_WIDTH(tgt),
        ID             => TARGET_ID        (tgt)
        )
      port map(
        clk_i          => clk_i          ,
        cke_i          => cke_i          ,
        arstn_i        => arst_b_i       ,
        pbi_ini_i      => pbi_ini_i      ,
        pbi_tgt_o      => pbi_tgts  (tgt),     
        pbi_ini_o      => pbi_inis_o(tgt),
        pbi_tgt_i      => pbi_tgts_i(tgt)
        );
    
  end generate gen_target;

  
end architecture rtl;
