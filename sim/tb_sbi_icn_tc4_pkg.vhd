-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_tc4_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Test Case 4 for SBI Interconnect Testbench: Arbitration
--              The masters are driven concurrently (same process, cycle by
--              cycle) and the order of the completed accesses is checked
--              against MASTER_SEL ("fix" / "roundrobin")
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-10-17  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.sbi_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_tc4_pkg is
  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_MASTER_SEL : in  string;
    constant C_PIPEIN     : in  boolean;
    constant C_SCOPE      : in  string
  );
end package tb_sbi_icn_tc4_pkg;

package body tb_sbi_icn_tc4_pkg is

  constant C_MAX_ACCESS : positive := 8;   -- Accesses per master in one sequence
  constant C_TIMEOUT    : positive := 100; -- Max cycles without any completed access

  -- One access: write data, or expected read data
  type t_access is record
    we   : std_logic;
    addr : unsigned        (SBI_ADDR_WIDTH-1 downto 0);
    data : std_logic_vector(SBI_DATA_WIDTH-1 downto 0);
  end record t_access;

  type t_access_list  is array (0 to C_MAX_ACCESS-1) of t_access;
  type t_access_lists is array (natural range <>)    of t_access_list;
  type t_order        is array (0 to 2*C_MAX_ACCESS-1) of integer;

  -- Run the access lists of the 2 masters concurrently: each master keeps cs asserted and
  -- issues its next access just after the previous one has completed (back-to-back).
  -- Read data are checked, order returns the master of each completed access.
  procedure run_concurrent (
    signal   clk_i   : in    std_logic;
    signal   sbi_ifs : inout t_sbi_if_array;
    constant lists   : in    t_access_lists(0 to 1);
    constant nb      : in    naturals_t(0 to 1);
    variable order   : out   t_order;
    constant msg     : in    string;
    constant C_SCOPE : in    string
  ) is
    variable v_idx  : naturals_t(0 to 1) := (others => 0);
    variable v_cnt  : natural := 0;
    variable v_wait : natural := 0;
    variable v_acc  : t_access;
  begin
    order := (others => -1);
    loop
      -- Drive the pending access of each master
      wait until falling_edge(clk_i);
      for m in 0 to 1 loop
        if v_idx(m) < nb(m) then
          v_acc := lists(m)(v_idx(m));
          sbi_ifs(m).cs    <= '1';
          sbi_ifs(m).wena  <= v_acc.we;
          sbi_ifs(m).rena  <= not v_acc.we;
          sbi_ifs(m).addr  <= v_acc.addr;
          if v_acc.we = '1' then
            sbi_ifs(m).wdata <= v_acc.data;
          else
            sbi_ifs(m).wdata <= (others => '0');
          end if;
        else
          sbi_ifs(m).cs    <= '0';
          sbi_ifs(m).wena  <= '0';
          sbi_ifs(m).rena  <= '0';
          sbi_ifs(m).addr  <= (others => '0');
          sbi_ifs(m).wdata <= (others => '0');
        end if;
      end loop;

      exit when v_idx(0) = nb(0) and v_idx(1) = nb(1);

      -- Sample the responses
      wait until rising_edge(clk_i);
      v_wait := v_wait + 1;
      for m in 0 to 1 loop
        if v_idx(m) < nb(m) and sbi_ifs(m).ready = '1' then
          v_acc := lists(m)(v_idx(m));
          if v_acc.we = '0' then
            check_value(sbi_ifs(m).rdata, v_acc.data, ERROR, msg & ": M" & integer'image(m) & " read @" & to_hstring(v_acc.addr), C_SCOPE, msg_id => ID_NEVER);
          end if;
          order(v_cnt) := m;
          v_cnt        := v_cnt    + 1;
          v_idx(m)     := v_idx(m) + 1;
          v_wait       := 0;
        end if;
      end loop;

      if v_wait > C_TIMEOUT then
        alert(ERROR, msg & ": timeout, M0 " & integer'image(v_idx(0)) & "/" & integer'image(nb(0)) &
                                   " M1 " & integer'image(v_idx(1)) & "/" & integer'image(nb(1)) & " accesses done", C_SCOPE);
        exit;
      end if;
    end loop;
  end procedure run_concurrent;

  -- "M0 M1 ..." : master of each completed access
  function order_image (order : t_order) return string is
    variable res : string(1 to 3*order'length) := (others => ' ');
    variable n   : natural := 0;
  begin
    for j in order'range loop
      exit when order(j) < 0;
      res(n+1 to n+2) := "M" & character'val(character'pos('0') + order(j));
      n := n + 3;
    end loop;
    return res(1 to n);
  end function order_image;

  procedure run_test_case (
    signal clk_i          : in  std_logic;
    signal sbi_ifs        : inout t_sbi_if_array;
    constant C_NB_MASTER  : in  positive;
    constant C_TARGET_ID  : in  sbi_addrs_t;
    constant C_MASTER_SEL : in  string;
    constant C_PIPEIN     : in  boolean;
    constant C_SCOPE      : in  string
  ) is
    variable v_lists : t_access_lists(0 to 1);
    variable v_order : t_order;
    variable v_first : integer;

    function wr (tgt : natural; offset : natural; data : natural) return t_access is
    begin
      return (we => '1', addr => unsigned(C_TARGET_ID(tgt)) + offset, data => std_logic_vector(to_unsigned(data, SBI_DATA_WIDTH)));
    end function wr;

    function rd (tgt : natural; offset : natural; data : natural) return t_access is
    begin
      return (we => '0', addr => unsigned(C_TARGET_ID(tgt)) + offset, data => std_logic_vector(to_unsigned(data, SBI_DATA_WIDTH)));
    end function rd;

  begin
    log(ID_LOG_HDR, "Test Case 4: Arbitration (" & C_MASTER_SEL & ")", C_SCOPE);

    if C_NB_MASTER < 2 then
      log(ID_SEQUENCER, "Only one master: no arbitration to test", C_SCOPE);
      return;
    end if;

    ---------------------------------------------------------------------------
    -- Simultaneous requests
    ---------------------------------------------------------------------------
    -- M0 alone (round robin: M1 has the priority afterwards)
    v_lists(0)(0) := wr(0, 5, 16#5A#);
    run_concurrent(clk_i, sbi_ifs, v_lists, (1, 0), v_order, "M0 alone", C_SCOPE);

    -- M0 and M1 request in the same cycle: "fix" grants M0 first, "roundrobin" grants M1 first
    v_lists(0)(0) := wr(1, 16, 16#11#);
    v_lists(1)(0) := wr(2, 16, 16#22#);
    run_concurrent(clk_i, sbi_ifs, v_lists, (1, 1), v_order, "Simultaneous writes", C_SCOPE);
    if C_MASTER_SEL = "fix" then v_first := 0; else v_first := 1; end if;
    log(ID_SEQUENCER, "Simultaneous writes, completion order: " & order_image(v_order), C_SCOPE);
    check_value(v_order(0), v_first, ERROR, "Simultaneous writes: first granted master", C_SCOPE, msg_id => ID_NEVER);
    check_value(v_order(1), 1-v_first, ERROR, "Simultaneous writes: second granted master", C_SCOPE, msg_id => ID_NEVER);

    -- M1 alone (round robin: M0 has the priority afterwards)
    v_lists(1)(0) := wr(0, 6, 16#66#);
    run_concurrent(clk_i, sbi_ifs, v_lists, (0, 1), v_order, "M1 alone", C_SCOPE);

    -- M0 and M1 read in the same cycle the data written by the other one: M0 first in both modes
    v_lists(0)(0) := rd(2, 16, 16#22#);
    v_lists(1)(0) := rd(1, 16, 16#11#);
    run_concurrent(clk_i, sbi_ifs, v_lists, (1, 1), v_order, "Simultaneous reads", C_SCOPE);
    log(ID_SEQUENCER, "Simultaneous reads, completion order: " & order_image(v_order), C_SCOPE);
    check_value(v_order(0), 0, ERROR, "Simultaneous reads: first granted master", C_SCOPE, msg_id => ID_NEVER);
    check_value(v_order(1), 1, ERROR, "Simultaneous reads: second granted master", C_SCOPE, msg_id => ID_NEVER);

    ---------------------------------------------------------------------------
    -- Sustained contention: back-to-back accesses of both masters
    -- Writes : M0 to target 1, M1 to target 2 (different wait states)
    -- Reads  : each master reads back the data written by the other one
    ---------------------------------------------------------------------------
    for phase in 0 to 1 loop
      for k in 0 to C_MAX_ACCESS-1 loop
        if phase = 0 then
          v_lists(0)(k) := wr(1, 8+k, 16#A0#+k);
          v_lists(1)(k) := wr(2, 8+k, 16#B0#+k);
        else
          v_lists(0)(k) := rd(2, 8+k, 16#B0#+k);
          v_lists(1)(k) := rd(1, 8+k, 16#A0#+k);
        end if;
      end loop;
      run_concurrent(clk_i, sbi_ifs, v_lists, (C_MAX_ACCESS, C_MAX_ACCESS), v_order, "Sustained contention " & integer'image(phase), C_SCOPE);
      log(ID_SEQUENCER, "Sustained contention " & integer'image(phase) & ", completion order: " & order_image(v_order), C_SCOPE);

      if C_MASTER_SEL = "roundrobin" then
        -- Masters served alternately
        for j in 1 to 2*C_MAX_ACCESS-1 loop
          check_value(v_order(j) /= v_order(j-1), ERROR, "Round robin: access " & integer'image(j) & " granted twice in a row to M" & integer'image(v_order(j)), C_SCOPE, msg_id => ID_NEVER);
        end loop;
      else
        check_value(v_order(0), 0, ERROR, "Fixed priority: first granted master", C_SCOPE, msg_id => ID_NEVER);
        -- Without input pipe, M0 requests again in the cycle following its completion and keeps the bus
        -- (with an input pipe, its request drops for a few cycles and M1 is granted in between)
        if not C_PIPEIN then
          for j in 0 to C_MAX_ACCESS-1 loop
            check_value(v_order(j), 0, ERROR, "Fixed priority: M0 keeps the bus while it requests (access " & integer'image(j) & ")", C_SCOPE, msg_id => ID_NEVER);
          end loop;
        end if;
      end if;
    end loop;

  end procedure run_test_case;
end package body tb_sbi_icn_tc4_pkg;
