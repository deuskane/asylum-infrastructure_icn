library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;
library asylum;
use     asylum.pbi_pkg.all;

package icn_pkg is
-- [COMPONENT_INSERT][BEGIN]
component pbi_icn is
  
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
end component pbi_icn;

-- [COMPONENT_INSERT][END]

end icn_pkg;
