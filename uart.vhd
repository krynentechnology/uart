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
-- Description: UART - Universal Asynchronous Receiver Transmitter
--
-- https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter
--

library ieee;
use ieee.std_logic_1164.all;

--==============================================================================
entity uart is
--==============================================================================
    generic(
        CLK_FREQ : real := 100.0E6;
        BAUD_RATE : real := 115.2E6;
        NR_BITS : positive range 2 to 16 := 8;
        PARITY : string := "NONE"; -- Or "EVEN", "ODD"
        STOP_BITS : positive range 1 to 2 := 1
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic; -- High when clock stable!
        -- RX
        uart_rx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_rx_dv : out std_logic;
        parity_ok : out std_logic;
        -- TX
        uart_tx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_tx_dv : in std_logic;
        uart_tx_dr : out std_logic;
        -- UART full duplex lines
        uart_rx : in std_logic;
        uart_tx : out std_logic
    );
end uart;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_1164.all;

--==============================================================================
architecture rtl of uart is
--==============================================================================
function CHECK_PARAMETERS return boolean is begin
--==============================================================================
    assert (( BAUD_RATE >= 50.0 ) and ( CLK_FREQ >= 200.0 ) and (( CLK_FREQ / BAUD_RATE ) >= 4.0 )) report "BAUD_RATE < 50.0 or CLK_FREQ < 200.0 or ( CLK_FREQ / BAUD_RATE ) < 4.0!" severity failure;
    assert (( NR_BITS >= 2 ) and ( NR_BITS <= 16 )) report "NR_BITS < 2 or NR_BITS > 16!" severity failure;
    assert (( "NONE" = PARITY ) or ( "EVEN" = PARITY ) or ( "ODD" = PARITY )) report "PARITY not defined!" severity failure;
    assert (( 1 = STOP_BITS ) or ( 2 = STOP_BITS )) report "STOP_BITS < 1 or STOP_BITS > 2!" severity failure;
    return true;
end function; -- CHECK_PARAMETERS

constant PARAMETERS_OK : boolean := CHECK_PARAMETERS;

--==============================================================================
function get_parity_bits( parity : string ) return natural is begin
--==============================================================================
    if parity = "NONE" then
        return 0;
    end if;
    return 1;
end function; -- get_parity_bits

--==============================================================================
function xor_data( data : std_logic_vector ) return std_logic is
--==============================================================================
    variable xor_bits : std_logic := data(0);
