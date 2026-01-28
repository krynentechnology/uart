--
-- Copyright (C) 2026, Kees Krijnen.
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This program is distributed WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/> for a
-- copy.
--
-- License: LGPL, v3, as defined and found on www.gnu.org,
--          https://www.gnu.org/licenses/lgpl-3.0.html
--
--  Description: UART HW setup for Digilent Xilinx Spartan-3 Starter Kit
--               (XC3S200-4FT256) and Xilinx ISE 14.7. E.g. ISE 14.7 does
--               not support package component interfaces.
--

library ieee;
use ieee.std_logic_1164.all;

--==============================================================================
entity xc3s_uart is
--==============================================================================
    port (
        CLK_50M : in std_logic; -- 50Mhz clock
        ARST : in std_logic; -- BTN3
        -- UART full duplex lines
        UART_RX : in std_logic := '0'; -- TTL/RS232
        UART_TX : out std_logic; -- TTL/RS232
        UART_RX_A : in std_logic := '0'; -- TTL/RS232
        UART_TX_A : out std_logic; -- TTL/RS232
        -- Buttons
        BTN : in std_logic_vector(2 downto 0);
        -- Sliding switches
        SWT : in std_logic_vector(7 downto 0);
        -- LEDs, seven segment display
        LED : out std_logic_vector(7 downto 0);
        SSG_AN_n : out std_logic_vector(3 downto 0); -- Active low
        SSG_n : out std_logic_vector(6 downto 0); -- Active low
        SSG_DP_n : out std_logic -- Active low
    );
end entity xc3s_uart;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_1164.all;

--==============================================================================
architecture rtl of xc3s_uart is
--==============================================================================

constant RSTW : positive := 4; -- Reset delay shift width
constant NR_BITS : positive := 8;
constant RX_FIFO : positive := 8;
constant CCW : positive := 13; -- Clock counter width
constant RXFW : positive := positive(ceil(log2(real( RX_FIFO ))));

signal clk : std_logic := '0';
signal rst_n : std_logic := '0';
signal rst_delay : unsigned(RSTW-1 downto 0) := (others => '0');

signal uart1_rx_d : std_logic_vector(7 downto 0);
signal uart1_rx_dv : std_logic;
signal parity1_ok : std_logic;
signal uart1_tx_d : std_logic_vector(7 downto 0);
signal uart1_tx_dv : std_logic;
signal uart1_tx_dr : std_logic;

signal uart2_rx_d : std_logic_vector(7 downto 0);
signal uart2_rx_dv : std_logic;
signal parity2_ok : std_logic;
signal uart2_tx_d : std_logic_vector(7 downto 0);
signal uart2_tx_dv : std_logic;
signal uart2_tx_dr : std_logic;

signal uart_io_rx_d : unsigned(7 downto 0);
signal uart_io_rx_d_i : std_logic_vector(7 downto 0);
signal uart_io_rx_dv : std_logic;
signal uart_io_rx_dr : std_logic := '1';
signal parity_io_ok : std_logic;
signal rx_fifo_nz : std_logic;
signal uart_io_tx_d : std_logic_vector(7 downto 0) := (others => '0');
signal uart_io_tx_d_i : std_logic_vector(7 downto 0);
signal uart_io_tx_dv : std_logic := '0';
signal uart_io_tx_dr : std_logic;

signal clk_count : unsigned(CCW-1 downto 0) := (others => '0');

-- Seven segment anode driver
signal ssg_on : std_logic_vector(3 downto 0) := (others => '1'); -- all off.
signal ssg_dp : std_logic_vector(3 downto 0) := (others => '1'); -- all off.
signal ssg_an_sel : std_logic_vector(1 downto 0);
signal ssg_an_on : std_logic;

