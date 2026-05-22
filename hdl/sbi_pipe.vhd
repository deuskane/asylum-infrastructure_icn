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
  generic (
    ENABLE              : boolean := true
  );
  port (
    clk_i               : in std_logic;
    cke_i               : in std_logic;
    arst_b_i            : in std_logic;

    -- Initiator side (from Master)
    sbi_ini_i           : in  sbi_ini_t;
    sbi_tgt_o           : out sbi_tgt_t;

    -- Target side (to Slave)
    sbi_ini_o           : out sbi_ini_t;
    sbi_tgt_i           : in  sbi_tgt_t
);
end entity sbi_pipe;

architecture rtl of sbi_pipe is
begin

  gen_enabled: if ENABLE generate
    signal pending_q : std_logic;
  begin
    process (clk_i, arst_b_i) is
    begin
      if arst_b_i = '0' 
      then
        sbi_ini_o.cs    <= '0';
        sbi_tgt_o.ready <= '1';
        pending_q       <= '0';
      elsif rising_edge(clk_i) 
      then
        if cke_i = '1' 
        then
          -- Return path (Target -> Initiator)
          -- Register the slave response
          sbi_tgt_o <= sbi_tgt_i;
  
          -- Forward path (Initiator -> Target)
          if pending_q = '0' 
          then
            -- IDLE state: Waiting for a new request
            if sbi_ini_i.cs = '1' 
            then
              sbi_ini_o       <= sbi_ini_i;
              pending_q       <= '1';
              -- Force ready to '0' while the request is being propagated
              -- to prevent the master from finishing too early.
              sbi_tgt_o.ready <= '0';
            else
              sbi_ini_o.cs    <= '0';
            end if;
          else
            -- BUSY state: Transaction in progress on slave side
            -- As soon as the slave responds 'ready', we cut the CS to it
            if sbi_tgt_i.ready = '1' then
              sbi_ini_o.cs    <= '0';
              -- Wait for the master to release its CS before accepting the next one
              if sbi_ini_i.cs = '0' then
                pending_q     <= '0';
              end if;
            end if;
          end if;
        end if;
      end if;
    end process;
  end generate gen_enabled;

  gen_disabled: if not ENABLE generate
    sbi_ini_o <= sbi_ini_i;
    sbi_tgt_o <= sbi_tgt_i;
  end generate gen_disabled;

end architecture rtl;