begin
    for i in 1 to ( data'length - 1 ) loop
        xor_bits := xor_bits xor data(i);
    end loop;
    return xor_bits;
end function; -- xor_data

constant START_BITS : positive range 1 to 1 := 1;
constant PARITY_BITS : natural range 0 to 1 := get_parity_bits( PARITY );
constant START_STOP_WIDTH : positive range 4 to 20 := START_BITS + NR_BITS + PARITY_BITS + STOP_BITS;
constant STSTW : positive range 1 to 5 := positive(ceil(log2(real( START_STOP_WIDTH ))));
constant CLK_DIV_BAUD : positive := positive( CLK_FREQ / BAUD_RATE );
constant CLK_COUNT_WIDTH : positive := positive(ceil(log2(real( CLK_DIV_BAUD ))));
constant CLKW : positive := CLK_COUNT_WIDTH;
constant RX_SAMPLE : positive := ( CLK_DIV_BAUD / 2 ) - 1;

signal uart_rx_d_i : std_logic_vector(NR_BITS-1 downto 0) := (others => '0');
signal uart_rx_dv_i : std_logic := '0';
signal parity_ok_i : std_logic := '0';
signal uart_rx_i : std_logic_vector(1 downto 0) := (others => '1');
signal rx_clk_count : unsigned(CLKW-1 downto 0) := (others => '0');
signal rx_bit_count : unsigned(STSTW-1 downto 0) := (others => '0');
signal xor_uart_rx_d_i : std_logic;
signal uart_rx_eq_xor : std_logic;

signal uart_tx_i : std_logic := '1';
signal tx_clk_count : unsigned(CLKW-1 downto 0) := (others => '0');
signal tx_bit_count : unsigned(STSTW-1 downto 0) := (others => '0');
signal uart_tx_d_i : unsigned(NR_BITS-1 downto 0) := (others => '0');
signal uart_tx_dr_i : std_logic := '1';
signal tx_d_parity : std_logic := '0';
signal xor_uart_tx_d : std_logic;

begin

uart_rx_d <= uart_rx_d_i;
uart_rx_dv <= uart_rx_dv_i;
parity_ok <= parity_ok_i;
xor_uart_rx_d_i <= xor_data( uart_rx_d_i );
-- Could be "uart_rx_eq_xor <= uart_rx and xor( uart_rx_d_i );" when supported!
uart_rx_eq_xor <= '1' when ( uart_rx = xor_uart_rx_d_i ) else '0';

--==============================================================================
process_rx : process (clk) is begin
--==============================================================================
if rising_edge(clk) then
    uart_rx_i <= uart_rx_i(0) & uart_rx;
    rx_clk_count <= rx_clk_count + 1;
    uart_rx_dv_i <= '0';
    if CLK_DIV_BAUD = rx_clk_count then
        rx_clk_count <= (others => '0');
    end if;
    if ( rx_bit_count = 0 ) and ( uart_rx_i = "10" ) then
        rx_clk_count <= (others => '0');
    elsif rx_clk_count = RX_SAMPLE then
        if ( rx_bit_count = 0 ) and ( uart_rx = '0' ) then
            rx_bit_count <= to_unsigned( 1, rx_bit_count'length ); -- Start bit
        end if;
        if rx_bit_count > 0 then
            rx_bit_count <= rx_bit_count + 1;
            if rx_bit_count <= NR_BITS then
                uart_rx_d_i <= uart_rx & uart_rx_d_i(NR_BITS-1 downto 1);
            end if;
            if rx_bit_count = ( NR_BITS + 1 ) then
                uart_rx_dv_i <= '1';
                if "EVEN" = PARITY then -- Conditional synthesis!
                    parity_ok_i <= uart_rx_eq_xor;
                elsif "ODD" = PARITY then -- Conditional synthesis!
                    parity_ok_i <= not uart_rx_eq_xor;
                end if;
                rx_bit_count <= (others => '0');
            end if;
        end if;
    end if;
    if rst_n = '0' then
        uart_rx_i <= (others => '1');
        uart_rx_d_i <= (others => '0');
        uart_rx_dv_i <= '0';
        rx_clk_count <= (others => '0');
    end if;
end if;
end process; -- process_rx

xor_uart_tx_d <= xor_data( uart_tx_d );
uart_tx_dr <= uart_tx_dr_i and not uart_tx_dv;
uart_tx <= uart_tx_i;

--==============================================================================
process_tx : process (clk) is begin
--==============================================================================
if rising_edge(clk) then
    tx_clk_count <= tx_clk_count + 1;
    if tx_clk_count = CLK_DIV_BAUD then
        tx_clk_count <= (others => '0');
        if tx_bit_count = START_STOP_WIDTH then
            tx_bit_count <= (others => '0');
            uart_tx_dr_i <= '1';
        end if;
    end if;
    if ( uart_tx_dv and uart_tx_dr_i ) = '1' then
        uart_tx_dr_i <= '0';
        uart_tx_d_i <= unsigned( uart_tx_d );
        if "EVEN" = PARITY then -- Conditional synthesis!
            tx_d_parity <= xor_uart_tx_d;
        elsif "ODD" = PARITY then -- Conditional synthesis!
            tx_d_parity <= not xor_uart_tx_d;
        end if;
        tx_clk_count <= (others => '0');
        tx_bit_count <= (others => '0');
        uart_tx_i <= '1';
    end if;
    if uart_tx_dr_i = '0' then
        if tx_clk_count = 0 then
            tx_bit_count <= tx_bit_count + 1;
            uart_tx_i <= '1';
            if tx_bit_count = 0 then
                uart_tx_i <= '0'; -- Start bit
            elsif tx_bit_count <= NR_BITS then
                uart_tx_i <= uart_tx_d_i(0);
                uart_tx_d_i <= shift_right( uart_tx_d_i, 1 );
            end if;
            if tx_bit_count = ( NR_BITS + 1 ) then
                if "NONE" /= PARITY then -- Conditional synthesis!
                    uart_tx_i <= tx_d_parity;
                end if;
            end if;
        end if;
    end if;
    if rst_n = '0' then
        uart_tx_i <= '1';
        uart_tx_d_i <= (others => '0');
        uart_tx_dr_i <= '1';
    end if;
end if;
end process; -- process_tx

end architecture rtl; -- uart
