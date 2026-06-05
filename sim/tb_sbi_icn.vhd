-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Testbench for SBI Interconnect
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_textio.all; -- Pour textio
use     std.textio.all;            -- Pour textio

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;
use     asylum.convert_pkg.all; -- Pour to_hstring (assuming it exists)

library uvvm_util;
context uvvm_util.uvvm_util_context;
library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

entity tb_sbi_icn is
end entity tb_sbi_icn;

architecture sim of tb_sbi_icn is

  constant C_SCOPE        : string := "TB_SBI_ICN";
  use work.tb_sbi_icn_pkg.all;
  use work.tb_sbi_icn_suite_pkg.all;

  -- Clock and Reset
  constant C_CLK_PERIOD   : time := 10 ns;
  signal   clk_i          : std_logic := '0';
  signal   cke_i          : std_logic := '1';
  signal   arst_b_i       : std_logic := '0'; -- Active low reset

  -- Master configuration
  constant C_NB_MASTER            : positive   := 2;
  constant C_MASTER_SEL           : string     := "roundrobin";

  -- Constants for sbi_icn generics
  constant C_NB_TARGET            : positive   := 3;
  -- Target IDs and Address Widths
  -- Using 2 MSBs for target ID (8-bit total), so each target has 6 bits of local address space
  constant C_TARGET_ID            : sbi_addrs_t(0 to C_NB_TARGET-1) := (
    0 => x"00", -- Target 0: 0x00 to 0x3F
    1 => x"40", -- Target 1: 0x40 to 0x7F
    2 => x"80"  -- Target 2: 0x80 to 0xBF
  );
  constant C_TARGET_ADDR_WIDTH    : naturals_t(0 to C_NB_TARGET-1) := (
    0 => 6, 
    1 => 6, 
    2 => 6  
  );

  constant C_TARGET_MEM_SIZE      : naturals_t(0 to C_NB_TARGET-1) := (
    0 => 2**C_TARGET_ADDR_WIDTH(0), 
    1 => 2**C_TARGET_ADDR_WIDTH(1), 
    2 => 2**C_TARGET_ADDR_WIDTH(2)  
  );

  constant C_TARGET_ADDR_ENCODING : string     := "binary";
  constant C_ALGO_SEL             : string     := "mux"; -- Using MUX for clear response
  constant C_PIPEOUT_ENABLE       : std_logic_vector(C_NB_TARGET-1 downto 0) := (others => '0');
  constant C_PIPEIN_ENABLE        : std_logic  := '0';

  -- SBI Bus Signals
  -- Assuming sbi_ini_t and sbi_tgt_t are defined with SBI_ADDR_WIDTH and SBI_DATA_WIDTH in sbi_pkg
  signal sbi_inis_i       : sbi_inis_t (C_NB_MASTER-1 downto 0)(addr (SBI_ADDR_WIDTH-1 downto 0),
                                                                wdata(SBI_DATA_WIDTH-1 downto 0));
  signal sbi_tgts_o       : sbi_tgts_t (C_NB_MASTER-1 downto 0)(rdata(SBI_DATA_WIDTH-1 downto 0));

  signal sbi_inis_o       : sbi_inis_t (C_NB_TARGET-1 downto 0)(addr (SBI_ADDR_WIDTH-1 downto 0),
                                                                wdata(SBI_DATA_WIDTH-1 downto 0));
  signal sbi_tgts_i       : sbi_tgts_t (C_NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH-1 downto 0));

  -- UVVM SBI Interface
  signal sbi_ifs          : t_sbi_if_array(0 to C_NB_MASTER-1) := (others => (ready => 'Z', 
                                                          rdata => (others => 'Z'),
                                                          cs    => 'Z',
                                                          rena  => 'Z', 
                                                          wena  => 'Z', 
                                                          wdata => (others => 'Z'), 
                                                          addr  => (others => 'Z'))); 

