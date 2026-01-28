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
--  License: GPL, v3, as defined and found on www.gnu.org,
--           https://www.gnu.org/licenses/gpl-3.0.html
--
--  Description: UART test bench.
--

entity uart_tb is
end entity uart_tb;

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.uart_pkg.all; -- Dependencies

--==============================================================================
architecture behavior of uart_tb is
--==============================================================================

signal clk : std_logic := '0';
signal rst_n : std_logic := '0';

constant NR_BITS_1 : positive := 8;

signal uart1_rx_d : std_logic_vector(NR_BITS_1-1 downto 0);
signal uart1_rx_dv : std_logic;
signal parity1_ok : std_logic;
signal rx1_data : std_logic_vector(NR_BITS_1-1 downto 0) := (others => '0');
signal uart1_tx_d : std_logic_vector(NR_BITS_1-1 downto 0) := (others => '0');
signal uart1_tx_dv : std_logic := '0';
signal uart1_tx_dr : std_logic;
signal uart1_rx : std_logic;
signal uart1_tx : std_logic;

constant NR_BITS_2 : positive := 7;

signal uart2_rx_d : std_logic_vector(NR_BITS_2-1 downto 0);
signal uart2_rx_dv : std_logic;
signal parity2_ok : std_logic;
signal rx2_data : std_logic_vector(NR_BITS_2-1 downto 0) := (others => '0');
signal uart2_tx_d : std_logic_vector(NR_BITS_2-1 downto 0) := (others => '0');
signal uart2_tx_dv : std_logic := '0';
signal uart2_tx_dr : std_logic;
signal uart2_rx : std_logic;
signal uart2_tx : std_logic;

constant NR_BITS_3 : positive := 12;

signal uart3_rx_d : std_logic_vector(NR_BITS_3-1 downto 0);
signal uart3_rx_dv : std_logic;
signal parity3_ok : std_logic;
signal rx3_data : std_logic_vector(NR_BITS_3-1 downto 0) := (others => '0');
signal uart3_tx_d : std_logic_vector(NR_BITS_3-1 downto 0) := (others => '0');
signal uart3_tx_dv : std_logic := '0';
signal uart3_tx_dr : std_logic;
signal uart3_rx : std_logic;
signal uart3_tx : std_logic;

signal uart4_rx_d : std_logic_vector(NR_BITS_1-1 downto 0);
signal uart4_rx_dv : std_logic;
signal parity4_ok : std_logic;
signal uart4_tx_d : std_logic_vector(NR_BITS_1-1 downto 0) := (others => '0');
signal uart4_tx_dv : std_logic := '0';
signal uart4_tx_dr : std_logic;
signal uart4_rx : std_logic;
signal uart4_tx : std_logic;
signal uart_tx4_rx1 : std_logic := '0';

signal uart4_io_rx_d : std_logic_vector(NR_BITS_1-1 downto 0);
signal uart4_io_rx_dv : std_logic;
signal uart4_io_rx_dr : std_logic := '0';
signal parity4_io_ok : std_logic;
signal rx_fifo_nz : std_logic;
signal uart4_io_tx_d : std_logic_vector(NR_BITS_1-1 downto 0) := (others => '0');
signal uart4_io_tx_dv : std_logic := '0';
signal uart4_io_tx_dr : std_logic;

begin

uart1_rx <= uart4_tx when uart_tx4_rx1 ='1' else uart1_tx;

uart1 : uart
    generic map(
        CLK_FREQ => 250.0,
        BAUD_RATE => 50.0,
        NR_BITS => NR_BITS_1,
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
        uart_rx => uart1_rx,
        uart_tx => uart1_tx
    );

uart2_rx <= uart2_tx;

uart2 : uart
    generic map(
        CLK_FREQ => 250.0,
        BAUD_RATE => 50.0,
        NR_BITS => NR_BITS_2,
        PARITY => "EVEN",
        STOP_BITS => 2
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
        uart_rx => uart2_rx,
        uart_tx => uart2_tx
    );

uart3_rx <= uart3_tx;

uart3 : uart
    generic map(
        CLK_FREQ => 250.0,
        BAUD_RATE => 50.0,
        NR_BITS => NR_BITS_3,
        PARITY => "ODD",
        STOP_BITS => 1
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_rx_d => uart3_rx_d,
        uart_rx_dv => uart3_rx_dv,
        parity_ok => parity3_ok,
        uart_tx_d => uart3_tx_d,
        uart_tx_dv => uart3_tx_dv,
        uart_tx_dr => uart3_tx_dr,
        uart_rx => uart3_rx,
        uart_tx => uart3_tx
    );

uart4_rx <= uart1_tx; -- Input UART1 TX!

uart4 : uart
    generic map(
        CLK_FREQ => 250.0,
        BAUD_RATE => 50.0,
        NR_BITS => NR_BITS_1,
        PARITY => "NONE",
        STOP_BITS => 1
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_rx_d => uart4_rx_d,
        uart_rx_dv => uart4_rx_dv,
        parity_ok => parity4_ok,
        uart_tx_d => uart4_tx_d,
        uart_tx_dv => uart4_tx_dv,
        uart_tx_dr => uart4_tx_dr,
        uart_rx => uart4_rx,
        uart_tx => uart4_tx
    );

