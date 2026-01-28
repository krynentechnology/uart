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
--  Description: UART - IO, terminal (console) interaction, XON/XOFF enabled!
--

library ieee;
use ieee.std_logic_1164.all;

--==============================================================================
entity uart_io is
--==============================================================================
    generic(
        PROMPT : string := "FDK>"; -- Fpga Development Kit prompt
        NR_BITS : positive range 2 to 16 := 8;
        SKIP_SPACE : natural range 0 to 1 := 0;
        RX_FIFO : positive := 8
    );
    port (
        clk : in std_logic;
        rst_n : in std_logic; -- High when clock stable!
        -- UART IO RX
        uart_io_rx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_io_rx_dv : out std_logic;
        uart_io_rx_dr : in std_logic;
        parity_io_ok : out std_logic;
        rx_fifo_nz : out std_logic; -- RX FIFO input non zero
        -- UART IO TX
        uart_io_tx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_io_tx_dv : in std_logic;
        uart_io_tx_dr : out std_logic;
        -- UART RX
        uart_rx_d : in std_logic_vector(NR_BITS-1 downto 0);
        uart_rx_dv : in std_logic;
        parity_ok : in std_logic;
        -- UART TX
        uart_tx_d : out std_logic_vector(NR_BITS-1 downto 0);
        uart_tx_dv : out std_logic;
        uart_tx_dr : in std_logic
    );
end uart_io;

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_1164.all;

--==============================================================================
architecture rtl of uart_io is
--==============================================================================
function CHECK_PARAMETERS return boolean is begin
--==============================================================================
    assert ( RX_FIFO > 1 ) report "RX_FIFO < 2!" severity failure;
    assert ( NR_BITS = 8 ) report "NR_BITS = 8 expected for console interaction!" severity failure;
    return true;
end function; -- CHECK_PARAMETERS

constant PARAMETERS_OK : boolean := CHECK_PARAMETERS;

constant BS : std_logic_vector(7 downto 0) := x"08";
constant CR : std_logic_vector(7 downto 0) := x"0D";
constant LF : std_logic_vector(7 downto 0) := x"0A";
constant XON : std_logic_vector(7 downto 0) := x"11";
constant XOFF : std_logic_vector(7 downto 0) := x"13";
constant SPACE : std_logic_vector(7 downto 0) := x"20";
constant PROMPT_SIZE : positive := PROMPT'length;
constant TX_PROMPT_SIZE : positive := PROMPT_SIZE + 1; -- +LF
constant RXFW : positive := positive(ceil(log2(real( RX_FIFO ))));

--==============================================================================
function TX_COUNTER_WIDTH return positive is begin
--==============================================================================
    if RX_FIFO > TX_PROMPT_SIZE then
        return RXFW;
    else
        return positive(ceil(log2(real( TX_PROMPT_SIZE ))));
    end if;
end function; -- TX_COUNTER_WIDTH

constant TXCW : positive := TX_COUNTER_WIDTH;

type FIFO_ARRAY is array (0 to RX_FIFO-1) of std_logic_vector(7 downto 0);

signal uart_io_rx_d_i : std_logic_vector(NR_BITS-1 downto 0) := (others => '0');
signal uart_io_rx_dv_i : std_logic := '0';
signal parity_io_ok_i : std_logic := '0';
signal rx_fifo_nz_i : std_logic;
signal uart_io_tx_dr_i : std_logic;
signal uart_tx_d_i : std_logic_vector(NR_BITS-1 downto 0) := (others => '0');
signal uart_tx_dv_i : std_logic := '0';

signal fifo : FIFO_ARRAY;
signal rx_count : unsigned(RXFW downto 0) := (others => '0'); -- +1
signal rx_enable : std_logic := '0';
signal tx_count : unsigned(TXCW downto 0) := (others => '0'); -- +1
signal tx_prompt : std_logic := '0';
signal tx_bs : std_logic := '0';
signal tx_space : std_logic := '0';
signal tx_xon : std_logic := '0';

type PROMPT_ARRAY is array (0 to TX_PROMPT_SIZE-1) of std_logic_vector(7 downto 0);

--==============================================================================
function INIT_PROMPT return PROMPT_ARRAY is
--==============================================================================
    variable p : PROMPT_ARRAY;
    variable c : integer;
begin
    p(0) := LF;
    for i in 1 to PROMPT'length loop
        c := character'pos( PROMPT(i) );
        p(i) := std_logic_vector(to_unsigned( c, NR_BITS ));
    end loop;
    return p;
