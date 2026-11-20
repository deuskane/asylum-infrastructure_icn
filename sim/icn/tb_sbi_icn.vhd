-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: UVVM/SBI self-checking testbench of sbi_icn : 2 masters (SBI
--              VIP), 3 memory targets with wait states, internal or external
--              default slave.
--              TESTS_LIST : scenarios run in sequence, separated by ','
--                           (tb_sbi_icn_tests_pkg), each one after a reset
--                           pulse ; "" : build and elaboration only
--              The other generics select the configuration of the DUT and
--              the wait states of the targets.
--              Monitors (every scenario, every cycle) : a master gets ready
--              only when it requests, at most one master gets ready and at
--              most one target port is selected in a cycle, a target sees
--              its local address only.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created
-- 2026-10-05  1.1      mrosiere Add PIPEIN / PIPEOUT generics (sbi_pipe coverage)
-- 2026-11-20  2.0      mrosiere TESTS_LIST, one package per scenario,
--                               reset pulse before each scenario, cke_i
--                               driven by the scenarios, target monitors
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;
use     asylum.string_pkg.all;

library work;
use     work.tb_sbi_icn_bfm_pkg.all;
use     work.tb_sbi_icn_tests_pkg.all;

entity tb_sbi_icn is
  generic (
    TESTS_LIST             : string  := ""          -- Scenarios, e.g. "simple,latency"
   ;MASTER_SEL             : string  := "fix"       -- "fix" / "roundrobin"
   ;TARGET_SEL             : string  := "or"        -- "or" / "mux"
   ;TARGET_ADDR_ENCODING   : string  := "binary"    -- "binary" / "one_hot"
   ;INTERNAL_DEFAULT_SLAVE : boolean := false       -- false : the default slave is a memory model on the last target port
   ;WAIT_STATES            : natural := 2           -- Target i answers after WAIT_STATES*i cycles
   ;PIPEIN                 : boolean := false       -- true : sbi_pipe stage on every master port (PIPEIN_ENABLE  = '1')
   ;PIPEOUT                : boolean := false       -- true : sbi_pipe stage on every target port (PIPEOUT_ENABLE = all '1')
  );
end entity tb_sbi_icn;

architecture sim of tb_sbi_icn is

  constant C_SCOPE        : string   := "TB_SBI_ICN";

  -- 3 memory targets, plus the external default slave (memory model on the whole address range)
  constant C_NB_TARGET    : positive := C_NB_MEM + 1 - boolean'pos(INTERNAL_DEFAULT_SLAVE);

  -- Address map
  -- binary  : 2 MSBs for target ID, 6 bits of local address space
  --           Target 0: 0x00 to 0x3F, Target 1: 0x40 to 0x7F, Target 2: 0x80 to 0xBF, unmapped: 0xC0 to 0xFF
  -- one_hot : select bits 5, 6 and 7, 5 bits of local address space
  --           Target 0: 0x20 to 0x3F, Target 1: 0x40 to 0x5F, Target 2: 0x80 to 0x9F, unmapped: 0x00 to 0x1F
  -- External default slave (last target) : ID 0, full address width
  function tb_cfg return t_tb_cfg is
    variable res : t_tb_cfg;
  begin
    res.nb_target    := C_NB_TARGET;
    res.id           := (others => (others => '0'));
    res.width        := (others => SBI_ADDR_WIDTH);
    res.ds_is_memory := not INTERNAL_DEFAULT_SLAVE;
    res.roundrobin   := MASTER_SEL = "roundrobin";
    res.pipein       := PIPEIN;
    res.pipeout      := PIPEOUT;
    for t in 0 to C_NB_MEM-1 loop
      if TARGET_ADDR_ENCODING = "one_hot"
      then
        res.id   (t) := std_logic_vector(to_unsigned(2**(5+t), SBI_ADDR_WIDTH));
        res.width(t) := 5;
      else
        res.id   (t) := std_logic_vector(to_unsigned(64*t    , SBI_ADDR_WIDTH));
        res.width(t) := 6;
      end if;
    end loop;
    for t in 0 to C_MAX_TARGET-1 loop
      res.wait_states(t) := WAIT_STATES*t;
    end loop;
    if TARGET_ADDR_ENCODING = "one_hot"
    then
      res.ds_addr := (x"00", x"1F");
    else
      res.ds_addr := (x"C0", x"FF");
    end if;
    return res;
  end function tb_cfg;

  constant C_CFG          : t_tb_cfg := tb_cfg;

  function to_sl (b : boolean) return std_logic is
  begin
    if b then return '1'; else return '0'; end if;
  end function to_sl;

  constant C_TARGET_ID         : sbi_addrs_t(0 to C_NB_TARGET-1) := C_CFG.id(0 to C_NB_TARGET-1);
  constant C_TARGET_ADDR_WIDTH : naturals_t (0 to C_NB_TARGET-1) := C_CFG.width(0 to C_NB_TARGET-1);

  signal   clk_i          : std_logic := '0';
  signal   clk_ena        : boolean   := true;
  signal   cke_i          : std_logic := '1';
  signal   arst_b_i       : std_logic := '0';

  -- SBI ports of the DUT
  signal   sbi_inis_i     : sbi_inis_t (C_NB_MASTER-1 downto 0)(addr (SBI_ADDR_WIDTH-1 downto 0),
                                                                wdata(SBI_DATA_WIDTH-1 downto 0));
  signal   sbi_tgts_o     : sbi_tgts_t (C_NB_MASTER-1 downto 0)(rdata(SBI_DATA_WIDTH-1 downto 0));
  signal   sbi_inis_o     : sbi_inis_t (C_NB_TARGET-1 downto 0)(addr (SBI_ADDR_WIDTH-1 downto 0),
                                                                wdata(SBI_DATA_WIDTH-1 downto 0));
  signal   sbi_tgts_i     : sbi_tgts_t (C_NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH-1 downto 0));

  -- UVVM SBI interface of each master
  signal   sbi_ifs        : t_sbi_if_array(0 to C_NB_MASTER-1) := (others => init_sbi_if_signals(SBI_ADDR_WIDTH, SBI_DATA_WIDTH));