console : uart_io
    generic map(
        PROMPT => "C10LP",
        NR_BITS => NR_BITS_1,
        SKIP_SPACE => 0,
        RX_FIFO => 8
    )
    port map(
        clk => clk,
        rst_n => rst_n,
        uart_io_rx_d => uart4_io_rx_d,
        uart_io_rx_dv => uart4_io_rx_dv,
        uart_io_rx_dr => uart4_io_rx_dr,
        parity_io_ok => parity4_io_ok,
        rx_fifo_nz => rx_fifo_nz,
        uart_io_tx_d => uart4_io_tx_d,
        uart_io_tx_dv => uart4_io_tx_dv,
        uart_io_tx_dr => uart4_io_tx_dr,
        uart_rx_d => uart4_rx_d,
        uart_rx_dv => uart4_rx_dv,
        parity_ok => parity4_ok,
        uart_tx_d => uart4_tx_d,
        uart_tx_dv => uart4_tx_dv,
        uart_tx_dr => uart4_tx_dr
    );

-- clock signals and reset
clk <= not clk after 5 ns; -- 100 MHz clock
rst_n <= '0', '1' after 100 ns;

--==============================================================================
rx1_data_collect : process(clk) is begin
--==============================================================================
if rising_edge(clk) then
    if uart1_rx_dv = '1' then
        rx1_data <= uart1_rx_d;
    end if;
end if;
end process; -- rx1_data_collect

--==============================================================================
rx2_data_collect : process(clk) is begin
--==============================================================================
if rising_edge(clk) then
    if uart2_rx_dv = '1' then
        rx2_data <= uart2_rx_d;
    end if;
end if;
end process; -- rx2_data_collect

--==============================================================================
rx3_data_collect : process(clk) is begin
--==============================================================================
if rising_edge(clk) then
    if uart3_rx_dv = '1' then
        rx3_data <= uart3_rx_d;
    end if;
end if;
end process; -- rx3_data_collect

--==============================================================================
test : process is
--==============================================================================
procedure uart_write(
--==============================================================================
      uart : in integer;
      uart_d : in std_logic_vector(NR_BITS_3-1 downto 0)) is
begin
    if uart = 1 then
        if uart1_tx_dr = '0' then
            wait until uart1_tx_dr = '1';
        end if;
        wait until falling_edge(clk);
        uart1_tx_d <= uart_d(NR_BITS_1-1 downto 0);
        uart1_tx_dv <= '1';
        wait until uart1_tx_dr = '0' ;
        wait until falling_edge(clk);
        uart1_tx_dv <= '0';
    end if;
    if uart = 2 then
        if uart2_tx_dr = '0' then
            wait until uart2_tx_dr = '1';
        end if;
        wait until falling_edge(clk);
        uart2_tx_d <= uart_d(NR_BITS_2-1 downto 0);
        uart2_tx_dv <= '1';
        wait until uart2_tx_dr = '0';
        wait until falling_edge(clk);
        uart2_tx_dv <= '0';
    end if;
    if uart = 3 then
        if uart3_tx_dr = '0' then
            wait until uart3_tx_dr = '1';
        end if;
        wait until falling_edge(clk);
        uart3_tx_d <= uart_d;
        uart3_tx_dv <= '1';
        wait until uart3_tx_dr = '0';
        wait until falling_edge(clk);
        uart3_tx_dv <= '0';
    end if;
    if uart = 4 then
        if uart4_io_tx_dr = '0' then
            wait until uart4_io_tx_dr= '1';
        end if;
        wait until falling_edge(clk);
        uart4_io_tx_d <= uart_d(NR_BITS_1-1 downto 0);
        uart4_io_tx_dv <= '1';
        wait until uart4_io_tx_dr = '0';
        wait until falling_edge(clk);
        uart4_io_tx_dv <= '0';
    end if;
end procedure; -- uart_write

begin
    uart_tx4_rx1 <= '0';
    uart4_io_rx_dr <= '1';
    wait until rst_n = '1';
    report "UART simulation started";
    uart_write( 1, x"081" );
    uart_write( 1, x"05A" );
    uart_write( 1, x"0A5" );
    uart_write( 1, x"081" );
    uart_write( 1, x"000" );
    ----------------------
    uart_write( 2, x"041" );
    uart_write( 2, x"05A" );
    uart_write( 2, x"025" );
    uart_write( 2, x"041" );
    uart_write( 2, x"000" );
    ----------------------
    uart_write( 3, x"801" );
    uart_write( 3, x"A5A" );
    uart_write( 3, x"5A5" );
    uart_write( 3, x"801" );
    uart_write( 3, x"000" );
    ----------------------
    uart_tx4_rx1 <= '1';
    uart4_io_rx_dr <= '0';
    uart_write( 1, x"081" );
    uart_write( 1, x"05A" );
    uart_write( 1, x"0A5" );
    uart_write( 1, x"081" );
    uart_write( 1, x"000" );
    uart_write( 1, x"00A" ); -- LF
    wait for 5000 ns;
    uart4_io_rx_dr <= '1';
    wait for 4000 ns;
    uart_write( 4, x"0FF" );
    wait for 1000 ns;
    ----------------------
    assert false report "Simulation finished, ignore failure message!" severity failure;
end process;

end architecture behavior; -- uart_tb
