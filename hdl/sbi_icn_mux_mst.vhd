-------------------------------------------------------------------------------
-- Title      : SBI Interconnect Mux Master
-- Project    : 
-------------------------------------------------------------------------------
-- Description: Multiplexing of SBI masters with "fix" or "roundrobin" priority
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026/06/02  1.0      mrosiere Created
-------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;

entity sbi_icn_mux_mst is
  generic (
    NAME       : string   := "sbi_icn";
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
end entity sbi_icn_mux_mst;

architecture rtl of sbi_icn_mux_mst is
  signal master_id : integer range 0 to NB_MASTER-1;
  signal busy      : std_logic;
begin

  -- Arbitration Logic: Fixed Priority
  gen_sel_fix: if MASTER_SEL = "fix" generate
    process (clk_i, arst_b_i) is
      variable v_found : boolean;
    begin
      if arst_b_i = '0' then
        master_id <= 0;
        busy      <= '0';
      elsif rising_edge(clk_i) then
        if cke_i = '1' then
          if busy = '0' then
            v_found := false;
            for m in 0 to NB_MASTER-1 loop
              if not v_found and sbi_inis_i(m).cs = '1' then
                master_id <= m;
                busy      <= '1';
                v_found   := true;
              end if;
            end loop;
          elsif sbi_tgt_i.ready = '1' then
            busy <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate gen_sel_fix;

  -- Arbitration Logic: Round Robin
  gen_sel_rr: if MASTER_SEL = "roundrobin" generate
    signal rr_ptr : integer range 0 to NB_MASTER-1;
  begin
    process (clk_i, arst_b_i) is
      variable v_idx   : integer range 0 to NB_MASTER-1;
      variable v_found : boolean;
    begin
      if arst_b_i = '0' then
        master_id <= 0;
        busy      <= '0';
        rr_ptr    <= 0;
      elsif rising_edge(clk_i) then
        if cke_i = '1' then
          if busy = '0' then
            v_found := false;
            for i in 0 to NB_MASTER-1 loop
              if not v_found then
                v_idx := (rr_ptr + i) mod NB_MASTER;
                if sbi_inis_i(v_idx).cs = '1' then
                  master_id <= v_idx;
                  busy      <= '1';
                  v_found   := true;
                  rr_ptr    <= (v_idx + 1) mod NB_MASTER;
                end if;
              end if;
            end loop;
          elsif sbi_tgt_i.ready = '1' then
            busy <= '0';
          end if;
        end if;
      end if;
    end process;
  end generate gen_sel_rr;

  -- Signal Routing
  process (all) is
  begin
    sbi_ini_o    <= sbi_inis_i(master_id);
    sbi_ini_o.cs <= sbi_inis_i(master_id).cs and busy;

    for m in 0 to NB_MASTER-1 loop
      sbi_tgts_o(m)       <= sbi_tgt_i;
      sbi_tgts_o(m).ready <= sbi_tgt_i.ready when (busy = '1' and m = master_id) else '0';
    end loop;
  end process;

end architecture rtl;