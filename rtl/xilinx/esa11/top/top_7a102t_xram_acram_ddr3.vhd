--
-- Copyright (c) 2015 Emanuel Stiebler
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;
use work.axi_pack.all;

entity esa11_xram_acram_ddr3 is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/100 MHz
	C_clk_freq: integer := 100;

	C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

	-- SoC configuration options
	C_bram_size: integer := 16;

        -- axi cache ram
	C_acram: boolean := true;
	C_acram_wait_cycles: integer := 2;
	C_acram_emu_kb: integer := 0; -- KB axi_cache emulation (0 to disable, power of 2, MAX 128)

        C_icache_expire: boolean := false; -- false: normal i-cache, true: passthru buggy i-cache
        -- warning: 2K, 4K, 8K, 16K, 32K cache produces timing critical warnings at 100MHz cpu clock
        C_icache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

        C3_NUM_DQ_PINS        : integer := 16;
        C3_MEM_ADDR_WIDTH     : integer := 14;
        C3_MEM_BANKADDR_WIDTH : integer := 3;
        
        C_axidma_c2: boolean := true;
        C_video_base_addr_out: boolean := true;
        C_axidma_bpp: integer := 32; -- bpp 8/16/32

        C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)

        C_video_cache_size: integer := 8; -- KB video cache (vgahdmi) (0: disable, 2,4,8,16,32:enable)
	C_vgahdmi_fifo_timeout: integer := 48;
	C_vgahdmi: boolean := false;

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: ESA11-7a102t MIPS compatible soft-core 100MHz 256MB DDR3"; -- default banner as initial content of screen BRAM, NOP for RAM
      C_vgatext_mode: integer := 0;   -- 640x480
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 0;   -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          C_vgatext_bitmap_fifo_timeout: integer := 48; -- abort compositing 48 pixels before end of line
          -- 8 bpp compositing
          -- step=horizontal width in pixels
          C_vgatext_bitmap_fifo_step: integer := 640;
          -- height=vertical height in pixels
          C_vgatext_bitmap_fifo_height: integer := 480;
          -- output data width 8bpp
          C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_addr_width: integer := 11;

	C_sio: integer := 1;   -- 1 UART channel
	C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
	C_gpio: integer := 32; -- 32 GPIO bits
	C_ps2: boolean := false; -- PS/2 keyboard
    C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
    );
    port (
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic;
	FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
	FPGA_SD_D0: in std_logic;
	-- two onboard green LEDs next to yellow and red
        --FPGA_LED2, FPGA_LED3: out std_logic;
        -- DDR3 ------------------------------------------------------------------
        DDR_DQ                  : inout  std_logic_vector(C3_NUM_DQ_PINS-1 downto 0);       -- mcb3_dram_dq
        DDR_A                   : out    std_logic_vector(C3_MEM_ADDR_WIDTH-1 downto 0);    -- mcb3_dram_a
        DDR_BA                  : out    std_logic_vector(C3_MEM_BANKADDR_WIDTH-1 downto 0);-- mcb3_dram_ba
        DDR_RAS_N               : out    std_logic;                                         -- mcb3_dram_ras_n
        DDR_CAS_N               : out    std_logic;                                         -- mcb3_dram_cas_n
        DDR_WE_N                : out    std_logic;                                         -- mcb3_dram_we_n
        DDR_ODT                 : out    std_logic;                                         -- mcb3_dram_odt
        DDR_CKE                 : out    std_logic;                                         -- mcb3_dram_cke
        DDR_LDM                 : out    std_logic;                                         -- mcb3_dram_dm
        DDR_DQS_P               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs
        DDR_DQS_N               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs_n
        DDR_UDM                 : out    std_logic;                                         -- mcb3_dram_udm
        DDR_CK_P                : out    std_logic;                                         -- mcb3_dram_ck
        DDR_CK_N                : out    std_logic;                                         -- mcb3_dram_ck_n
        DDR_RESET_N             : out    std_logic;
      
	M_EXPMOD0, M_EXPMOD1, M_EXPMOD2, M_EXPMOD3: inout std_logic_vector(7 downto 0); -- EXPMODs
	M_7SEG_A, M_7SEG_B, M_7SEG_C, M_7SEG_D, M_7SEG_E, M_7SEG_F, M_7SEG_G, M_7SEG_DP: out std_logic;
	M_7SEG_DIGIT: out std_logic_vector(3 downto 0);
--	seg: out std_logic_vector(7 downto 0); -- 7-segment display
--	an: out std_logic_vector(3 downto 0); -- 7-segment display
	M_LED: out std_logic_vector(7 downto 0);
	-- PS/2 keyboard
	PS2_A_DATA, PS2_A_CLK, PS2_B_DATA, PS2_B_CLK: inout std_logic;
        -- HDMI
	VID_D_P, VID_D_N: out std_logic_vector(2 downto 0);
	VID_CLK_P, VID_CLK_N: out std_logic;
        -- VGA
        VGA_RED, VGA_GREEN, VGA_BLUE: out std_logic_vector(7 downto 0);
        VGA_SYNC_N, VGA_BLANK_N, VGA_CLOCK_P: out std_logic;
        VGA_HSYNC, VGA_VSYNC: out std_logic;
	M_BTN: in std_logic_vector(4 downto 0);
	M_HEX: in std_logic_vector(3 downto 0)
    );
