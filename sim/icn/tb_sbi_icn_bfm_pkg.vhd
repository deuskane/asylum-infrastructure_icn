-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_sbi_icn_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-------------------------------------------------------------------------------
-- Description: Helpers of the tb_sbi_icn scenarios : configuration of the
--              bench (address map, wait states, options of the DUT), SBI
--              accesses of a master (SBI VIP), accesses driven cycle by cycle
--              (latency, concurrent masters), checks, reset pulse.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created (tb_sbi_icn_pkg)
-- 2026-11-20  2.0      mrosiere Helpers of the scenarios (configuration
--                               record, wr / chk, cycle accesses, reset)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

package tb_sbi_icn_bfm_pkg is

  constant C_TB_SCOPE   : string   := "TB_SBI_ICN_BFM";
  constant C_CLK_PERIOD : time     := 10 ns;
  constant C_NB_MASTER  : positive := 2;            -- Masters of the bench
  constant C_NB_MEM     : positive := 3;            -- Memory targets (0x00, 0x40, 0x80 or 0x20, 0x40, 0x80)
  constant C_MAX_TARGET : positive := C_NB_MEM + 1; -- With the external default slave
  constant C_TIMEOUT    : positive := 100;          -- Max cycles of an access driven cycle by cycle

  subtype  byte_t is std_logic_vector(SBI_DATA_WIDTH-1 downto 0);

  -- UVVM SBI interface of a master, constrained with the SBI widths
  subtype  t_sbi_if_constrained is t_sbi_if(addr  (SBI_ADDR_WIDTH-1 downto 0),
                                            wdata (SBI_DATA_WIDTH-1 downto 0),
                                            rdata (SBI_DATA_WIDTH-1 downto 0));
  type     t_sbi_if_array is array (integer range <>) of t_sbi_if_constrained;

  -- Configuration of the bench, computed from the generics of tb_sbi_icn
  type t_tb_cfg is record
    nb_target    : positive;                          -- Target ports of the DUT
    id           : sbi_addrs_t(0 to C_MAX_TARGET-1);  -- Base address of each target port
    width        : naturals_t (0 to C_MAX_TARGET-1);  -- Local address width of each target port (memory model of 2**width bytes)
    wait_states  : naturals_t (0 to C_MAX_TARGET-1);  -- Wait states of each target port
    ds_addr      : sbi_addrs_t(0 to 1);               -- Two unmapped addresses (default slave)
    ds_is_memory : boolean;                           -- External default slave : memory model on the last target port
    roundrobin   : boolean;                           -- MASTER_SEL = "roundrobin" (else "fix")
    pipein       : boolean;                           -- sbi_pipe on every master port
    pipeout      : boolean;                           -- sbi_pipe on every target port
  end record t_tb_cfg;

  -- Waits of the masters bounded (target 3 of sim_soc : 6 wait states)
  constant C_SBI_CFG : t_sbi_bfm_config := (
    max_wait_cycles            => 20,
    max_wait_cycles_severity   => error,
    use_fixed_wait_cycles_read => false,
    fixed_wait_cycles_read     => 0,
    clock_period               => -1 ns,
    clock_period_margin        => 0 ns,
    clock_margin_severity      => TB_ERROR,
    setup_time                 => -1 ns,
    hold_time                  => -1 ns,
    bfm_sync                   => SYNC_ON_CLOCK_ONLY,
    match_strictness           => MATCH_EXACT,
    id_for_bfm                 => ID_BFM,
    id_for_bfm_wait            => ID_BFM_WAIT,
    id_for_bfm_poll            => ID_BFM_POLL,
    use_ready_signal           => true
  );

  -- One access : write data, or expected read data
  type t_access is record
    we   : std_logic;
    addr : unsigned(SBI_ADDR_WIDTH-1 downto 0);
    data : byte_t;
  end record t_access;

  constant C_MAX_ACCESS : positive := 8;  -- Accesses per master in run_concurrent

  type t_access_list  is array (0 to C_MAX_ACCESS-1)   of t_access;
  type t_access_lists is array (0 to C_NB_MASTER-1)    of t_access_list;
  type t_grants        is array (0 to 2*C_MAX_ACCESS-1) of integer;

  -- Address offset of the target port t
  function taddr
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ) return unsigned;

  -- Write access, read access (expected data) of the target port t
  function wr_acc
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ;constant data     : in    natural
    ) return t_access;

  function rd_acc
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ;constant data     : in    natural
    ) return t_access;

  -- SBI write of master m
  procedure wr
    (constant m        : in    natural
    ;constant addr     : in    unsigned
    ;constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  -- SBI read of master m and check
  procedure chk
    (constant m        : in    natural
    ;constant addr     : in    unsigned
    ;constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  -- Checks
  procedure chk_int
    (constant val      : in    integer
    ;constant exp      : in    integer
    ;constant msg      : in    string
    );

  procedure chk_true
    (constant val      : in    boolean
    ;constant msg      : in    string
    );

  -- Request of master m driven (acc) or released (idle), on the current delta
  procedure drive
    (constant m        : in    natural
    ;constant acc      : in    t_access
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  procedure idle
    (constant m        : in    natural
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  -- Access of master m driven on a falling edge, kept until ready : number of
  -- rising edges from the request to ready (C_TIMEOUT+1 without ready),
  -- request released on the next falling edge
  procedure access_cycles
    (constant m        : in    natural
    ;constant acc      : in    t_access
    ;variable cnt      : out   natural
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  -- Access lists of the 2 masters run concurrently : each master issues its
  -- next access in the cycle after the completion of the previous one
  -- (back-to-back). Read data checked, order : master of each completed access
  procedure run_concurrent
    (constant lists    : in    t_access_lists
    ;constant nb       : in    naturals_t
    ;variable order    : out   t_grants
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    );

  -- "M0 M1 ..." : master of each completed access
  function order_image
    (constant order    : in    t_grants
    ) return string;

  -- Wait n rising edges
  procedure cycles
    (constant n        : in    natural
    ;signal   clk      : in    std_logic
    );

  -- Reset pulse, released on a falling edge
  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    );

end package tb_sbi_icn_bfm_pkg;

package body tb_sbi_icn_bfm_pkg is

  function taddr
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ) return unsigned is
  begin
    return unsigned(cfg.id(t)) + offset;
  end function;

  function wr_acc
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ;constant data     : in    natural
    ) return t_access is
  begin
    return (we => '1', addr => taddr(cfg, t, offset), data => std_logic_vector(to_unsigned(data, SBI_DATA_WIDTH)));
  end function;

  function rd_acc
    (constant cfg      : in    t_tb_cfg
    ;constant t        : in    natural
    ;constant offset   : in    natural
    ;constant data     : in    natural
    ) return t_access is
  begin
    return (we => '0', addr => taddr(cfg, t, offset), data => std_logic_vector(to_unsigned(data, SBI_DATA_WIDTH)));
  end function;

  -- The actual of a signal parameter is a static name : one call per master
  procedure wr
    (constant m        : in    natural
    ;constant addr     : in    unsigned
    ;constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    if m = 0
    then
      sbi_write(addr_value => addr
               ,data_value => data
               ,msg        => "M0 " & msg
               ,clk        => clk
               ,sbi_if     => sbi_ifs(0)
               ,scope      => C_TB_SCOPE
               ,config     => C_SBI_CFG
               );
    else
      sbi_write(addr_value => addr
               ,data_value => data
               ,msg        => "M1 " & msg
               ,clk        => clk
               ,sbi_if     => sbi_ifs(1)
               ,scope      => C_TB_SCOPE
               ,config     => C_SBI_CFG
               );
    end if;
  end procedure;

  procedure chk
    (constant m        : in    natural
    ;constant addr     : in    unsigned
    ;constant data     : in    byte_t
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    if m = 0
    then
      sbi_check(addr_value  => addr
               ,data_exp    => data
               ,msg         => "M0 " & msg
               ,clk         => clk
               ,sbi_if      => sbi_ifs(0)
               ,alert_level => error
               ,scope       => C_TB_SCOPE
               ,config      => C_SBI_CFG
               );
    else
      sbi_check(addr_value  => addr
               ,data_exp    => data
               ,msg         => "M1 " & msg
               ,clk         => clk
               ,sbi_if      => sbi_ifs(1)
               ,alert_level => error
               ,scope       => C_TB_SCOPE
               ,config      => C_SBI_CFG
               );
    end if;
  end procedure;

  procedure chk_int
    (constant val      : in    integer
    ;constant exp      : in    integer
    ;constant msg      : in    string
    ) is
  begin
    check_value(val, exp, error, msg, C_TB_SCOPE);
  end procedure;

  procedure chk_true
    (constant val      : in    boolean
    ;constant msg      : in    string
    ) is
  begin
    check_value(val, error, msg, C_TB_SCOPE);
  end procedure;

  procedure drive
    (constant m        : in    natural
    ;constant acc      : in    t_access
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    sbi_ifs(m).cs    <= '1';
    sbi_ifs(m).wena  <= acc.we;
    sbi_ifs(m).rena  <= not acc.we;
    sbi_ifs(m).addr  <= acc.addr;
    if acc.we = '1'
    then
      sbi_ifs(m).wdata <= acc.data;
    else
      sbi_ifs(m).wdata <= (others => '0');
    end if;
  end procedure;

  procedure idle
    (constant m        : in    natural
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    sbi_ifs(m).cs    <= '0';
    sbi_ifs(m).wena  <= '0';
    sbi_ifs(m).rena  <= '0';
    sbi_ifs(m).addr  <= (others => '0');
    sbi_ifs(m).wdata <= (others => '0');
  end procedure;

  procedure access_cycles
    (constant m        : in    natural
    ;constant acc      : in    t_access
    ;variable cnt      : out   natural
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
  begin
    cnt := C_TIMEOUT+1;
    wait until falling_edge(clk);
    drive(m, acc, sbi_ifs);
    for i in 1 to C_TIMEOUT loop
      wait until rising_edge(clk);
      if sbi_ifs(m).ready = '1'
      then
        cnt := i;
        exit;
      end if;
    end loop;
    wait until falling_edge(clk);
    idle(m, sbi_ifs);
  end procedure;

  procedure run_concurrent
    (constant lists    : in    t_access_lists
    ;constant nb       : in    naturals_t
    ;variable order    : out   t_grants
    ;constant msg      : in    string
    ;signal   clk      : in    std_logic
    ;signal   sbi_ifs  : inout t_sbi_if_array
    ) is
    variable v_idx  : naturals_t(0 to C_NB_MASTER-1) := (others => 0);
    variable v_cnt  : natural := 0;
    variable v_wait : natural := 0;
    variable v_acc  : t_access;
  begin
    order := (others => -1);
    loop
      -- Drive the pending access of each master
      wait until falling_edge(clk);
      for m in 0 to C_NB_MASTER-1 loop
        if v_idx(m) < nb(m)
        then
          drive(m, lists(m)(v_idx(m)), sbi_ifs);
        else
          idle (m, sbi_ifs);
        end if;
      end loop;

      exit when v_idx(0) = nb(0) and v_idx(1) = nb(1);

      -- Sample the responses
      wait until rising_edge(clk);
      v_wait := v_wait + 1;
      for m in 0 to C_NB_MASTER-1 loop
        if v_idx(m) < nb(m) and sbi_ifs(m).ready = '1'
        then
          v_acc := lists(m)(v_idx(m));
          if v_acc.we = '0'
          then
            check_value(sbi_ifs(m).rdata, v_acc.data, error, msg & " : M" & integer'image(m) & " read @" & to_hstring(v_acc.addr), C_TB_SCOPE);
          end if;
          order(v_cnt) := m;
          v_cnt        := v_cnt    + 1;
          v_idx(m)     := v_idx(m) + 1;
          v_wait       := 0;
        end if;
      end loop;

      if v_wait > C_TIMEOUT
      then
        alert(error, msg & " : timeout, M0 " & integer'image(v_idx(0)) & "/" & integer'image(nb(0)) &
                                     " M1 " & integer'image(v_idx(1)) & "/" & integer'image(nb(1)) & " accesses done", C_TB_SCOPE);
        exit;
      end if;
    end loop;
  end procedure;

  function order_image
    (constant order    : in    t_grants
    ) return string is
    variable res : string(1 to 3*order'length) := (others => ' ');
    variable n   : natural := 0;
  begin
    for j in order'range loop
      exit when order(j) < 0;
      res(n+1 to n+2) := "M" & character'val(character'pos('0') + order(j));
      n := n + 3;
    end loop;
    return res(1 to n);
  end function;

  procedure cycles
    (constant n        : in    natural
    ;signal   clk      : in    std_logic
    ) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure;

  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   arst_b   : out   std_logic
    ) is
  begin
    arst_b <= '0';
    wait for 10*C_CLK_PERIOD;
    wait until falling_edge(clk);
    arst_b <= '1';
    wait until rising_edge(clk);
  end procedure;

end package body tb_sbi_icn_bfm_pkg;
