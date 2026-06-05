-------------------------------------------------------------------------------
-- Title      : tb_sbi_icn_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- Description: Package for SBI Interconnect Testbench
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-06-05  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.std_logic_textio.all;
use     std.textio.all;

library asylum;
use     asylum.sbi_pkg.all;
use     asylum.icn_pkg.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
library bitvis_vip_sbi;
use     bitvis_vip_sbi.sbi_bfm_pkg.all;

package tb_sbi_icn_pkg is

  -- Define the subtype to constrain the UVVM SBI BFM record using global SBI constants
  subtype t_sbi_if_constrained is t_sbi_if(
    addr  (SBI_ADDR_WIDTH-1 downto 0),
    wdata (SBI_DATA_WIDTH-1 downto 0),
    rdata (SBI_DATA_WIDTH-1 downto 0)
  );

  -- Define the array type using the constrained subtype
  type t_sbi_if_array is array (integer range <>) of t_sbi_if_constrained;



end package tb_sbi_icn_pkg;