end esa11_xram_acram_ddr3;

architecture Behavioral of esa11_xram_acram_ddr3 is
    -- useful for conversion from KB to number of address bits
    function ceil_log2(x: integer)
      return integer is
    begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
    end ceil_log2;
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_100MHz, clk_200MHz, clk_250MHz: std_logic;
    signal clk_125MHz: std_logic := '0';
    signal clk_pixel_shift: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;

    component clk_d100_100_200_250_25MHz is
    Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_250mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_250_25MHz;

    component clk_d100_100_200_125_25MHz is
    Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_125mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_125_25MHz;

    signal calib_done           : std_logic := '0';

    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0);
    signal ram_address        : std_logic_vector(29 downto 2);
    signal ram_data_write     : std_logic_vector(31 downto 0);
    signal ram_data_read      : std_logic_vector(31 downto 0);
    signal ram_read_busy      : std_logic := '0';
    signal ram_ready          : std_logic := '1';
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);

    signal dma_data : std_logic_vector(31 downto 0);
    signal cche_debug : std_logic_vector(7 downto 0) := (others => '0');
    signal cche_busy : std_logic := '0';
    signal vga_clk: std_logic;
    signal S_vga_red, S_vga_green, S_vga_blue: std_logic_vector(7 downto 0);
    signal S_vga_blank: std_logic;
    signal S_vga_vsync, S_vga_hsync: std_logic;
    signal S_vga_fetch_next, S_vga_line_repeat: std_logic;
    signal S_vga_active_enabled: std_logic;
    signal S_vga_addr: std_logic_vector(29 downto 2);
    signal S_vga_base_addr: std_logic_vector(31 downto 0) := x"80010000"; -- byte address
    signal S_vga_addr_strobe: std_logic;
    signal S_vga_suggest_cache: std_logic;
    signal S_vga_suggest_burst: std_logic_vector(15 downto 0);
    signal S_vga_data, S_vga_data_debug: std_logic_vector(31 downto 0);
    signal S_vga_read_ready: std_logic;
    signal S_vga_data_ready: std_logic;
    signal red_byte, green_byte, blue_byte: std_logic_vector(7 downto 0);
    signal vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_refresh: std_logic;
    signal vga_reg_dtack: std_logic; -- low active, ack from VGA reg access
    signal vga_ackback: std_logic := '0'; -- clear for ack_d, sys_clk domai
    signal vreg_en: std_logic := '1'; -- active high
    signal vreg_uds: std_logic := '0'; -- even byte-addr, data bits 8-15, low active
    signal vreg_lds: std_logic := '0'; -- odd byte-addr, data bits 0-7, low active
