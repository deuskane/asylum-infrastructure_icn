-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_tc5_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Test Case 5 for SBI Interconnect Testbench: aborted transfer
--              The granted master releases cs before ready (protocol
--              violation, e.g. a CPU reset while blocked on a stalled
--              target): the interconnect must release the bus, so that the
--              other master is not locked out.
--              Needs 2 masters, a target with wait states (to abort before
--              its ready) and no sbi_pipe on the master ports (it would hold
--              the request): skipped otherwise.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-17  1.0      mrosiere Created
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

library work;
use     work.tb_sbi_icn_pkg.all;

package tb_sbi_icn_tc5_pkg is
  procedure run_test_case (
    signal clk_i           : in  std_logic;
    signal sbi_ifs         : inout t_sbi_if_array;
    constant C_NB_MASTER   : in  positive;
    constant C_TARGET_ID   : in  sbi_addrs_t;
    constant C_TARGET_WAIT : in  naturals_t;
    constant C_PIPEIN      : in  boolean;
    constant C_SCOPE       : in  string
  );
end package tb_sbi_icn_tc5_pkg;

package body tb_sbi_icn_tc5_pkg is

  constant C_TIMEOUT : positive := 50; -- Max cycles for the access of master 1

  procedure run_test_case (
    signal clk_i           : in  std_logic;
    signal sbi_ifs         : inout t_sbi_if_array;
    constant C_NB_MASTER   : in  positive;
    constant C_TARGET_ID   : in  sbi_addrs_t;
    constant C_TARGET_WAIT : in  naturals_t;
    constant C_PIPEIN      : in  boolean;
    constant C_SCOPE       : in  string
  ) is
    variable v_tgt  : integer := -1;
    variable v_wait : natural;
    variable v_done : boolean;
  begin
    log(ID_LOG_HDR, "Test Case 5: aborted transfer (cs released before ready)", C_SCOPE);

    -- Slowest target with at least 2 wait states, the external default slave
    -- (ID 0, whole address range) excluded
    for t in C_TARGET_WAIT'range loop
      if unsigned(C_TARGET_ID(t)) /= 0 and C_TARGET_WAIT(t) >= 2 and
         (v_tgt < 0 or C_TARGET_WAIT(t) > C_TARGET_WAIT(v_tgt)) then
        v_tgt := t;
      end if;
    end loop;

    if C_NB_MASTER < 2 or v_tgt < 0 or C_PIPEIN then
      log(ID_SEQUENCER, "Skipped: needs 2 masters, a target with wait states and no sbi_pipe on the master ports", C_SCOPE);
      return;
    end if;

    ---------------------------------------------------------------------------
    -- Master 0 : read of the slow target, aborted one cycle after the grant
    ---------------------------------------------------------------------------
    wait until falling_edge(clk_i);
    sbi_ifs(0).cs    <= '1';
    sbi_ifs(0).rena  <= '1';
    sbi_ifs(0).wena  <= '0';
    sbi_ifs(0).addr  <= unsigned(C_TARGET_ID(v_tgt));
    wait until rising_edge(clk_i);  -- grant (bus idle)
    wait until falling_edge(clk_i);
    check_value(sbi_ifs(0).ready, '0', ERROR, "TC5: transfer of master 0 to target " & integer'image(v_tgt) & " pending", C_SCOPE);
    sbi_ifs(0).cs    <= '0';
    sbi_ifs(0).rena  <= '0';
    sbi_ifs(0).addr  <= (others => '0');

    ---------------------------------------------------------------------------
    -- Master 1 : write to target 0, must complete
    ---------------------------------------------------------------------------
    sbi_ifs(1).cs    <= '1';
    sbi_ifs(1).wena  <= '1';
    sbi_ifs(1).rena  <= '0';
    sbi_ifs(1).addr  <= unsigned(C_TARGET_ID(0));
    sbi_ifs(1).wdata <= x"C5";
    v_wait := 0;
    v_done := false;
    while not v_done and v_wait < C_TIMEOUT loop
      wait until rising_edge(clk_i);
      v_done := sbi_ifs(1).ready = '1';
      v_wait := v_wait + 1;
    end loop;
    check_value(v_done, ERROR, "TC5: master 1 not locked out after the abort of master 0 (" & integer'image(v_wait) & " cycles)", C_SCOPE);
    wait until falling_edge(clk_i);
    sbi_ifs(1).cs    <= '0';
    sbi_ifs(1).wena  <= '0';
    sbi_ifs(1).addr  <= (others => '0');
    sbi_ifs(1).wdata <= (others => '0');

    -- The write of master 1 really reached target 0
    sbi_check(addr_value => unsigned(C_TARGET_ID(0)), data_exp => x"C5", msg => "TC5: read back the write of master 1", clk => clk_i, sbi_if => sbi_ifs(0));
  end procedure run_test_case;

end package body tb_sbi_icn_tc5_pkg;
