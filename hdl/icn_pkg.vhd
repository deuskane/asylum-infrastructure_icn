library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;
library asylum;
use     asylum.sbi_pkg.all;

package icn_pkg is
-- [COMPONENT_INSERT][BEGIN]
component sbi_icn is
  
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
end component sbi_icn;

component sbi_wrapper_target is
  -- =====[ Parameters ]==========================
  generic (
    SIZE_DATA      : natural := 8;
    SIZE_ADDR_IP   : natural := 0;
    ID             : std_logic_vector (SBI_ADDR_WIDTH-1 downto 0) := (others => '0');
    ADDR_ENCODING  : string  := "binary"; -- "binary" / "one_hot"
    TGT_ZEROING    : boolean := false
    
     );
  -- =====[ Interfaces ]==========================
  port (
    cs_o                : out   std_logic;

    -- To IP
    sbi_ini_o           : out   sbi_ini_t;
    sbi_tgt_i           : in    sbi_tgt_t;
    
    -- From Bus
    sbi_ini_i           : in    sbi_ini_t;
    sbi_tgt_o           : out   sbi_tgt_t
    );
end component sbi_wrapper_target;

-- [COMPONENT_INSERT][END]

end icn_pkg;