type SSG_ARRAY is array (0 to 15) of std_logic_vector(6 downto 0);
constant ssg_disp : SSG_ARRAY := (
    0  => "1000000", -- '0'
    1  => "1111001", -- '1'
    2  => "0100100", -- '2'
    3  => "0110000", -- '3'
    4  => "0011001", -- '4'
    5  => "0010010", -- '5'
    6  => "0000010", -- '6'
    7  => "1111000", -- '7'
    8  => "0000000", -- '8'
    9  => "0010000", -- '9'
    10 => "0001000", -- 'A'
    11 => "0000011", -- 'B'
    12 => "1000110", -- 'C'
    13 => "0100001", -- 'D'
    14 => "0000110", -- 'E'
    15 => "0001110"  -- 'F'
    );

type SSG_DIGIT_ARRAY is array (0 to 3) of std_logic_vector(3 downto 0);
signal ssg_digit : SSG_DIGIT_ARRAY;
signal ssg_digit_sel : std_logic_vector(3 downto 0);

signal u_rx_count : unsigned(RXFW downto 0) := (others => '0'); -- +1
signal u_rxd : std_logic_vector(7 downto 0);
signal u_rxd_cmd : std_logic_vector(7 downto 0) := (others => '0');
signal u_rxd_param : std_logic_vector(15 downto 0) := (others => '0');
signal u_txd : std_logic_vector(15 downto 0) := (others => '0');
signal u_tx_count : unsigned(2 downto 0) := (others => '0');
signal u_rx_end : std_logic := '0';
signal u_tx_enable : std_logic := '0';
signal u_rxd_0_9 : std_logic;
signal u_rxd_a_f : std_logic;
signal u_rxd_AF : std_logic;
signal u_txd_0_9 : std_logic;

constant CR : std_logic_vector(7 downto 0) := x"0D";

--==============================================================================
component uart is
--==============================================================================
    generic(
        CLK_FREQ : real;
        BAUD_RATE : real;
        NR_BITS : positive;
        PARITY : string;
        STOP_BITS : positive
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic;
        uart_rx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_rx_dv : out std_logic;
        parity_ok : out std_logic;
        uart_tx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_tx_dv : in std_logic;
        uart_tx_dr : out std_logic;
        uart_rx : in std_logic;
        uart_tx : out std_logic
    );
end component; -- uart

--==============================================================================
component uart_io is
--==============================================================================
    generic(
        PROMPT : string;
        NR_BITS : positive;
        SKIP_SPACE : natural;
        RX_FIFO : positive
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic;
        uart_io_rx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_io_rx_dv : out std_logic;
        uart_io_rx_dr : in std_logic;
        parity_io_ok : out std_logic;
        rx_fifo_nz : out std_logic;
        uart_io_tx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_io_tx_dv : in std_logic;
        uart_io_tx_dr : out std_logic;
        uart_rx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_rx_dv : in std_logic;
        parity_ok : in std_logic;
        uart_tx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_tx_dv : out std_logic;
        uart_tx_dr : in std_logic
    );
end component; -- uart_io

begin

uart1 : uart
    generic map(
        CLK_FREQ => 50.0E6, -- 50Mhz
        BAUD_RATE => 115.2E3, -- 115K2
        NR_BITS => NR_BITS,
        PARITY => "NONE",
        STOP_BITS => 1
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_rx_d => uart1_rx_d,
        uart_rx_dv => uart1_rx_dv,
        parity_ok => parity1_ok,
        uart_tx_d => uart1_tx_d,
        uart_tx_dv => uart1_tx_dv,
        uart_tx_dr => uart1_tx_dr,
        uart_rx => UART_RX,
        uart_tx => UART_TX
    );

uart2 : uart
    generic map(
        CLK_FREQ => 50.0E6, -- 50Mhz
        BAUD_RATE => 115.2E3, -- 115K2
        NR_BITS => NR_BITS,
        PARITY => "NONE",
        STOP_BITS => 1
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_rx_d => uart2_rx_d,
        uart_rx_dv => uart2_rx_dv,
        parity_ok => parity2_ok,
        uart_tx_d => uart2_tx_d,
        uart_tx_dv => uart2_tx_dv,
        uart_tx_dr => uart2_tx_dr,
        uart_rx => UART_RX,
        uart_tx => UART_TX
    );