--   signal vreg_wbe : std_logic_vector(3 downto 0);
    signal vreg_we: std_logic := '1'; -- write enable, active low
    signal vreg_wait: std_logic := '0'; -- mem_pause from VGA reg acces
    signal vga_read : std_logic_vector(15 downto 0) := (others => '0');
    signal vga_window : std_logic;
    signal vblank_int : std_logic;

    -- CPU memory axi port
    signal l00_axi_areset_n: std_logic := '1';
    signal l00_axi_aclk: std_logic := '0';
    signal main_axi_miso: T_axi_miso;
    signal main_axi_mosi: T_axi_mosi;

    -- video axi port
    signal l01_axi_areset_n: std_logic := '1';
    signal l01_axi_aclk: std_logic := '0';
    signal from_reader_to_axi: T_axi_mosi;
    signal from_axi_to_reader: T_axi_miso;

    -- unused axi port
    signal l02_axi_areset_n: std_logic := '1';
    signal l02_axi_aclk: std_logic := '0';
    signal main_axi_miso2: T_axi_miso;
    signal main_axi_mosi2: T_axi_mosi;

    -- to switch glue/plasma vga
    signal glue_vga_vsync_n, glue_vga_hsync_n: std_logic;
    signal glue_vga_red, glue_vga_green, glue_vga_blue: std_logic_vector(7 downto 0);

    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
    --signal vga_vsync_n, vga_hsync_n: std_logic;
    signal ps2_clk_in : std_logic;
    signal ps2_clk_out : std_logic;
    signal ps2_dat_in : std_logic;
    signal ps2_dat_out : std_logic;
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin

    cpu100_200_250_25MHz: if C_clk_freq = 100 and not C_dvid_ddr generate
    clk100in_out100_200_250_25: clk_d100_100_200_250_25MHz
    port map(clk_100mhz_in_p => i_100MHz_P,
             clk_100mhz_in_n => i_100MHz_N,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk,
             clk_200mhz => clk_200MHz,
             clk_250mhz => clk_250MHz,
             clk_25mhz  => clk_25MHz
    );
    clk_pixel_shift <= clk_250MHz;
    end generate;

    cpu100_200_125_25MHz: if C_clk_freq = 100 and C_dvid_ddr generate
    clk100in_out100_200_125_25: clk_d100_100_200_125_25MHz
    port map(clk_100mhz_in_p => i_100MHz_P,
             clk_100mhz_in_n => i_100MHz_N,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk,
             clk_200mhz => clk_200MHz,
             clk_125mhz => clk_125MHz,
             clk_25mhz  => clk_25MHz
    );
    clk_pixel_shift <= clk_125MHz;
    end generate;

    G_vendor_specific_startup: if C_vendor_specific_startup generate
    -- reset hard-block: Xilinx Artix-7 specific
    reset: startupe2
    generic map (
      prog_usr => "FALSE"
    )
    port map (
      cfgmclk => cfgmclk,
      clk => cfgmclk,
      gsr => sio_break,
      gts => '0',
      keyclearb => '0',
      pack => '1',
      usrcclko => clk,
      usrcclkts => '0',
      usrdoneo => '1',
      usrdonets => '0'
    );
    end generate;

    ps2_dat_in	<= PS2_A_DATA;
    PS2_A_DATA	<= '0' when ps2_dat_out='0' else 'Z';
    ps2_clk_in	<= PS2_A_CLK;
    PS2_A_CLK	<= '0' when ps2_clk_out='0' else 'Z';

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_acram => C_acram,
      C_acram_wait_cycles => C_acram_wait_cycles,
      C_icache_expire => C_icache_expire,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      --C_ps2 => C_ps2,
      C_video_base_addr_out => C_video_base_addr_out,
      C_dvid_ddr => C_dvid_ddr,
      C_vgahdmi => C_vgahdmi,
      C_video_cache_size => C_video_cache_size,
      C_vgahdmi_fifo_timeout => C_vgahdmi_fifo_timeout,

      -- vga advanced graphics text+compositing bitmap
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_bram_base => C_vgatext_bram_base,
      C_vgatext_external_mem => C_vgatext_external_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
      C_vgatext_font_bram8 => C_vgatext_font_bram8,
      C_vgatext_bus_read => C_vgatext_bus_read,
      C_vgatext_reg_read => C_vgatext_reg_read,
      C_vgatext_text_fifo => C_vgatext_text_fifo,
      C_vgatext_text_fifo_step => C_vgatext_text_fifo_step,
      C_vgatext_text_fifo_width => C_vgatext_text_fifo_width,
      C_vgatext_char_height => C_vgatext_char_height,
      C_vgatext_font_height => C_vgatext_font_height,
      C_vgatext_font_depth => C_vgatext_font_depth,
      C_vgatext_font_linedouble => C_vgatext_font_linedouble,
      C_vgatext_font_widthdouble => C_vgatext_font_widthdouble,
      C_vgatext_monochrome => C_vgatext_monochrome,
      C_vgatext_finescroll => C_vgatext_finescroll,
      C_vgatext_cursor => C_vgatext_cursor,
      C_vgatext_cursor_blink => C_vgatext_cursor_blink,
      C_vgatext_bitmap => C_vgatext_bitmap,
      C_vgatext_bitmap_depth => C_vgatext_bitmap_depth,
      C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo,
      C_vgatext_bitmap_fifo_timeout => C_vgatext_bitmap_fifo_timeout,
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,

      C_debug => C_debug
    )
    port map (
        clk => clk,
	clk_pixel => clk_25MHz,
	clk_pixel_shift => clk_pixel_shift,
	acram_en => ram_en,
	acram_addr => ram_address,
	acram_byte_we => ram_byte_we,
	acram_data_rd => ram_data_read,
	acram_data_wr => ram_data_write,
	acram_ready => ram_ready,
	sio_txd(0) => UART1_TXD, 
	sio_rxd(0) => UART1_RXD,
	sio_break(0) => sio_break,
        spi_sck(0)  => open,  spi_sck(1)  => FPGA_SD_SCLK,
        spi_ss(0)   => open,  spi_ss(1)   => FPGA_SD_D3,
        spi_mosi(0) => open,  spi_mosi(1) => FPGA_SD_CMD,
        spi_miso(0) => '-',   spi_miso(1) => FPGA_SD_D0,
	gpio(7 downto 0) => M_EXPMOD0, gpio(15 downto 8) => M_EXPMOD1,
	gpio(23 downto 16) => M_EXPMOD2, gpio(31 downto 24) => M_EXPMOD3,
	gpio(127 downto 32) => open,
        -- PS/2 Keyboard
        ps2_clk_in   => ps2_clk_in,
        ps2_dat_in   => ps2_dat_in,
        ps2_clk_out  => ps2_clk_out,
        ps2_dat_out  => ps2_dat_out,
        -- VGA/HDMI
	vga_vsync => glue_vga_vsync_n,
	vga_hsync => glue_vga_hsync_n,
	vga_r => glue_vga_red,
	vga_g => glue_vga_green,
	vga_b => glue_vga_blue,
        dvid_red   => dvid_red,
        dvid_green => dvid_green,
        dvid_blue  => dvid_blue,
        dvid_clock => dvid_clock,
        video_base_addr => S_vga_base_addr(31 downto 2),
	-- simple I/O
	simple_out(7 downto 0) => M_LED, simple_out(15 downto 8) => disp_7seg_segment,
	simple_out(19 downto 16) => M_7SEG_DIGIT, simple_out(31 downto 20) => open,
	simple_in(4 downto 0) => M_BTN,
        simple_in(8 downto 5) => M_HEX,
        simple_in(31 downto 9) => (others => '-')
    );

    m_7seg_a  <= disp_7seg_segment(0);
    m_7seg_b  <= disp_7seg_segment(1);
    m_7seg_c  <= disp_7seg_segment(2);
    m_7seg_d  <= disp_7seg_segment(3);
    m_7seg_e  <= disp_7seg_segment(4);
    m_7seg_f  <= disp_7seg_segment(5);
    m_7seg_g  <= disp_7seg_segment(6);
    m_7seg_dp <= disp_7seg_segment(7);

    G_dvi_sdr: if not C_dvid_ddr generate
      tmds_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_clk <= dvid_clock(0);
    end generate;

    G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift,
      clk_n     => '0', -- inverted shift clock not needed on xilinx
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_rgb(2),
      out_green => tmds_rgb(1),
      out_blue  => tmds_rgb(0),
      out_clock => tmds_clk
    );
    end generate;

    -- differential output buffering for HDMI clock and video
    hdmi_output: entity work.hdmi_out
    port map (
        tmds_in_clk => tmds_clk, -- clk_25MHz or tmds_clk
        tmds_out_clk_p => VID_CLK_P,
        tmds_out_clk_n => VID_CLK_N,
        tmds_in_rgb => tmds_rgb,
        tmds_out_rgb_p => VID_D_P,
        tmds_out_rgb_n => VID_D_N
    );

    acram_emu_gen: if C_acram_emu_kb > 0 generate
    axi_cache_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 8 + ceil_log2(C_acram_emu_kb)
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(9 + ceil_log2(C_acram_emu_kb) downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
    );
    --ram_data_read <= x"01234567"; -- debug purpose
    end generate;

    G_acram_real: if C_acram_emu_kb = 0 generate
    axi_cache_ram: entity work.axi_cache
    port map (
        sys_clk            => clk,
        reset              => not calib_done, -- release reset when DDR3 is ready

        -- simple RAM bus interface
        i_en               => ram_en,
        addr_next          => (others => '0'),
        addr(31 downto 30) => "00",
        addr(29 downto 2)  => ram_address(29 downto 2),
        addr(1 downto 0)   => "00",
        wbe                => ram_byte_we,
        din                => ram_data_write,
        dout               => ram_data_read,
        readBusy           => ram_read_busy,
        hitcount           => ram_cache_hitcnt,
        readcount          => ram_cache_readcnt,

        -- axi port l00 this module is AXI master
        m_axi_aresetn      => l00_axi_areset_n,
        m_axi_aclk         => l00_axi_aclk,
        axi_in             => main_axi_miso,
        axi_out            => main_axi_mosi,

        debug              => ram_cache_debug
    );
    ram_ready <= not ram_read_busy;

    u_ddr_mem : entity work.axi_mpmc
    port map(
        sys_rst              => not clk_locked, -- release reset when clock is stable
        sys_clk_i            => clk_200MHz, -- should be 200MHz
        -- physical signals to RAM chip
        ddr3_dq              => ddr_dq,
        ddr3_dqs_n           => ddr_dqs_n,
        ddr3_dqs_p           => ddr_dqs_p,
        ddr3_addr            => ddr_a,
        ddr3_ba              => ddr_ba,
        ddr3_ras_n           => ddr_ras_n,
        ddr3_cas_n           => ddr_cas_n,
        ddr3_we_n            => ddr_we_n,
        ddr3_reset_n         => ddr_reset_n,
        ddr3_ck_p(0)         => ddr_ck_p,
        ddr3_ck_n(0)         => ddr_ck_n,
        ddr3_cke(0)          => ddr_cke,
        ddr3_dm(1)           => ddr_udm,
        ddr3_dm(0)           => ddr_ldm,
        ddr3_odt(0)          => ddr_odt,

        -- multiport axi interface (AXI slaves)
        s00_axi_areset_out_n => l00_axi_areset_n,
        s00_axi_aclk         => l00_axi_aclk,
        s00_axi_in           => main_axi_mosi,
        s00_axi_out          => main_axi_miso,

        s01_axi_areset_out_n => l01_axi_areset_n,
        s01_axi_aclk         => l01_axi_aclk,
        s01_axi_in           => from_reader_to_axi,
        s01_axi_out          => from_axi_to_reader,

        s02_axi_areset_out_n => l02_axi_areset_n,
        s02_axi_aclk         => l02_axi_aclk,
        s02_axi_in           => main_axi_mosi2,
        s02_axi_out          => main_axi_miso2,

        init_calib_complete  => calib_done -- becomes high cca 0.3 seconds after startup
    );
    l00_axi_aclk <= clk; -- 100 MHz
    l01_axi_aclk <= clk; -- port l01 used for video
    l02_axi_aclk <= '0'; -- port l02 not used
    end generate; -- G_acram_real

    --FPGA_LED2 <= calib_done; -- should turn on 0.3 seconds after startup and remain on
    --FPGA_LED3 <= ram_read_busy; -- more RAM traffic -> more LED brightness

    vga_f32c: if C_vgahdmi or C_vgatext generate
    VGA_SYNC_N <= '1';
    VGA_BLANK_N <= '1';
    VGA_CLOCK_P <= clk_25MHz;
    VGA_VSYNC <= glue_vga_vsync_n;
    VGA_HSYNC <= glue_vga_hsync_n;
    vga_red <= glue_vga_red;
    vga_green <= glue_vga_green;
    vga_blue <= glue_vga_blue;
    end generate;

    G_axidma_c2: if C_axidma_c2 generate
    axidma: entity work.axi_read
    port map
    (
        axi_aresetn => l01_axi_areset_n,
        axi_aclk => l01_axi_aclk,
        axi_in => from_axi_to_reader,
        axi_out => from_reader_to_axi,

        iaddr => S_vga_addr,
        iaddr_strobe => S_vga_addr_strobe,
        iburst => S_vga_suggest_burst(7 downto 0),
        odata => S_vga_data,
        oready => S_vga_data_ready,
        iread_ready => S_vga_read_ready
    );
    -- data source: FIFO - cross clock domain cpu-pixel
    -- compositing2 video accelerator, shows linked list of pixel data
    comp_fifo: entity work.compositing2_fifo
    generic map
    (
      --C_timeout => 48,
      --C_timeout_incomplete => true,
      C_fast_ram => false,
      C_burst_max => 64,
      C_width => 640,
      C_height => 480,
      C_data_width => C_axidma_bpp,
      C_addr_width => 11
    )
    port map
    (
      clk => l01_axi_aclk, -- at axi speed
      clk_pixel => clk_25MHz,
      suggest_cache => S_vga_suggest_cache, -- video_fifo_suggest_cache,
      suggest_burst => S_vga_suggest_burst,
      addr_strobe => S_vga_addr_strobe, -- video_fifo_addr_strobe,
      addr_out => S_vga_addr, -- video_fifo_addr,
      data_ready => S_vga_data_ready, -- data valid, acknowledge from RAM
      data_in => S_vga_data,
      read_ready => S_vga_read_ready,
      base_addr => S_vga_base_addr(29 downto 2),
      active => S_vga_active_enabled,
      frame => open, -- vga_frame, -- for f32c video interrupt
      data_out => vga_data_from_fifo(C_axidma_bpp-1 downto 0),
      fetch_next => S_vga_fetch_next
    );
    S_vga_active_enabled <= not S_vga_vsync;
    --S_vga_data_debug <= x"00AA00AA"; -- stripe on the screen
    --S_vga_data_debug <= x"0280_0000" when S_vga_suggest_cache='0' else x"031CE000"; -- full screen of RGB series
    --S_vga_data_debug <= x"0280_0000" when S_vga_suggest_cache='0' else S_vga_data;

    G_axidma_8bpp: if C_axidma_bpp = 8 generate
      red_byte   <= vga_data_from_fifo(7 downto 5) & vga_data_from_fifo(5) & vga_data_from_fifo(5) & vga_data_from_fifo(5) & vga_data_from_fifo(5) & vga_data_from_fifo(5);
      green_byte <= vga_data_from_fifo(4 downto 2) & vga_data_from_fifo(2) & vga_data_from_fifo(2) & vga_data_from_fifo(2) & vga_data_from_fifo(2) & vga_data_from_fifo(2);
      blue_byte  <= vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(0) & vga_data_from_fifo(0) & vga_data_from_fifo(0) & vga_data_from_fifo(0) & vga_data_from_fifo(0) & vga_data_from_fifo(0);
    end generate;

    G_axidma_16bpp: if C_axidma_bpp = 16 generate
      red_byte   <= vga_data_from_fifo(15 downto 11) & vga_data_from_fifo(11) & vga_data_from_fifo(11) & vga_data_from_fifo(11);
      green_byte <= vga_data_from_fifo(10 downto 5) & vga_data_from_fifo(5) & vga_data_from_fifo(5);
      blue_byte  <= vga_data_from_fifo(4 downto 0) & vga_data_from_fifo(0) & vga_data_from_fifo(0) & vga_data_from_fifo(0);
    end generate;

    G_axidma_32bpp: if C_axidma_bpp = 32 generate
      red_byte   <= vga_data_from_fifo(23 downto 16);
      green_byte <= vga_data_from_fifo(15 downto 8);
      blue_byte  <= vga_data_from_fifo(7 downto 0);
    end generate;

    -- VGA video generator - pixel clock synchronous
    vgabitmap: entity work.vga
    --generic map (
    --  C_dbl_y => 1
    --)
    port map
    (
      clk_pixel => clk_25MHz,
      test_picture => '0', -- shows test picture when VGA is disabled (on startup)
      fetch_next  => S_vga_fetch_next,
      line_repeat => S_vga_line_repeat,
      red_byte    => red_byte,
      green_byte  => green_byte,
      blue_byte   => blue_byte,
      vga_r => S_vga_red,
      vga_g => S_vga_green,
      vga_b => S_vga_blue,
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync,
      vga_blank => S_vga_blank, -- '1' when outside of horizontal or vertical graphics area
      vga_vblank => open -- '1' when outside of vertical graphics area (used for vblank interrupt)
    );
    vga_red <= S_vga_red;
    vga_green <= S_vga_green;
    vga_blue <= S_vga_blue;
    vga_sync_n <= '1';
    vga_blank_n <= not S_vga_blank;
    vga_hsync <= not S_vga_hsync;
    vga_vsync <= not S_vga_vsync;
    vga_clock_p <= clk_25MHz;

    I_vgahdmi_dvid: entity work.vga2dvid
    generic map 
    (
      C_ddr     => C_dvid_ddr,
      C_depth   => 8 -- 8bpp (8 bit per pixel)
    )
    port map
    (
      clk_pixel => clk_25MHz, clk_shift => clk_pixel_shift,

      in_red   => S_vga_red,
      in_green => S_vga_green,
      in_blue  => S_vga_blue,

      in_blank => S_vga_blank,
      in_hsync => S_vga_hsync,
      in_vsync => S_vga_vsync,

      -- single-ended output ready for differential buffers
      out_red   => dvid_red,
      out_green => dvid_green,
      out_blue  => dvid_blue,
      out_clock => dvid_clock
    );

    end generate; -- G_vga_c2_gen C_axidma_c2

end Behavioral;
