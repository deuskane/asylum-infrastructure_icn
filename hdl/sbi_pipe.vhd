-------------------------------------------------------------------------------
-- Title      : SBI Pipe
-- Project    : 
-------------------------------------------------------------------------------
-- Description: Add a register stage on SBI interface to break timing paths
-------------------------------------------------------------------------------
-- Copyright (c) 2025 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2025/07/10  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;

entity sbi_pipe is
  generic 
  (ENABLE              : boolean := true
  ;VERBOSE             : boolean := false
  );
  port 
  (clk_i               : in std_logic
  ;cke_i               : in std_logic
  ;arst_b_i            : in std_logic

  -- Initiator side (from Master)
  ;sbi_ini_i           : in  sbi_ini_t
  ;sbi_tgt_o           : out sbi_tgt_t

   -- Target side (to Slave)
  ;sbi_ini_o           : out sbi_ini_t
  ;sbi_tgt_i           : in  sbi_tgt_t
);
end entity sbi_pipe;

architecture rtl of sbi_pipe is
begin

  gen_enabled: if ENABLE generate
    type state_t is (IDLE, PENDING, RESPONSE);
    signal state_q             : state_t;
    signal transaction_error_q : std_logic; -- For protocol compliance checking

     -- Pipeline registers are implemented in the process below, which also manages the handshakes and protocol compliance
  begin
    process (clk_i, arst_b_i) is
    begin
      if arst_b_i = '0' 
      then
        sbi_ini_o.cs    <= '0';
        sbi_tgt_o.ready <= '0'; -- On n'est pas prêt par défaut pour forcer le cycle de pipeline
        state_q         <= IDLE;
      elsif rising_edge(clk_i) 
      then
        if cke_i = '1' 
        then
          case state_q is

            ------------------------------------------
            -- IDLE state
            -- Waiting for a new request
            ------------------------------------------
            when IDLE =>
              sbi_ini_o.cs    <= '0'; -- No transaction in progress, so CS is deasserted
              sbi_tgt_o.ready <= '0'; -- No  response ready in IDLE state
          
              if sbi_ini_i.cs = '1' 
              then
                state_q         <= PENDING;
                sbi_ini_o.cs    <= '1'; -- Propagate CS to target
                sbi_ini_o       <= sbi_ini_i;
              end if;

            ------------------------------------------
            -- BUSY state
            -- Transaction in progress on slave side
            ------------------------------------------
            when PENDING =>
              sbi_ini_o.cs    <= '1'; -- Propagate CS to target
              sbi_tgt_o.ready <= '0'; 

              if sbi_tgt_i.ready = '1' 
              then
                state_q         <= RESPONSE;
                sbi_ini_o.cs    <= '0'; -- Deassert CS after transaction completion
                sbi_tgt_o.ready <= '1'; -- Propagate ready back to initiator
                sbi_tgt_o       <= sbi_tgt_i;

              end if;

            ------------------------------------------
            -- RESPONSE state
            -- Transaction complete
            ------------------------------------------
            when RESPONSE =>
              state_q         <= IDLE;
              sbi_ini_o.cs    <= '0';
              sbi_tgt_o.ready <= '0'; 
            end case;
          end if;
        end if;
    end process;

-- pragma translate_off
    -- Verification of protocol compliance: 
    -- The initiator must maintain the request signals stable while the transaction is pending
    process (clk_i,arst_b_i) is
    begin
      if arst_b_i = '1' 
      then
        transaction_error_q <= '0';
      elsif rising_edge(clk_i)
      then
        if cke_i = '1' then
          
          if state_q = PENDING and sbi_tgt_i.ready = '0' 
          then
            transaction_error_q <= '1';
            assert sbi_ini_i = sbi_ini_o
              report "SBI Pipe: Initiator changed request during pending transaction" severity error;
          end if;
        end if;
      end if;
    end process;
-- pragma translate_on

  end generate gen_enabled;

  gen_disabled: if not ENABLE generate
    sbi_ini_o <= sbi_ini_i;
    sbi_tgt_o <= sbi_tgt_i;
  end generate gen_disabled;

-- pragma translate_off
  gen_verbose: if VERBOSE generate
    process (clk_i) is
    begin
      if rising_edge(clk_i)
      then
        if cke_i = '1'
        then
          -- Report only at the start of an outgoing transaction
          if sbi_ini_o.cs = '1' and sbi_tgt_i.ready = '1'
          then
              if sbi_ini_o.we = '1' then
                report "["&sbi_tgt_i.info.name& "] Write @0x" & to_hstring(sbi_ini_o.addr) & " 0x" & to_hstring(sbi_ini_o.wdata) severity note;
              else -- Read
                report "["&sbi_tgt_i.info.name& "] Read  @0x" & to_hstring(sbi_ini_o.addr) & " 0x" & to_hstring(sbi_tgt_i.rdata) severity note;
              end if;
          end if;
        end if;
      end if;
    end process;
  end generate gen_verbose;
-- pragma translate_on

  
end architecture rtl;