begin

  clock_generator(clk_i, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : sbi_icn
    generic map
    (NAME                   => "sbi_icn_tb"
    ,NB_MASTER              => C_NB_MASTER
    ,MASTER_SEL             => MASTER_SEL
    ,NB_TARGET              => C_NB_TARGET
    ,TARGET_SEL             => TARGET_SEL
    ,TARGET_ID              => C_TARGET_ID
    ,TARGET_ADDR_WIDTH      => C_TARGET_ADDR_WIDTH
    ,TARGET_ADDR_ENCODING   => TARGET_ADDR_ENCODING
    ,INTERNAL_DEFAULT_SLAVE => INTERNAL_DEFAULT_SLAVE
    ,PIPEOUT_ENABLE         => (C_NB_TARGET-1 downto 0 => to_sl(PIPEOUT))
    ,PIPEIN_ENABLE          => to_sl(PIPEIN)
    )
    port map
    (clk_i                  => clk_i
    ,cke_i                  => cke_i
    ,arst_b_i               => arst_b_i
    ,sbi_inis_i             => sbi_inis_i
    ,sbi_tgts_o             => sbi_tgts_o
    ,sbi_inis_o             => sbi_inis_o
    ,sbi_tgts_i             => sbi_tgts_i
    );

  gen_master_if: for m in 0 to C_NB_MASTER-1
  generate
    sbi_inis_i(m).cs    <= sbi_ifs(m).cs;
    sbi_inis_i(m).addr  <= std_logic_vector(sbi_ifs(m).addr);
    sbi_inis_i(m).re    <= sbi_ifs(m).rena;
    sbi_inis_i(m).we    <= sbi_ifs(m).wena;
    sbi_inis_i(m).wdata <= sbi_ifs(m).wdata;
    sbi_ifs(m).ready    <= sbi_tgts_o(m).ready;
    sbi_ifs(m).rdata    <= sbi_tgts_o(m).rdata;
  end generate gen_master_if;

  -----------------------------------------------------------------------------
  -- Monitors : at most one master gets ready in a cycle, and only a master
  -- with a pending request ; at most one target port is selected
  -----------------------------------------------------------------------------
  p_monitor : process (clk_i)
    variable v_nb_ready : natural;
    variable v_nb_cs    : natural;
  begin
    if rising_edge(clk_i) and arst_b_i = '1'
    then
      v_nb_ready := 0;
      for m in 0 to C_NB_MASTER-1 loop
        check_value(not is_x(sbi_tgts_o(m).ready), error, "Master " & integer'image(m) & " : ready not X", C_SCOPE, msg_id => ID_NEVER);
        if sbi_tgts_o(m).ready = '1'
        then
          v_nb_ready := v_nb_ready + 1;
          check_value(sbi_inis_i(m).cs = '1', error, "Master " & integer'image(m) & " got ready without request", C_SCOPE, msg_id => ID_NEVER);
        end if;
      end loop;
      check_value(v_nb_ready <= 1, error, "Several masters got ready in the same cycle", C_SCOPE, msg_id => ID_NEVER);

      v_nb_cs := 0;
      for t in 0 to C_NB_TARGET-1 loop
        check_value(not is_x(sbi_inis_o(t).cs), error, "Target " & integer'image(t) & " : cs not X", C_SCOPE, msg_id => ID_NEVER);
        if sbi_inis_o(t).cs = '1'
        then
          v_nb_cs := v_nb_cs + 1;
        end if;
      end loop;
      check_value(v_nb_cs <= 1, error, "Several target ports selected in the same cycle", C_SCOPE, msg_id => ID_NEVER);
    end if;
  end process p_monitor;

  -----------------------------------------------------------------------------
  -- Targets
  -- Memory model answering after wait_states(i) cycles. Out of an access it
  -- drives ready = 1 and rdata = 0xFF (as the generated CSR blocks do), and
  -- during the wait states it drives wrong data : the interconnect must
  -- ignore ("mux") or zero ("or") the responses of the targets not selected.
  -- The address of an access must be the local address of the target, and
  -- an access is either a read or a write. The memory is not reset : a
  -- scenario writes what it reads.
  -----------------------------------------------------------------------------
  gen_target: for i in 0 to C_NB_TARGET-1
  generate
    constant C_AW   : natural := C_TARGET_ADDR_WIDTH(i);
    constant C_WAIT : natural := C_CFG.wait_states(i);
    type     mem_t is array (0 to 2**C_AW-1) of std_logic_vector(SBI_DATA_WIDTH-1 downto 0);
    signal   mem      : mem_t := (others => (others => '0'));
    signal   addr_idx : natural range 0 to 2**C_AW-1;
    signal   wait_cnt : natural range 0 to C_WAIT := 0;
    signal   ack      : std_logic;
  begin
    addr_idx            <= to_integer(unsigned(sbi_inis_o(i).addr(C_AW-1 downto 0)));
    ack                 <= sbi_inis_o(i).cs when wait_cnt = C_WAIT else '0';

    sbi_tgts_i(i).ready <= ack                when sbi_inis_o(i).cs = '1' else '1';
    sbi_tgts_i(i).rdata <= mem(addr_idx)      when ack              = '1' else
                           not mem(addr_idx)  when sbi_inis_o(i).cs = '1' else
                           (others => '1');
    sbi_tgts_i(i).info.name <= to_sbi_name("target" & integer'image(i));

    p_target : process (clk_i)
    begin
      if rising_edge(clk_i)
      then
        if arst_b_i = '0'
        then
          wait_cnt <= 0;
        elsif cke_i = '1'
        then
          if sbi_inis_o(i).cs = '1'
          then
            check_value(unsigned(sbi_inis_o(i).addr) < 2**C_AW, error, "Target " & integer'image(i) & " : local address", C_SCOPE, msg_id => ID_NEVER);
            check_value((sbi_inis_o(i).re xor sbi_inis_o(i).we) = '1', error, "Target " & integer'image(i) & " : either re or we", C_SCOPE, msg_id => ID_NEVER);
          end if;

          if sbi_inis_o(i).cs = '0' or ack = '1'
          then
            wait_cnt <= 0;
          else
            wait_cnt <= wait_cnt + 1;
          end if;

          if ack = '1' and sbi_inis_o(i).we = '1'
          then
            mem(addr_idx) <= sbi_inis_o(i).wdata;
          end if;
        end if;
      end if;
    end process p_target;
  end generate gen_target;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_sequencer : process
  begin
    log(ID_LOG_HDR, "MASTER_SEL = " & MASTER_SEL & ", TARGET_SEL = " & TARGET_SEL &
                    ", TARGET_ADDR_ENCODING = " & TARGET_ADDR_ENCODING &
                    ", INTERNAL_DEFAULT_SLAVE = " & boolean'image(INTERNAL_DEFAULT_SLAVE) &
                    ", WAIT_STATES = " & integer'image(WAIT_STATES) &
                    ", PIPEIN = " & boolean'image(PIPEIN) & ", PIPEOUT = " & boolean'image(PIPEOUT) &
                    ", TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      elsif not test_applies(list_item(TESTS_LIST, i), C_CFG)
      then
        alert(TB_ERROR, "Test """ & list_item(TESTS_LIST, i) & """ does not apply to this configuration", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Reset pulse, masters idle, clock enabled : each scenario starts from reset
      sbi_ifs <= (others => init_sbi_if_signals(SBI_ADDR_WIDTH, SBI_DATA_WIDTH));
      cke_i   <= '1';
      do_reset(clk_i, arst_b_i);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), C_CFG, clk_i, cke_i, arst_b_i, sbi_ifs);
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_sequencer;

end architecture sim;
