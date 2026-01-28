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
-- Description: UART library
--

library ieee;
use ieee.std_logic_1164.all;

--==============================================================================
package uart_pkg is
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

end package uart_pkg;
