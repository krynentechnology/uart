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
--  Description: UART HW setup for Cyclone 10 LP Evaluation Kit
--               (10CL025YU256I7G)
--

library ieee;
use ieee.std_logic_1164.all;

--==============================================================================
entity c10lp_uart is
--==============================================================================
    port (
        CLK1_100M : in std_logic; -- 100Mhz LVDS clock
        ARST_n : in std_logic;
        -- UART full duplex lines
        UART_RX : in std_logic := '0'; -- TTL J18.3
        UART_TX : out std_logic; -- // TTL J18.4
        -- LEDs,
        LED_n : out std_logic_vector(3 downto 0);
        PB : in std_logic_vector(3 downto 0); -- Push button
        DIP_SW : in std_logic_vector(2 downto 0) -- Dip switch
    );
end entity c10lp_uart;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_1164.all;

library work;
use work.uart_pkg.all; -- Dependencies

--==============================================================================
architecture rtl of c10lp_uart is
--==============================================================================

constant RSTW : positive := 4; -- Reset delay shift width
constant NR_BITS : positive := 8;
constant RX_FIFO : positive := 8;
constant CCW : positive := 13; -- Clock counter width
constant RXFW : positive := positive(ceil(log2(real( RX_FIFO ))));

signal clk : std_logic := '0';
signal rst_n : std_logic := '0';
signal rst_delay : unsigned(RSTW-1 downto 0) := (others => '0');

signal uart_rx_d : std_logic_vector(7 downto 0);
signal uart_rx_dv : std_logic;
signal parity_ok : std_logic;
signal uart_tx_d : std_logic_vector(7 downto 0);
signal uart_tx_dv : std_logic;
signal uart_tx_dr : std_logic;

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

begin

uart_ttl : uart
    generic map(
        CLK_FREQ => 100.0E6, -- 100Mhz
        BAUD_RATE => 115.2E3, -- 115K2
        NR_BITS => NR_BITS,
        PARITY => "NONE",
        STOP_BITS => 1
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_rx_d => uart_rx_d,
        uart_rx_dv => uart_rx_dv,
        parity_ok => parity_ok,
        uart_tx_d => uart_tx_d,
        uart_tx_dv => uart_tx_dv,
        uart_tx_dr => uart_tx_dr,
        uart_rx => UART_RX,
        uart_tx => UART_TX
    );

console : uart_io
    generic map(
        PROMPT => "C10LP>",
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
        uart_rx_d => uart_rx_d,
        uart_rx_dv => uart_rx_dv,
        parity_ok => parity_ok,
        uart_tx_d => uart_tx_d,
        uart_tx_dv => uart_tx_dv,
        uart_tx_dr => uart_tx_dr
    );

clk <= CLK1_100M;
-- Could be "rst_n <= and( rst_delay )" when unary operator is supported!
rst_n <= '1' when rst_delay = (( 2 ** RSTW ) - 1 ) else '0';

--==============================================================================
synchronized_reset : process(clk, ARST_n) is begin
--==============================================================================
if ARST_n = '0' then
    rst_delay <= (others => '0');
elsif rising_edge(clk) then
    rst_delay <= rst_delay(RSTW-2 downto 0) & '1';
end if;
end process; -- synchronized_reset

--==============================================================================
clk_counter : process(clk) is begin
--==============================================================================
if rising_edge(clk) then
    clk_count <= clk_count + 1;
end if;
end process; -- clk_counter

LED_n <= uart_rx_d(3 downto 0) or PB;

u_rxd_0_9 <= '1' when (( uart_io_rx_d >= x"30" ) and ( uart_io_rx_d <= x"39" )) else '0'; -- >= "0" and <= "9"
u_rxd_a_f <= '1' when (( uart_io_rx_d >= x"61" ) and ( uart_io_rx_d <= x"66" )) else '0'; -- >= "a" and <= "f"
u_rxd_AF <= '1' when (( uart_io_rx_d >= x"41" ) and ( uart_io_rx_d <= x"46" )) else '0'; -- >= "A" and <= "F"
u_txd_0_9 <= '1' when unsigned(u_txd(15 downto 12)) < x"A" else '0';

uart_io_rx_d <= unsigned(uart_io_rx_d_i);
uart_io_tx_d_i <= x"0" & u_txd(15 downto 12);

--==============================================================================
atoi_uart_rxd : process(uart_io_rx_d, u_rxd_0_9, u_rxd_a_f, u_rxd_AF) is begin
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
        if ( u_rxd_0_9 or u_rxd_a_f or u_rxd_AF ) = '1' then
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
    end if;
    if u_rx_end = '1' then
        case u_rxd_cmd(7 downto 4) is
        when x"0" =>
            if u_rx_count = 1 then
                u_txd <= uart_rx_d & uart_io_tx_d;
                u_tx_enable <= '1';
            end if;
            if u_rx_count = 5 then
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

end architecture rtl; -- c10lp_uart
