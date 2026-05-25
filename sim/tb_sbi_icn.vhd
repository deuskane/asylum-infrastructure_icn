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

  -- Clock and Reset
  constant C_CLK_PERIOD   : time := 10 ns;
  signal   clk_i          : std_logic := '0';
  signal   cke_i          : std_logic := '1';
  signal   arst_b_i       : std_logic := '0'; -- Active low reset

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
  signal sbi_ini_i        : sbi_ini_t(addr (SBI_ADDR_WIDTH-1 downto 0),
                                      wdata(SBI_DATA_WIDTH-1 downto 0));
  signal sbi_tgt_o        : sbi_tgt_t(rdata(SBI_DATA_WIDTH-1 downto 0));
  signal sbi_inis_o       : sbi_inis_t (C_NB_TARGET-1 downto 0)(addr (SBI_ADDR_WIDTH-1 downto 0),
                                                                wdata(SBI_DATA_WIDTH-1 downto 0));
  signal sbi_tgts_i       : sbi_tgts_t (C_NB_TARGET-1 downto 0)(rdata(SBI_DATA_WIDTH-1 downto 0));

  -- UVVM SBI Interface
  signal sbi_if           : t_sbi_if(addr (SBI_ADDR_WIDTH-1 downto 0), 
                                     wdata(SBI_DATA_WIDTH-1 downto 0), 
                                     rdata(SBI_DATA_WIDTH-1 downto 0))
                          := (ready => 'Z', 
                              rdata => (others => 'Z'),
                              cs    => 'Z',
                              rena  => 'Z',
                              wena  => 'Z',
                              wdata => (others => 'Z'),
                              addr  => (others => 'Z'));


  -- Function to convert integer to std_logic_vector (assuming not in convert_pkg or numeric_std directly as to_slv)
  function to_slv (val : natural; size : natural) return std_logic_vector is
    variable res : std_logic_vector(size-1 downto 0);
  begin
    res := std_logic_vector(to_unsigned(val, size));
    return res;
  end function to_slv;