end function; -- INIT_PROMPT

constant CON_PROMPT : PROMPT_ARRAY := INIT_PROMPT;

begin

uart_io_rx_d <= uart_io_rx_d_i;
uart_io_rx_dv <= uart_io_rx_dv_i;
parity_io_ok <= parity_io_ok_i;
rx_fifo_nz_i <= '1' when rx_count > 0 else '0';
rx_fifo_nz <= rx_fifo_nz_i;
uart_io_tx_dr_i <= uart_tx_dr and tx_xon and not ( tx_prompt or tx_space or tx_bs );
uart_io_tx_dr <= uart_io_tx_dr_i;
uart_tx_d <= uart_tx_d_i;
uart_tx_dv <= uart_tx_dv_i;

--==============================================================================
uart_handler : process (clk) is begin
--==============================================================================
if rising_edge(clk) then
    uart_io_rx_dv_i <= '0';
    uart_tx_dv_i <= '0';
    if uart_rx_dv = '1' then
        uart_tx_d_i <= uart_rx_d; -- Echo RX!
        -- Could be "or( uart_rx_d(7 downto 5)) = '1'" when supported!
        if uart_rx_d(7 downto 5) /= "000" then -- uart_rx_d >= 8'h20
            if not (( SKIP_SPACE = 1 ) and ( SPACE( 4 downto 0 ) = uart_rx_d( 4 downto 0 ))) then
                if rx_count < RX_FIFO then
                    fifo(to_integer(rx_count)) <= uart_rx_d;
                    rx_count <= rx_count + 1;
                end if;
            end if;
            uart_tx_dv_i <= '1';
        end if;
        if uart_rx_d = BS then
            if rx_fifo_nz_i = '1' then
                rx_count <= rx_count - 1;
                uart_tx_dv_i <= '1';
                tx_space <= '1';
            end if;
        end if;
        if uart_rx_d = CR then
            rx_enable <= '1';
            tx_prompt <= '1'; -- LF in included by prompt!
            tx_count <= (others => '0');
            uart_tx_dv_i <= '1';
        end if;
        if uart_rx_d = XON then
            tx_xon <= '1';
        end if;
        if uart_rx_d = XOFF then
            tx_xon <= '0';
        end if;
        if rx_fifo_nz_i = '1' then
            parity_io_ok_i <= parity_io_ok_i and parity_ok;
        else    
            parity_io_ok_i <= parity_ok;
        end if;    
    elsif uart_io_rx_dr = '1' then
        if rx_fifo_nz_i = '1' then
            if rx_enable = '1' then
                uart_io_rx_d_i <= fifo(0);
                uart_io_rx_dv_i <= '1';
                for i in 0 to ( RX_FIFO - 2 ) loop
                    fifo(i) <= fifo(i+1);
                end loop;
                rx_count <= rx_count - 1;
            end if;
        else
            rx_enable <= '0'; -- RX FIFO empty
        end if;
    end if;
    if uart_tx_dr = '1' then
        if tx_prompt = '1' then
            uart_tx_d_i <= CON_PROMPT(to_integer(tx_count));
            uart_tx_dv_i <= '1';
            if tx_count = ( TX_PROMPT_SIZE - 1 ) then
                tx_prompt <= '0'; -- Stop TX prompt
            else
                tx_count <= tx_count + 1;
            end if;
        end if;
        if tx_space = '1' then
            tx_space <= '0';
            tx_bs <= '1';
            uart_tx_d_i <= SPACE;
            uart_tx_dv_i <= '1';
        end if;
        if tx_bs = '1' then
            tx_bs <= '0';
            uart_tx_d_i <= BS;
            uart_tx_dv_i <= '1';
        end if;
        if ( uart_io_tx_dr_i and uart_io_tx_dv ) = '1' then
            uart_tx_d_i <= uart_io_tx_d;
            uart_tx_dv_i <= '1';
            if uart_io_tx_d = CR then
                tx_prompt <= '1'; -- LF in included by prompt!
                tx_count <= (others => '0');
            end if;
        end if;
    end if;
    if rst_n = '0' then
        rx_count <= (others => '0');
        rx_enable <= '0';
        tx_count <= (others => '0');
        tx_prompt <= '0';
        tx_bs <= '0';
        tx_space <= '0';
        tx_xon <= '1';
    end if;
end if;
end process; -- uart_handler

end architecture rtl; -- uart_io
