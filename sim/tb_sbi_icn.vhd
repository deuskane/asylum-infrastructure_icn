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
-- 2026-10-05  1.1      mrosiere Add PIPEIN / PIPEOUT generics (sbi_pipe coverage)
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
  generic (
    PIPEIN                 : boolean := false;        -- true: sbi_pipe stage on every master port (PIPEIN_ENABLE  = '1')
    PIPEOUT                : boolean := false;        -- true: sbi_pipe stage on every target port (PIPEOUT_ENABLE = all '1')
    MASTER_SEL             : string  := "roundrobin"; -- "fix" / "roundrobin"
    TARGET_SEL             : string  := "mux";        -- "or" / "mux"
    TARGET_ADDR_ENCODING   : string  := "binary";     -- "binary" / "one_hot"
    INTERNAL_DEFAULT_SLAVE : boolean := true;         -- false: the default slave is a memory model on the last target port
    WAIT_STATES            : natural := 0             -- target i answers after WAIT_STATES*i cycles
    );
end entity tb_sbi_icn;

architecture sim of tb_sbi_icn is

  constant C_SCOPE        : string := "TB_SBI_ICN";

  function bool_to_sl (b : boolean) return std_logic is
  begin
    if b then return '1'; else return '0'; end if;
  end function bool_to_sl;
  use work.tb_sbi_icn_pkg.all;
  use work.tb_sbi_icn_suite_pkg.all;

  -- Clock and Reset
  constant C_CLK_PERIOD   : time := 10 ns;
  signal   clk_i          : std_logic := '0';
  signal   cke_i          : std_logic := '1';
  signal   arst_b_i       : std_logic := '0'; -- Active low reset

  -- Master configuration
  constant C_NB_MASTER            : positive   := 2;
  constant C_MASTER_SEL           : string     := MASTER_SEL;

  -- Constants for sbi_icn generics
  -- 3 memory targets, plus the external default slave (memory model on the whole address range)
  constant C_NB_TARGET_MEM        : positive   := 3;
  constant C_NB_TARGET            : positive   := C_NB_TARGET_MEM + 1 - boolean'pos(INTERNAL_DEFAULT_SLAVE);

  -- Target IDs and Address Widths
  -- binary  : 2 MSBs for target ID, 6 bits of local address space
  --           Target 0: 0x00 to 0x3F, Target 1: 0x40 to 0x7F, Target 2: 0x80 to 0xBF, unmapped: 0xC0 to 0xFF
  -- one_hot : select bits 5, 6 and 7, 5 bits of local address space
  --           Target 0: 0x20 to 0x3F, Target 1: 0x40 to 0x5F, Target 2: 0x80 to 0x9F, unmapped: 0x00 to 0x1F
  -- External default slave (last target) : ID 0, full address width
  function target_id return sbi_addrs_t is
    variable res : sbi_addrs_t(0 to C_NB_TARGET-1) := (others => (others => '0'));
  begin
    for t in 0 to C_NB_TARGET_MEM-1 loop
      if TARGET_ADDR_ENCODING = "one_hot" then
        res(t) := std_logic_vector(to_unsigned(2**(5+t), SBI_ADDR_WIDTH));
      else
        res(t) := std_logic_vector(to_unsigned(64*t    , SBI_ADDR_WIDTH));
      end if;
    end loop;
    return res;
  end function target_id;

  function target_addr_width return naturals_t is
    variable res : naturals_t(0 to C_NB_TARGET-1) := (others => SBI_ADDR_WIDTH);
  begin
    for t in 0 to C_NB_TARGET_MEM-1 loop
      if TARGET_ADDR_ENCODING = "one_hot" then
        res(t) := 5;
      else
        res(t) := 6;
      end if;
    end loop;
    return res;
  end function target_addr_width;

  function target_mem_size return naturals_t is
    variable res : naturals_t(0 to C_NB_TARGET-1);
  begin
    for t in res'range loop
      res(t) := 2**target_addr_width(t);
    end loop;
    return res;
  end function target_mem_size;

  function target_wait return naturals_t is
    variable res : naturals_t(0 to C_NB_TARGET-1);
  begin
    for t in res'range loop
      res(t) := WAIT_STATES*t;
    end loop;
    return res;
  end function target_wait;

  function ds_addr return sbi_addrs_t is
  begin
    if TARGET_ADDR_ENCODING = "one_hot" then
      return (x"00", x"1F");
    else
      return (x"C0", x"FF");
    end if;
  end function ds_addr;

  constant C_TARGET_ID            : sbi_addrs_t(0 to C_NB_TARGET-1) := target_id;
  constant C_TARGET_ADDR_WIDTH    : naturals_t (0 to C_NB_TARGET-1) := target_addr_width;
  constant C_TARGET_MEM_SIZE      : naturals_t (0 to C_NB_TARGET-1) := target_mem_size;
  constant C_TARGET_WAIT          : naturals_t (0 to C_NB_TARGET-1) := target_wait;
  constant C_DS_ADDR              : sbi_addrs_t(0 to 1)             := ds_addr;    -- Unmapped addresses

  constant C_TARGET_ADDR_ENCODING : string     := TARGET_ADDR_ENCODING;
  constant C_TARGET_SEL           : string     := TARGET_SEL;
  constant C_PIPEOUT_ENABLE       : std_logic_vector(C_NB_TARGET-1 downto 0) := (others => bool_to_sl(PIPEOUT));
  constant C_PIPEIN_ENABLE        : std_logic  := bool_to_sl(PIPEIN);

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
      TARGET_SEL           => C_TARGET_SEL,
      TARGET_ID            => C_TARGET_ID,
      TARGET_ADDR_WIDTH    => C_TARGET_ADDR_WIDTH,
      TARGET_ADDR_ENCODING => C_TARGET_ADDR_ENCODING,
      INTERNAL_DEFAULT_SLAVE => INTERNAL_DEFAULT_SLAVE,
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

  -- Protocol monitor (all test cases): at most one master gets ready in a cycle,
  -- and only a master which has a pending request
  protocol_monitor : process (clk_i)
    variable v_nb_ready : natural;
  begin
    if rising_edge(clk_i) and arst_b_i = '1' then
      v_nb_ready := 0;
      for m in 0 to C_NB_MASTER-1 loop
        if sbi_tgts_o(m).ready = '1' then
          v_nb_ready := v_nb_ready + 1;
          check_value(sbi_inis_i(m).cs = '1', ERROR, "Master " & integer'image(m) & " got ready without request", C_SCOPE, msg_id => ID_NEVER);
        end if;
      end loop;
      check_value(v_nb_ready <= 1, ERROR, "Several masters got ready in the same cycle", C_SCOPE, msg_id => ID_NEVER);
    end if;
  end process protocol_monitor;

  -- Target Responder Processes
  -- Memory model answering after C_TARGET_WAIT(i) cycles. Out of an access it drives ready = 1 and
  -- rdata = 0xFF (as the generated CSR blocks do), and during the wait states it drives wrong data:
  -- the interconnect must ignore ("mux") or zero ("or") the responses of the targets not selected
  target_responder_gen: for i in 0 to C_NB_TARGET-1 generate
    type mem_array_t is array (0 to C_TARGET_MEM_SIZE(i) -1) of std_logic_vector(SBI_DATA_WIDTH-1 downto 0);
    signal mem      : mem_array_t := (others => (others => '0'));
    signal addr_idx : natural range 0 to C_TARGET_MEM_SIZE(i) -1;
    signal wait_cnt : natural range 0 to C_TARGET_WAIT(i) := 0;
    signal ack      : std_logic;
  begin
    addr_idx            <= to_integer(unsigned(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)));
    ack                 <= sbi_inis_o(i).cs when wait_cnt = C_TARGET_WAIT(i) else '0';

    sbi_tgts_i(i).ready <= ack                when sbi_inis_o(i).cs = '1' else '1';
    sbi_tgts_i(i).rdata <= mem(addr_idx)      when ack              = '1' else
                           not mem(addr_idx)  when sbi_inis_o(i).cs = '1' else
                           (others => '1');
    sbi_tgts_i(i).info.name <= to_sbi_name("target" & integer'image(i));

    process (clk_i)
    begin
      if rising_edge(clk_i) then
        if arst_b_i = '0' then
          mem      <= (others => (others => '0'));
          wait_cnt <= 0;
        elsif cke_i = '1' then
          if sbi_inis_o(i).cs = '0' or ack = '1' then
            wait_cnt <= 0;
          else
            wait_cnt <= wait_cnt + 1;
          end if;

          if ack = '1' then
            -- The address coming to the target is already adjusted (local address)
            if sbi_inis_o(i).we = '1' then
              mem(addr_idx) <= sbi_inis_o(i).wdata;
              log(ID_SEQUENCER, "Target " & integer'image(i) & " Write: Local Addr=" & to_hstring(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)) & ", Data=" & to_hstring(sbi_inis_o(i).wdata), C_SCOPE);
            elsif sbi_inis_o(i).re = '1' then
              log(ID_SEQUENCER, "Target " & integer'image(i) & " Read: Local Addr=" & to_hstring(sbi_inis_o(i).addr(C_TARGET_ADDR_WIDTH(i)-1 downto 0)) & ", Data=" & to_hstring(mem(addr_idx)), C_SCOPE);
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
      C_DS_ADDR      => C_DS_ADDR,
      C_DS_IS_MEMORY => not INTERNAL_DEFAULT_SLAVE,
      C_MASTER_SEL   => C_MASTER_SEL,
      C_PIPEIN       => PIPEIN,
      C_CLK_PERIOD   => C_CLK_PERIOD,
      C_SCOPE        => C_SCOPE
    );
 end process test_stimulus;

end architecture sim;