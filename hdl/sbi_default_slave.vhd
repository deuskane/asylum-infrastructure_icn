-------------------------------------------------------------------------------
-- Title      : SBI Default Slave
-- Project    : 
-------------------------------------------------------------------------------
-- Description: Handle access to unmapped address space
-------------------------------------------------------------------------------
-- Copyright (c) 2025 
--------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2025/06/22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;

entity sbi_default_slave is
  port (
    clk_i               : in std_logic;
    cke_i               : in std_logic;
    arst_b_i            : in std_logic;

    sbi_ini_i           : in  sbi_ini_t;
    sbi_tgt_o           : out sbi_tgt_t
);
end entity sbi_default_slave;

architecture rtl of sbi_default_slave is
begin

  -- Always ready with data set to 0
  sbi_tgt_o.ready     <= sbi_ini_i.cs;
  sbi_tgt_o.rdata     <= (others => '0');
  sbi_tgt_o.info.name <= to_sbi_name("Default");

  -- Access report for debugging
-- pragma translate_off
  process (clk_i) is
  begin
    if rising_edge(clk_i) then
      -- Reset is not checked here because we want to see access attempts
      -- even if the system is being initialized (depending on needs)
      if cke_i = '1' and sbi_ini_i.cs = '1' then
        report "SBI Interconnect: Access to Default Slave at address 0x" & to_hstring(sbi_ini_i.addr) severity note;
      end if;
    end if;
  end process;
-- pragma translate_on

end architecture rtl;