console : uart_io
    generic map(
        PROMPT => "S3",
        NR_BITS => NR_BITS,
        SKIP_SPACE => 0,
        RX_FIFO => RX_FIFO
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_io_rx_d => uart_io_rx_d_i,
        uart_io_rx_dv => uart_io_rx_dv,
        uart_io_rx_dr => uart_io_rx_dr,
        parity_io_ok => parity_io_ok,
        rx_fifo_nz => rx_fifo_nz,
        uart_io_tx_d => uart_io_tx_d,
        uart_io_tx_dv => uart_io_tx_dv,
        uart_io_tx_dr => uart_io_tx_dr,
        uart_rx_d => uart1_rx_d,
        uart_rx_dv => uart1_rx_dv,
        parity_ok => parity1_ok,
        uart_tx_d => uart1_tx_d,
        uart_tx_dv => uart1_tx_dv,
        uart_tx_dr => uart1_tx_dr
    );

clk <= CLK_50M;
-- Could be "rst_n <= and( rst_delay )" when unary operator is supported!
rst_n <= '1' when rst_delay = (( 2 ** RSTW ) - 1 ) else '0';

--==============================================================================
synchronized_reset : process(clk, ARST) is begin
--==============================================================================
if ARST = '1' then
    rst_delay <= (others => '0');
elsif rising_edge(clk) then
    rst_delay <= rst_delay(RSTW-1 downto 1) & '1';
end if;
end process; -- synchronized_reset

--==============================================================================
clk_counter : process(clk) is begin
--==============================================================================
    clk_count <= clk_count + 1;
end process; -- clk_counter

uart_io_rx_d <= unsigned(uart_io_rx_d_i);

-- Seven segment anode driver
ssg_an_sel <= std_logic_vector(clk_count(CCW-1 downto CCW-2));
ssg_an_on <= ssg_on(to_integer(unsigned(ssg_an_sel)));
SSG_AN_n(0) <= '0' when ssg_an_sel = "00" else ssg_an_on;
SSG_AN_n(1) <= '0' when ssg_an_sel = "01" else ssg_an_on;
SSG_AN_n(2) <= '0' when ssg_an_sel = "10" else ssg_an_on;
SSG_AN_n(3) <= '0' when ssg_an_sel = "11" else ssg_an_on;
-- Seven segment decimal point decoder
SSG_DP_n <= ssg_dp(to_integer(unsigned(ssg_an_sel)));
-- Seven segment decoder
ssg_digit_sel <= ssg_digit(to_integer(unsigned(ssg_an_sel)));
SSG_n <= ssg_disp(to_integer(unsigned(ssg_digit_sel))) when
    ssg_dp(to_integer(unsigned(ssg_an_sel))) = '1' else (others => '1');

LED(0) <= uart2_rx_d(0) or ( not rst_n );
LED(3 downto 1) <= uart2_rx_d(3 downto 1);
LED(4) <= uart2_rx_d(4) or BTN(0);
LED(5) <= uart2_rx_d(5) or BTN(1);
LED(6) <= uart2_rx_d(6) or BTN(2);
LED(7) <= uart2_rx_d(7) or ARST;

u_rxd_0_9 <= '1' when (( uart_io_rx_d >= x"30" ) and ( uart_io_rx_d <= x"39" )) else '0'; -- >= "0" and <= "9"
u_rxd_a_f <= '1' when (( uart_io_rx_d >= x"61" ) and ( uart_io_rx_d <= x"66" )) else '0'; -- >= "a" and <= "f"
u_rxd_AF <= '1' when (( uart_io_rx_d >= x"41" ) and ( uart_io_rx_d <= x"46" )) else '0'; -- >= "A" and <= "F"
u_txd_0_9 <= '1' when unsigned(u_txd(15 downto 12)) < x"A" else '0';

uart_io_tx_d_i <= x"0" & u_txd(15 downto 12);

