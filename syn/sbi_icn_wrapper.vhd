-------------------------------------------------------------------------------
-- Title      : sbi_icn_wrapper
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : sbi_icn_wrapper.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description:
-- Wrapper (lint_ghdl, lint_ghdl_synth_*) : sbi_icn (and so
-- sbi_pipe, sbi_icn_mux_mst, sbi_icn_mux_tgt, sbi_wrapper_target and
-- sbi_default_slave) with flat and constrained ports (sbi_icn has
-- unconstrained SBI record ports, and TARGET_ID / TARGET_ADDR_WIDTH are
-- arrays without default that cannot be set on the command line).
-- The address map is selected by ADDR_MAP (sbi_icn_wrapper_pkg) :
--   "picosoc_icn2" : ICN2 of asylum-soc-picosoc, 10 targets, binary (default)
--   "picosoc_icn1" : ICN1 of asylum-soc-picosoc, 3 targets, binary, the last
--                    one is the external default slave (ID 0, 8 bits)
--   "tb"           : map of tb_sbi_icn, 3 targets of 6 bits, binary
--   "one_hot"      : 4 targets (address bits 4 to 7) of 4 bits, one_hot
-- The other generics are forwarded, PIPEIN / PIPEOUT set PIPEIN_ENABLE and
-- every bit of PIPEOUT_ENABLE. SBI address / data width : SBI_ADDR_WIDTH /
-- SBI_DATA_WIDTH, port m (target t) on the bits m*WIDTH+WIDTH-1 downto
-- m*WIDTH of the flat vectors, the info name of target t is "target<t>".
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-10-20  1.0      mrosiere Created
-- 2026-10-24  1.1      mrosiere Was sbi_icn_synth_top, library asylum
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
library asylum;
use     asylum.sbi_pkg.all;

package sbi_icn_wrapper_pkg is

  -- ICN2 of asylum-soc-picosoc (PicoSoC_pkg / PicoSoC_user) : switch, led0,
  -- led1, uart, spi, timer, crc, spinlock, mailbox, ram2
  constant PICOSOC_ICN2_ID : sbi_addrs_t(0 to 9) :=
    (x"04", x"08", x"0C", x"20", x"18", x"28", x"10", x"02", x"14", x"40");
  constant PICOSOC_ICN2_AW : naturals_t (0 to 9) :=
    (2, 2, 2, 3, 2, 3, 2, 1, 2, 6);

  -- ICN1 of asylum-soc-picosoc : gic, ram1, icn2 (external default slave)
  constant PICOSOC_ICN1_ID : sbi_addrs_t(0 to 2) := (x"00", x"80", x"00");
  constant PICOSOC_ICN1_AW : naturals_t (0 to 2) := (1, 7, 8);

  -- tb_sbi_icn
  constant TB_ID           : sbi_addrs_t(0 to 2) := (x"00", x"40", x"80");
  constant TB_AW           : naturals_t (0 to 2) := (6, 6, 6);

  -- One hot decoding, one address bit (4 to 7) per target
  constant ONE_HOT_ID      : sbi_addrs_t(0 to 3) := (x"10", x"20", x"40", x"80");
  constant ONE_HOT_AW      : naturals_t (0 to 3) := (4, 4, 4, 4);

  function map_id         (m : string) return sbi_addrs_t;
  function map_addr_width (m : string) return naturals_t;
  function map_encoding   (m : string) return string;
  function map_nb_target  (m : string) return positive;
  function to_sl          (b : boolean) return std_logic;

end package sbi_icn_wrapper_pkg;

package body sbi_icn_wrapper_pkg is

  function map_id (m : string) return sbi_addrs_t is
  begin
    if    m = "picosoc_icn1" then return PICOSOC_ICN1_ID;
    elsif m = "tb"           then return TB_ID;
    elsif m = "one_hot"      then return ONE_HOT_ID;
    else                          return PICOSOC_ICN2_ID;
    end if;
  end function map_id;

  function map_addr_width (m : string) return naturals_t is
  begin
    if    m = "picosoc_icn1" then return PICOSOC_ICN1_AW;
    elsif m = "tb"           then return TB_AW;
    elsif m = "one_hot"      then return ONE_HOT_AW;
    else                          return PICOSOC_ICN2_AW;
    end if;
  end function map_addr_width;

  function map_encoding (m : string) return string is
  begin
    if m = "one_hot" then return "one_hot";
    else                  return "binary";
    end if;
  end function map_encoding;

  function map_nb_target (m : string) return positive is
    constant ID : sbi_addrs_t := map_id(m);
  begin
    return ID'length;
  end function map_nb_target;

  function to_sl (b : boolean) return std_logic is
  begin
    if b then return '1';
    else      return '0';
    end if;
  end function to_sl;

end package body sbi_icn_wrapper_pkg;

library ieee;
use     ieee.std_logic_1164.all;
library asylum;
use     asylum.sbi_pkg.all;
library work;
use     work.sbi_icn_wrapper_pkg.all;

