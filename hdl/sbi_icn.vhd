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
-- 2026/05/22  1.3      mrosiere Add external default slave
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;
use     asylum.convert_pkg.all;

entity sbi_icn is
  
  generic (
    NAME                 : string     := "sbi_icn";
    NB_TARGET            : positive   := 1;       -- Number of Target Port
    TARGET_ID            : sbi_addrs_t;
    TARGET_ADDR_WIDTH    : naturals_t ;
    TARGET_ADDR_ENCODING : string     ;           -- "binary" / "one_hot"
    ALGO_SEL             : string     := "or";    -- "or" / "mux"
    PIPEOUT_ENABLE       : std_logic_vector(NB_TARGET-1 downto 0) := (others => '0'); -- Pipeline enable per target
    PIPEIN_ENABLE        : std_logic  := '0'      -- Pipeline enable for input
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

  constant TGT_ZEROING      : boolean := ALGO_SEL = "or";

  signal   sbi_tgts         : sbi_tgts_t (NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH -1 downto 0));
  signal   tgt_cs           : std_logic_vector(NB_TARGET-1 downto 0);

  signal   sbi_ini_pipein   : sbi_ini_t(addr(sbi_ini_i.addr'range), 
                                        wdata(sbi_ini_i.wdata'range));
  signal   sbi_tgt_pipein   : sbi_tgt_t(rdata(SBI_DATA_WIDTH -1 downto 0));

  signal   any_cs           : std_logic;
  signal   sbi_ini_ds       : sbi_ini_t(addr(sbi_ini_i.addr'range), 
                                        wdata(sbi_ini_i.wdata'range));
  signal   sbi_tgt_ds       : sbi_tgt_t(rdata(SBI_DATA_WIDTH -1 downto 0));

  signal   sbi_inis_pipeout : sbi_inis_t (NB_TARGET-1 downto 0)(addr(sbi_ini_i.addr'range), 
                                                                wdata(sbi_ini_i.wdata'range));
  signal   sbi_tgts_pipeout : sbi_tgts_t (NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH -1 downto 0));

begin  -- architecture rtl

  -- Detection if at least one slave is addressed
  any_cs        <= or tgt_cs;
  
  -- Input pipeline
  ins_sbi_pipe_input : sbi_pipe
    generic map (
      ENABLE    => PIPEIN_ENABLE = '1'
    )
    port map (
      clk_i     => clk_i,
      cke_i     => cke_i,
      arst_b_i  => arst_b_i,
      sbi_ini_i => sbi_ini_i,
      sbi_tgt_o => sbi_tgt_o,
      sbi_ini_o => sbi_ini_pipein,
      sbi_tgt_i => sbi_tgt_pipein
    );

  -- Signal preparation for the default slave
  process (ALL) is
  begin
    sbi_ini_ds    <= sbi_ini_pipein;
    sbi_ini_ds.cs <= sbi_ini_pipein.cs and not any_cs;
  end process;

  -- Default slave instantiation
  ins_sbi_default_slave : sbi_default_slave
    port map (
      clk_i     => clk_i,
      cke_i     => cke_i,
      arst_b_i  => arst_b_i,
      sbi_ini_i => sbi_ini_ds,
      sbi_tgt_o => sbi_tgt_ds
    );

  ins_sbi_icn_mux : sbi_icn_mux
    generic map (
      NB_TARGET    => NB_TARGET,
      ALGO_SEL     => ALGO_SEL
    )
    port map (
      sbi_tgts_i   => sbi_tgts,
      sbi_tgt_ds_i => sbi_tgt_ds,
      tgt_cs_i     => tgt_cs,
      sbi_tgt_o    => sbi_tgt_pipein
    );
  
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
        sbi_ini_i      => sbi_ini_pipein  ,
        sbi_tgt_o      => sbi_tgts  (tgt),
        sbi_ini_o      => sbi_inis_pipeout(tgt),
        sbi_tgt_i      => sbi_tgts_pipeout(tgt)
        );
    
    ins_sbi_pipe_target : sbi_pipe
      generic map (
        ENABLE    => PIPEOUT_ENABLE(tgt) = '1'
      )
      port map (
        clk_i     => clk_i,
        cke_i     => cke_i,
        arst_b_i  => arst_b_i,
        sbi_ini_i => sbi_inis_pipeout(tgt),
        sbi_tgt_o => sbi_tgts_pipeout(tgt),
        sbi_ini_o => sbi_inis_o(tgt),
        sbi_tgt_i => sbi_tgts_i(tgt)
      );

        
-- pragma translate_off

  process is
  begin  -- process
    wait for 1 ps;
    
    report "["&NAME&"]["& sbi_tgts_i(tgt).info.name &"] Target["&to_hstring(TARGET_ID(tgt))&"] Address : "&integer'image(TARGET_ADDR_WIDTH(tgt)) severity note;

    if (TARGET_ADDR_ENCODING = "one_hot")
    then
      report "  * Index : " &integer'image(onehot_to_integer(TARGET_ID(tgt))) severity note;
      
    end if;
    

    wait;
  end process;

-- pragma translate_on  

  end generate gen_target;
  
end architecture rtl;
