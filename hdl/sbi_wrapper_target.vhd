-------------------------------------------------------------------------------
-- Title      : sbi wrapper target
-- Project    : sbi (Pico Bus)
-------------------------------------------------------------------------------
-- File       : sbi_wrapper_target.vhd
-- Author     : Mathieu Rosière
-- Company    : 
-- Created    : 2014-06-03
-- Last update: 2026-01-18
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2014-06-03  1.0      mrosiere Created
-- 2025-08-03  1.1      mrosiere Use unconstrainted pbi
-- 2025-04-05  1.2      mrosiere Add Algo (binary/one-hot)
-- 2025-05-08  1.3      mrosiere CS depends of input cs Delete clock/reset port
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
library asylum;
use     asylum.sbi_pkg.all;
use     asylum.logic_pkg.all;
use     asylum.convert_pkg.all;

entity sbi_wrapper_target is
  -- =====[ Parameters ]==========================
  generic (
    SIZE_DATA      : natural := 8;
    SIZE_ADDR_IP   : natural := 0;
    ID             : std_logic_vector (SBI_ADDR_WIDTH-1 downto 0) := (others => '0');
    ADDR_ENCODING  : string  := "binary"; -- "binary" / "one_hot"
    TGT_ZEROING    : boolean := false
    
     );
  -- =====[ Interfaces ]==========================
  port (
    cs_o                : out   std_logic;

    -- To IP
    sbi_ini_o           : out   sbi_ini_t;
    sbi_tgt_i           : in    sbi_tgt_t;
    
    -- From Bus
    sbi_ini_i           : in    sbi_ini_t;
    sbi_tgt_o           : out   sbi_tgt_t
    );
end sbi_wrapper_target;

architecture rtl of sbi_wrapper_target is
  constant SIZE_ADDR       : natural := sbi_ini_i.addr'length;
  constant SIZE_ADDR_ID    : natural := SIZE_ADDR-SIZE_ADDR_IP;
  constant CST0            : std_logic_vector(sbi_tgt_o.rdata'range) := (others => '0');
  constant IDX             : integer := onehot_to_integer(ID);
    
  signal   sbi_id          : std_logic_vector(SIZE_ADDR_ID-1 downto 0);
  signal   tgt_id          : std_logic_vector(SIZE_ADDR_ID-1 downto 0);
           
  signal   cs              : std_logic;
  signal   tgt_addr        : std_logic_vector(SIZE_ADDR_IP-1 downto 0);
  signal   tgt_rdata       : std_logic_vector(sbi_tgt_o.rdata'range);
  signal   tgt_ready       : std_logic;

  signal   ini_cs          : std_logic;
  signal   ini_re          : std_logic;
  signal   ini_we          : std_logic;
  signal   ini_addr        : std_logic_vector(sbi_ini_i.addr'range);
  signal   ini_wdata       : std_logic_vector(sbi_ini_i.wdata'range);

    
begin  -- rtl

  -----------------------------------------------------------------------------
  -- Check Parameters
  -----------------------------------------------------------------------------
--  assert SIZE_ADDR_IP>SBI_ADDR_WIDTH report "Invalid value at the parameter 'SIZE_ADDR_IP'" severity FAILURE;
  
  -----------------------------------------------------------------------------
  -- Chip Select
  -----------------------------------------------------------------------------
  -- Don't use Alias to see this signal in gtkwave
  
  gen_addr_encoding_binary: if ADDR_ENCODING="binary"
  generate
    sbi_id             <= ini_addr(SIZE_ADDR   -1 downto SIZE_ADDR_IP);
    tgt_id             <= ID      (SIZE_ADDR   -1 downto SIZE_ADDR_IP);
    
    cs                 <= ini_cs when (sbi_id = tgt_id) else
                          '0';
  end generate gen_addr_encoding_binary;
    
  gen_addr_encoding_one_hot: if ADDR_ENCODING="one_hot"
  generate
    cs                 <= ini_cs and ini_addr(IDX);
  end generate gen_addr_encoding_one_hot;
  
  -----------------------------------------------------------------------------
  -- From Bus
  -----------------------------------------------------------------------------
  -- USe tmp signal to see this signal in gtkwave
  ini_cs             <= sbi_ini_i.cs   ;
  ini_re             <= sbi_ini_i.re   ;
  ini_we             <= sbi_ini_i.we   ;
  ini_addr           <= sbi_ini_i.addr ;
  ini_wdata          <= sbi_ini_i.wdata;

  tgt_addr           <= ini_addr(SIZE_ADDR_IP-1 downto 0);
  
  -----------------------------------------------------------------------------
  -- To Bus
  -----------------------------------------------------------------------------
  gen_tgt_zeroing: if TGT_ZEROING = true
  generate
    tgt_rdata          <= sbi_tgt_i.rdata when cs='1' else
                          CST0(tgt_rdata'range);
    tgt_ready          <= sbi_tgt_i.ready when cs='1' else
                          '1';
  end generate gen_tgt_zeroing;

  gen_tgt_zeroing_b: if TGT_ZEROING = false
  generate
    tgt_rdata          <= sbi_tgt_i.rdata;
    tgt_ready          <= sbi_tgt_i.ready;
  end generate gen_tgt_zeroing_b;
  
  sbi_tgt_o.rdata    <= tgt_rdata;
  sbi_tgt_o.ready    <= tgt_ready;
  sbi_tgt_o.info     <= sbi_tgt_i.info;
  
  -----------------------------------------------------------------------------
  -- To IP
  -----------------------------------------------------------------------------
  sbi_ini_o.cs        <= cs;
  sbi_ini_o.re        <= ini_re;
  sbi_ini_o.we        <= ini_we;
  sbi_ini_o.addr      <= std_logic_vector(resize(unsigned(tgt_addr),sbi_ini_o.addr'length));
  sbi_ini_o.wdata     <= ini_wdata;

  cs_o                <= cs;
  
-- pragma translate_off

  process is
  begin  -- process
    wait for 1 ps;
    
    report "["& sbi_tgt_i.info.name &"] Target["&to_hstring(ID)&"] Address : "&integer'image(SIZE_ADDR_IP) severity note;

    if (ADDR_ENCODING = "one_hot")
    then
      report "  * Index : " &integer'image(IDX) severity note;
      
    end if;
    

    wait;
  end process;

-- pragma translate_on  
  
  
end rtl;