entity sbi_icn_wrapper is
  generic (
    NB_MASTER              : positive := 1;
    MASTER_SEL             : string   := "fix";
    TARGET_SEL             : string   := "or";
    ADDR_MAP               : string   := "picosoc_icn2";
    INTERNAL_DEFAULT_SLAVE : boolean  := true;
    PIPEIN                 : boolean  := false;
    PIPEOUT                : boolean  := false
  );
  port (
    clk_i         : in  std_logic;
    cke_i         : in  std_logic;
    arst_b_i      : in  std_logic;

    -- From Masters (SBI)
    cs_i          : in  std_logic_vector(NB_MASTER               -1 downto 0);
    re_i          : in  std_logic_vector(NB_MASTER               -1 downto 0);
    we_i          : in  std_logic_vector(NB_MASTER               -1 downto 0);
    addr_i        : in  std_logic_vector(NB_MASTER*SBI_ADDR_WIDTH-1 downto 0);
    wdata_i       : in  std_logic_vector(NB_MASTER*SBI_DATA_WIDTH-1 downto 0);
    ready_o       : out std_logic_vector(NB_MASTER               -1 downto 0);
    rdata_o       : out std_logic_vector(NB_MASTER*SBI_DATA_WIDTH-1 downto 0);

    -- To Targets (SBI)
    tgt_cs_o      : out std_logic_vector(map_nb_target(ADDR_MAP)               -1 downto 0);
    tgt_re_o      : out std_logic_vector(map_nb_target(ADDR_MAP)               -1 downto 0);
    tgt_we_o      : out std_logic_vector(map_nb_target(ADDR_MAP)               -1 downto 0);
    tgt_addr_o    : out std_logic_vector(map_nb_target(ADDR_MAP)*SBI_ADDR_WIDTH-1 downto 0);
    tgt_wdata_o   : out std_logic_vector(map_nb_target(ADDR_MAP)*SBI_DATA_WIDTH-1 downto 0);
    tgt_ready_i   : in  std_logic_vector(map_nb_target(ADDR_MAP)               -1 downto 0);
    tgt_rdata_i   : in  std_logic_vector(map_nb_target(ADDR_MAP)*SBI_DATA_WIDTH-1 downto 0)
  );
end entity sbi_icn_wrapper;

architecture rtl of sbi_icn_wrapper is

  constant NB_TARGET   : positive := map_nb_target(ADDR_MAP);
  constant AW          : natural  := SBI_ADDR_WIDTH;
  constant DW          : natural  := SBI_DATA_WIDTH;

  signal sbi_inis_i    : sbi_inis_t(NB_MASTER-1 downto 0)(addr (AW-1 downto 0),
                                                          wdata(DW-1 downto 0));
  signal sbi_tgts_o    : sbi_tgts_t(NB_MASTER-1 downto 0)(rdata(DW-1 downto 0));
  signal sbi_inis_o    : sbi_inis_t(NB_TARGET-1 downto 0)(addr (AW-1 downto 0),
                                                          wdata(DW-1 downto 0));
  signal sbi_tgts_i    : sbi_tgts_t(NB_TARGET-1 downto 0)(rdata(DW-1 downto 0));

begin

  gen_master: for m in 0 to NB_MASTER-1 generate
    sbi_inis_i(m).cs    <= cs_i   (m);
    sbi_inis_i(m).re    <= re_i   (m);
    sbi_inis_i(m).we    <= we_i   (m);
    sbi_inis_i(m).addr  <= addr_i (m*AW+AW-1 downto m*AW);
    sbi_inis_i(m).wdata <= wdata_i(m*DW+DW-1 downto m*DW);
    ready_o(m)                     <= sbi_tgts_o(m).ready;
    rdata_o(m*DW+DW-1 downto m*DW) <= sbi_tgts_o(m).rdata;
  end generate gen_master;

  gen_target: for t in 0 to NB_TARGET-1 generate
    tgt_cs_o   (t)                     <= sbi_inis_o(t).cs;
    tgt_re_o   (t)                     <= sbi_inis_o(t).re;
    tgt_we_o   (t)                     <= sbi_inis_o(t).we;
    tgt_addr_o (t*AW+AW-1 downto t*AW) <= sbi_inis_o(t).addr;
    tgt_wdata_o(t*DW+DW-1 downto t*DW) <= sbi_inis_o(t).wdata;
    sbi_tgts_i(t).ready <= tgt_ready_i(t);
    sbi_tgts_i(t).rdata <= tgt_rdata_i(t*DW+DW-1 downto t*DW);
    sbi_tgts_i(t).info  <= (name => to_sbi_name("target" & integer'image(t)));
  end generate gen_target;

  ins_sbi_icn : entity asylum.sbi_icn
    generic map (
      NB_MASTER              => NB_MASTER,
      MASTER_SEL             => MASTER_SEL,
      NB_TARGET              => NB_TARGET,
      TARGET_SEL             => TARGET_SEL,
      TARGET_ID              => map_id(ADDR_MAP),
      TARGET_ADDR_WIDTH      => map_addr_width(ADDR_MAP),
      TARGET_ADDR_ENCODING   => map_encoding(ADDR_MAP),
      INTERNAL_DEFAULT_SLAVE => INTERNAL_DEFAULT_SLAVE,
      PIPEOUT_ENABLE         => (NB_TARGET-1 downto 0 => to_sl(PIPEOUT)),
      PIPEIN_ENABLE          => to_sl(PIPEIN)
    )
    port map (
      clk_i                  => clk_i,
      cke_i                  => cke_i,
      arst_b_i               => arst_b_i,
      sbi_inis_i             => sbi_inis_i,
      sbi_tgts_o             => sbi_tgts_o,
      sbi_inis_o             => sbi_inis_o,
      sbi_tgts_i             => sbi_tgts_i
    );

end architecture rtl;