begin

  -- Instantiate the Unit Under Test (UUT)
  dut : sbi_icn
    generic map (
      NAME                 => "sbi_icn_tb",
      NB_MASTER            => C_NB_MASTER,
      MASTER_SEL           => C_MASTER_SEL,
      NB_TARGET            => C_NB_TARGET,
      TARGET_ID            => C_TARGET_ID,
      TARGET_ADDR_WIDTH    => C_TARGET_ADDR_WIDTH,
      TARGET_ADDR_ENCODING => C_TARGET_ADDR_ENCODING,
      ALGO_SEL             => C_ALGO_SEL,
      PIPEOUT_ENABLE       => C_PIPEOUT_ENABLE,
      PIPEIN_ENABLE        => C_PIPEIN_ENABLE
    )
    port map (
      clk_i     => clk_i,
      cke_i     => cke_i,
      arst_b_i  => arst_b_i,
      sbi_inis_i => sbi_inis_i,
      sbi_tgts_o => sbi_tgts_o,
      sbi_inis_o => sbi_inis_o,
      sbi_tgts_i => sbi_tgts_i
    );

  -- Mapping UVVM SBI IF to Asylum SBI Ports
  gen_master_if: for m in 0 to C_NB_MASTER-1 generate
    sbi_inis_i(m).cs    <= sbi_ifs(m).cs;
    sbi_inis_i(m).addr  <= std_logic_vector(sbi_ifs(m).addr);
    sbi_inis_i(m).re    <= sbi_ifs(m).rena;
    sbi_inis_i(m).we    <= sbi_ifs(m).wena;
    sbi_inis_i(m).wdata <= sbi_ifs(m).wdata;
    sbi_ifs(m).ready    <= sbi_tgts_o(m).ready;
    sbi_ifs(m).rdata    <= sbi_tgts_o(m).rdata;
  end generate;

  -- Clock generation
  clk_gen : process
  begin
    clk_i <= '0';
    wait for C_CLK_PERIOD / 2;
    loop
      clk_i <= '1';
      wait for C_CLK_PERIOD / 2;
      clk_i <= '0';
      wait for C_CLK_PERIOD / 2;
    end loop;
  end process clk_gen;

  -- Reset generation
  reset_gen : process
  begin
    arst_b_i <= '0';
    wait for C_CLK_PERIOD * 2;
    arst_b_i <= '1';
    wait for C_CLK_PERIOD; -- Hold reset high for a cycle
    wait;
  end process reset_gen;

  -- Target Responder Processes
  target_responder_gen: for i in 0 to C_NB_TARGET-1 generate
    -- Simple memory model for each target
    type mem_array_t is array (0 to C_TARGET_MEM_SIZE(i) -1) of std_logic_vector(SBI_DATA_WIDTH-1 downto 0);
    signal mem : mem_array_t := (others => (others => '0'));
  begin
    -- Combinatorial response (0-wait-state) to avoid stale ready bits between transactions
    sbi_tgts_i(i).ready <= sbi_inis_o(i).cs;
    sbi_tgts_i(i).rdata <= mem(to_integer(unsigned(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)))) 
                           when sbi_inis_o(i).cs = '1' else (others => '0');

    process (clk_i)
      variable v_addr_idx : natural;
    begin
      if rising_edge(clk_i) then
        if arst_b_i = '0' then
          mem <= (others => (others => '0'));
        elsif cke_i = '1' then
          if sbi_inis_o(i).cs = '1' then
            -- The address coming to the target is already adjusted (local address)
            -- 8-bit data/address: direct indexing
            v_addr_idx := to_integer(unsigned(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)));
            
            if v_addr_idx < C_TARGET_MEM_SIZE(i) then -- Check bounds
              if sbi_inis_o(i).we = '1' then
                mem(v_addr_idx) <= sbi_inis_o(i).wdata;
                log(ID_SEQUENCER, "Target " & integer'image(i) & " Write: Local Addr=" & to_hstring(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)) & ", Data=" & to_hstring(sbi_inis_o(i).wdata), C_SCOPE);
              elsif sbi_inis_o(i).re = '1' then
                log(ID_SEQUENCER, "Target " & integer'image(i) & " Read: Local Addr=" & to_hstring(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)) & ", Data=" & to_hstring(mem(v_addr_idx)), C_SCOPE);
              end if;
            else
              -- Address out of bounds for this target's memory
              log(ID_SEQUENCER, "Target " & integer'image(i) & " Error: Local Address " & to_hstring(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)) & " out of bounds. Responding with default.", C_SCOPE);
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate target_responder_gen;

  -- Test Stimulus Process
  test_stimulus : process
    -- No local constants needed here, all passed to run_test_suite
  begin
    run_test_suite(
      clk_i          => clk_i,
      arst_b_i       => arst_b_i,
      sbi_ifs        => sbi_ifs,
      C_NB_MASTER    => C_NB_MASTER,
      C_NB_TARGET    => C_NB_TARGET,
      C_TARGET_ID    => C_TARGET_ID,
      C_TARGET_MEM_SIZE => C_TARGET_MEM_SIZE,
      C_CLK_PERIOD   => C_CLK_PERIOD,
      C_SCOPE        => C_SCOPE
    );
 end process test_stimulus;

end architecture sim;