--==============================================================================
atoi_uart_rxd : process(u_rxd_0_9, u_rxd_a_f, u_rxd_AF) is begin
--==============================================================================
    u_rxd <= (others => '0');
    if u_rxd_0_9 = '1' then
        u_rxd <= std_logic_vector( uart_io_rx_d - x"30" );
    end if;
    if u_rxd_a_f = '1' then
        u_rxd <= std_logic_vector( uart_io_rx_d - x"61" + x"0A" );
    end if;
    if u_rxd_AF = '1' then
        u_rxd <= std_logic_vector( uart_io_rx_d - x"41" + x"0A" );
    end if;
end process; -- atoi_uart_rxd

--==============================================================================
uart_cmd : process(clk) is begin
--==============================================================================
if rising_edge(clk) then
    u_rx_end <= '0';
    if ( uart_io_rx_dv and uart_io_rx_dr ) = '1' then
        ssg_dp <= '0' & ssg_dp(3 downto 1);

        if ( u_rxd_0_9 or u_rxd_a_f or u_rxd_AF ) = '1' then
            ssg_on <= '0' & ssg_on(3 downto 1);
            ssg_dp <= '1' & ssg_dp(3 downto 1);

            if u_rx_count  = 0 then
                u_rxd_cmd(7 downto 4) <= u_rxd(3 downto 0); -- Set upper nibble
            end if;
            if u_rx_count  = 1 then
                u_rxd_cmd(7 downto 4) <= u_rxd(3 downto 0); -- Set lower nibble
            end if;
            if u_rx_count = 2 then
                u_rxd_param(15 downto 12) <= u_rxd(3 downto 0); -- Set upper nibble high byte word
            end if;
            if u_rx_count = 3 then
                u_rxd_param(11 downto 8) <= u_rxd(3 downto 0); -- Set lower nibble high byte word
            end if;
            if u_rx_count = 4 then
                u_rxd_param(7 downto 4) <= u_rxd(3 downto 0); -- Set upper nibble low byte word
            end if;
            if u_rx_count = 5 then
                u_rxd_param(3 downto 0) <= u_rxd(3 downto 0); -- Set lower nibble low byte word
            end if;

            u_rx_count <= u_rx_count + 1;
        end if;
        u_rx_end <= not rx_fifo_nz;
        -- Display UART RX 0..F
        ssg_digit(0) <= ssg_digit(1);
        ssg_digit(1) <= ssg_digit(2);
        ssg_digit(2) <= ssg_digit(3);
        ssg_digit(3) <= u_rxd(3 downto 0);
    end if;
    if u_rx_end = '1' then
        case u_rxd_cmd(7 downto 4) is
        when x"0" =>
            if u_rx_count = 1 then
                u_txd <= SWT & uart1_rx_d;
                u_tx_enable <= '1';
            end if;
            if u_rx_count = 5 then
                ssg_on <= (others => '1'); -- all off.
                u_txd <= u_rxd_param;
                u_tx_enable <= '1';
            end if;
        when others =>
        end case;
        u_rx_count <= (others => '0');
        u_tx_count <= (others => '0');
    end if;
    uart_io_tx_dv <= '0';
    if u_tx_enable = '1' then
        if ( uart_io_tx_dr and ( not uart_io_tx_dv )) = '1' then
            if u_txd_0_9 = '1' then
                uart_io_tx_d <= std_logic_vector( unsigned(uart_io_tx_d_i) + x"30" );
            else
                uart_io_tx_d <= std_logic_vector( unsigned(uart_io_tx_d_i) + x"41" - x"0A" );
            end if;
            uart_io_tx_dv <= '1';
            if u_tx_count = 4 then
                uart_io_tx_d <= CR;
                u_tx_enable <= '0';
            else
                u_tx_count <= u_tx_count + 1;
            end if;
            u_txd <= u_txd(11 downto 0) & x"0";
        end if;
    end if;
    if rst_n = '0' then
        uart_io_rx_dr <= '1';
        u_tx_enable <= '0';
    end if;
end if;
end process; -- uart_cmd

end architecture rtl; -- xc3s_uart
