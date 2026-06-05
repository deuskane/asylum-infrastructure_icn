library IEEE;
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;
library asylum;
use     asylum.sbi_pkg.all;

package icn_pkg is
-- [COMPONENT_INSERT][BEGIN]
component sbi_default_slave is
  port (
    clk_i               : in std_logic;
    cke_i               : in std_logic;
    arst_b_i            : in std_logic;

    sbi_ini_i           : in  sbi_ini_t;
    sbi_tgt_o           : out sbi_tgt_t
);
end component sbi_default_slave;

component sbi_icn is
  
  generic (
    NAME                   : string     := "sbi_icn";
    NB_MASTER              : positive   := 1;       -- Number of Initiator Port
    MASTER_SEL             : string     := "fix";   -- "fix" / "roundrobin"
    NB_TARGET              : positive   := 1;       -- Number of Target Port
    TARGET_SEL             : string     := "or";    -- "or" / "mux"
    TARGET_ID              : sbi_addrs_t;
    TARGET_ADDR_WIDTH      : naturals_t ;
    TARGET_ADDR_ENCODING   : string     ;           -- "binary" / "one_hot"
    INTERNAL_DEFAULT_SLAVE : boolean    := True;    -- If True, a default slave is implemented internally.
                                                    -- If False, the default slave is implemented externally and connected to the last target port (NB_TARGET)
    PIPEOUT_ENABLE         : std_logic_vector(NB_TARGET-1 downto 0) := (others => '0'); -- Pipeline enable per target
    PIPEIN_ENABLE          : std_logic  := '0';      -- Pipeline enable for input

    -- Internal generics
    NB_TARGET_INT          : positive   := NB_TARGET + (1-boolean'pos(INTERNAL_DEFAULT_SLAVE))
    );

  port (
    clk_i               : in std_logic;           -- Clock
    cke_i               : in std_logic;           -- Clock Enable
    arst_b_i            : in std_logic;           -- Asynchronous Reset Active Low

    -- From Bus
    sbi_inis_i          : in    sbi_inis_t (NB_MASTER-1 downto 0);
    sbi_tgts_o          : out   sbi_tgts_t (NB_MASTER-1 downto 0);
    
    sbi_inis_o          : out   sbi_inis_t (NB_TARGET_INT-1 downto 0);
    sbi_tgts_i          : in    sbi_tgts_t (NB_TARGET_INT-1 downto 0)
);
end component sbi_icn;

component sbi_icn_mux_mst is
  generic (
    NB_MASTER  : positive := 1;
    MASTER_SEL : string   := "fix" -- "fix" / "roundrobin"
  );
  port (
    clk_i      : in  std_logic;
    cke_i      : in  std_logic;
    arst_b_i   : in  std_logic;

    -- From Masters
    sbi_inis_i : in  sbi_inis_t(NB_MASTER-1 downto 0);
    sbi_tgts_o : out sbi_tgts_t(NB_MASTER-1 downto 0);

    -- To Interconnect
    sbi_ini_o  : out sbi_ini_t;
    sbi_tgt_i  : in  sbi_tgt_t
  );
end component sbi_icn_mux_mst;

component sbi_icn_mux_tgt is
  generic (
    NB_TARGET    : positive := 1;
    TARGET_SEL   : string   := "or"
  );
  port (
    sbi_tgts_i   : in  sbi_tgts_t(NB_TARGET-1 downto 0);
    sbi_tgt_ds_i : in  sbi_tgt_t;
    tgt_cs_i     : in  std_logic_vector(NB_TARGET-1 downto 0);
    sbi_tgt_o    : out sbi_tgt_t
  );
end component sbi_icn_mux_tgt;

component sbi_pipe is
  generic 
  (ENABLE              : boolean := true
  ;VERBOSE             : boolean := false
  );
  port 
  (clk_i               : in std_logic
  ;cke_i               : in std_logic
  ;arst_b_i            : in std_logic

  -- Initiator side (from Master)
  ;sbi_ini_i           : in  sbi_ini_t
  ;sbi_tgt_o           : out sbi_tgt_t

   -- Target side (to Slave)
  ;sbi_ini_o           : out sbi_ini_t
  ;sbi_tgt_i           : in  sbi_tgt_t
);
end component sbi_pipe;

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