begin

  -- Instantiate the Unit Under Test (UUT)
  dut : sbi_icn
    generic map (
      NAME                 => "sbi_icn_tb",
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
      sbi_ini_i => sbi_ini_i,
      sbi_tgt_o => sbi_tgt_o,
      sbi_inis_o => sbi_inis_o,
      sbi_tgts_i => sbi_tgts_i
    );

  -- Mapping UVVM SBI IF to Asylum SBI Ports
  sbi_ini_i.cs    <= sbi_if.cs;
  sbi_ini_i.addr  <= std_logic_vector(sbi_if.addr);
  sbi_ini_i.re    <= sbi_if.rena;
  sbi_ini_i.we    <= sbi_if.wena;
  sbi_ini_i.wdata <= sbi_if.wdata;
  sbi_if.ready    <= sbi_tgt_o.ready;
  sbi_if.rdata    <= sbi_tgt_o.rdata;

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
  begin
    -- Initialisation des logs UVVM
    --set_log_filter_all(set_256 => (others => '1'));
    -- Print the configuration to the log
    report_global_ctrl (VOID);
    report_msg_id_panel(VOID);

    enable_log_msg     (ALL_MESSAGES);

    sbi_if.cs  <= '0';
    sbi_if.addr <= (others => '0');
    sbi_if.wena <= '0';
    sbi_if.rena <= '0';
    sbi_if.wdata <= (others => '0');

    wait until arst_b_i = '1'; -- Wait for reset to de-assert
    wait for C_CLK_PERIOD;
    log(ID_LOG_HDR, "Simulation Started", C_SCOPE);

    ---------------------------------------------------------------------------
    -- Test Case 1: Simple access to each target
    ---------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test Case 1: Simple access to each target", C_SCOPE);

    -- Target 0 (base address 0x00)
    sbi_write(addr_value => x"00", data_value => x"A5", msg => "Write T0",          clk => clk_i, sbi_if => sbi_if);
    sbi_check(addr_value => x"00", data_exp   => x"A5", msg => "Check T0",          clk => clk_i, sbi_if => sbi_if);
    sbi_write(addr_value => x"01", data_value => x"5A", msg => "Write T0 offset 1", clk => clk_i, sbi_if => sbi_if); 
    sbi_check(addr_value => x"01", data_exp   => x"5A", msg => "Check T0 offset 1", clk => clk_i, sbi_if => sbi_if);

    -- Target 1 (base address 0x40)
    sbi_write(addr_value => x"40", data_value => x"12", msg => "Write T1",          clk => clk_i, sbi_if => sbi_if);
    sbi_check(addr_value => x"40", data_exp   => x"12", msg => "Check T1",          clk => clk_i, sbi_if => sbi_if);
    sbi_write(addr_value => x"42", data_value => x"34", msg => "Write T1 offset 2", clk => clk_i, sbi_if => sbi_if); 
    sbi_check(addr_value => x"42", data_exp   => x"34", msg => "Check T1 offset 2", clk => clk_i, sbi_if => sbi_if);

    -- Target 2 (base address 0x80)
    sbi_write(addr_value => x"80", data_value => x"FF", msg => "Write T2",          clk => clk_i, sbi_if => sbi_if);
    sbi_check(addr_value => x"80", data_exp   => x"FF", msg => "Check T2",          clk => clk_i, sbi_if => sbi_if);
    sbi_write(addr_value => x"83", data_value => x"00", msg => "Write T2 offset 3", clk => clk_i, sbi_if => sbi_if); 
    sbi_check(addr_value => x"83", data_exp   => x"00", msg => "Check T2 offset 3", clk => clk_i, sbi_if => sbi_if);

    ---------------------------------------------------------------------------
    -- Test Case 2: Access to default slave
    ---------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test Case 2: Access to default slave", C_SCOPE);
 
    -- Address 0xC0 should go to default slave (since targets only go up to 0xBF)
    -- Default slave typically returns all zeros for reads and ignores writes.
    sbi_write(addr_value => x"C0", data_value => x"EE", msg => "Write to default slave", clk => clk_i, sbi_if => sbi_if); 
    sbi_check(addr_value => x"C0", data_exp   => x"00", msg => "Check default slave",    clk => clk_i, sbi_if => sbi_if); 
    sbi_check(addr_value => x"FF", data_exp   => x"00", msg => "Check unmapped top addr",clk => clk_i, sbi_if => sbi_if); 

    ---------------------------------------------------------------------------
    -- Test Case 3: Exhaustive access (more comprehensive)
    ---------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test Case 3: Exhaustive access (more comprehensive)", C_SCOPE);

    -- Write and read multiple locations for Target 0
    for i in 0 to C_TARGET_MEM_SIZE(0) - 1 loop
      sbi_write(addr_value => unsigned(C_TARGET_ID(0)) + i, data_value => to_slv(i + 1, SBI_DATA_WIDTH), msg => "Exhaustive write T0", clk => clk_i, sbi_if => sbi_if);
    end loop;
    for i in 0 to C_TARGET_MEM_SIZE(0) - 1 loop
      sbi_check(addr_value => unsigned(C_TARGET_ID(0)) + i, data_exp => to_slv(i + 1, SBI_DATA_WIDTH), msg => "Exhaustive check T0", clk => clk_i, sbi_if => sbi_if);
    end loop;

    -- Write and read multiple locations for Target 1
    for i in 0 to C_TARGET_MEM_SIZE(1) - 1 loop
      sbi_write(addr_value => unsigned(C_TARGET_ID(1)) + i, data_value => to_slv(i + 10, SBI_DATA_WIDTH), msg => "Exhaustive write T1", clk => clk_i, sbi_if => sbi_if);
    end loop;
    for i in 0 to C_TARGET_MEM_SIZE(1) - 1 loop
      sbi_check(addr_value => unsigned(C_TARGET_ID(1)) + i, data_exp => to_slv(i + 10, SBI_DATA_WIDTH), msg => "Exhaustive check T1", clk => clk_i, sbi_if => sbi_if);
    end loop;

    -- Test sequential bursts to different targets
    log(ID_SEQUENCER, "Testing sequential bursts to different targets", C_SCOPE);
    sbi_write(addr_value => unsigned(C_TARGET_ID(0)) + unsigned'(x"00"), data_value => x"AA", msg => "Burst write T0", clk => clk_i, sbi_if => sbi_if);
    sbi_write(addr_value => unsigned(C_TARGET_ID(1)) + unsigned'(x"00"), data_value => x"BB", msg => "Burst write T1", clk => clk_i, sbi_if => sbi_if);
    sbi_check(addr_value => unsigned(C_TARGET_ID(0)) + unsigned'(x"00"), data_exp => x"AA", msg => "Burst check T0", clk => clk_i, sbi_if => sbi_if);
    sbi_check(addr_value => unsigned(C_TARGET_ID(1)) + unsigned'(x"00"), data_exp => x"BB", msg => "Burst check T1", clk => clk_i, sbi_if => sbi_if);

    log(ID_LOG_HDR, "Simulation Finished. All tests passed.", C_SCOPE);
    report_alert_counters(FINAL);      -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    -- Finish the simulation
    std.env.stop;
 end process test_stimulus;

end architecture sim;