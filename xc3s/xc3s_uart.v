/**
 *  Copyright (C) 2026, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: UART HW setup for Digilent Xilinx Spartan-3 Starter Kit
 *               (XC3S200-4FT256).
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "uart.xise.v"
// `include "..\uart_io.v"

/*============================================================================*/
module xc3s_uart(
/*============================================================================*/
    input  wire CLK_50M, // 50Mhz clock
    input  wire ARST, // BTN3
    // UART full duplex lines
    input wire UART_RX, // TTL/RS232
    output wire UART_TX, // TTL/RS232
    input wire UART_RX_A, // TTL/RS232
    output wire UART_TX_A, // TTL/RS232
    // Buttons
    input wire [2:0] BTN,
    // Sliding switches
    input wire [7:0] SWT,
    // LEDs, seven segment display
    output wire [7:0] LED,
    output wire [3:0] SSG_AN_n, // Active low
    output wire [6:0] SSG_n, // Active low
    output wire SSG_DP_n // Active low
    );

/*============================================================================*/
function integer clog2( input [31:0] value );
/*============================================================================*/
    reg [31:0] depth;
begin
    clog2 = 1; // Minimum bit width
    if ( value > 1 ) begin
        depth = value - 1;
        clog2 = 0;
        while ( depth > 0 ) begin
            depth = depth >> 1;
            clog2 = clog2 + 1;
        end
    end
end
endfunction // clog2

localparam RSTW = 4; // Reset delay shift width
localparam NR_BITS = 8;
localparam RX_FIFO = 8;

wire clk;
wire rst_n;
reg [RSTW-1:0] rst_delay = 0;

wire [7:0] uart1_rx_d;
wire uart1_rx_dv;
wire parity1_ok;
wire [7:0] uart1_tx_d;
wire uart1_tx_dv;
wire uart1_tx_dr;

uart #(
    .CLK_FREQ(50000000),
    .BAUD_RATE(115200),
    .NR_BITS(NR_BITS),
    .PARITY("NONE"),
    .STOP_BITS(1))
uart1(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart1_rx_d),
    .uart_rx_dv(uart1_rx_dv),
    .parity_ok(parity1_ok),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr),
    .uart_rx(UART_RX),
    .uart_tx(UART_TX)
    );

wire [7:0] uart2_rx_d;
wire uart2_rx_dv;
wire parity2_ok;

uart #(
    .CLK_FREQ(50000000),
    .BAUD_RATE(115200),
    .NR_BITS(NR_BITS),
    .PARITY("NONE"),
    .STOP_BITS(1))
uart2(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_d(uart2_rx_d),
    .uart_rx_dv(uart2_rx_dv),
    .parity_ok(parity2_ok),
    .uart_tx_d(uart1_rx_d),
    .uart_tx_dv(uart1_rx_dv),
    .uart_tx_dr(),
    .uart_rx(UART_RX_A),
    .uart_tx(UART_TX_A)
    );

wire [7:0] uart_io_rx_d;
wire uart_io_rx_dv;
reg uart_io_rx_dr = 1;
wire parity_io_ok;
wire rx_fifo_nz;
reg [7:0] uart_io_tx_d = 0;
reg uart_io_tx_dv = 0;
wire uart_io_tx_dr;

uart_io #(
    .PROMPT("XC3S>"),
    .NR_BITS(NR_BITS),
    .SKIP_SPACE(0),
    .RX_FIFO(RX_FIFO))
console (
    .clk(clk),
    .rst_n(rst_n),
    .uart_io_rx_d(uart_io_rx_d),
    .uart_io_rx_dv(uart_io_rx_dv),
    .uart_io_rx_dr(uart_io_rx_dr),
    .parity_io_ok(parity_io_ok),
    .rx_fifo_nz(rx_fifo_nz),
    .uart_io_tx_d(uart_io_tx_d),
    .uart_io_tx_dv(uart_io_tx_dv),
    .uart_io_tx_dr(uart_io_tx_dr),
    .uart_rx_d(uart1_rx_d),
    .uart_rx_dv(uart1_rx_dv),
    .parity_ok(parity1_ok),
    .uart_tx_d(uart1_tx_d),
    .uart_tx_dv(uart1_tx_dv),
    .uart_tx_dr(uart1_tx_dr)
    );

assign clk = CLK_50M;
assign rst_n = &rst_delay;

/*============================================================================*/
always @(posedge clk) begin : synchronized_reset
/*============================================================================*/
    rst_delay <= {rst_delay[RSTW-2:0], 1'b1};
    if ( ARST ) begin
        rst_delay <= 0;
    end
end // synchronized_reset

localparam CCW = 13;

reg [CCW-1:0] clk_count = 0;
/*============================================================================*/
always @(posedge clk) begin : clk_counter
/*============================================================================*/
    clk_count <= clk_count + 1;
end // clk_counter

reg [6:0] ssg_disp[0:15];
/*============================================================================*/
initial begin : init_seven_segment
/*============================================================================*/
    ssg_disp[0]  = 7'b1000000; // '0'
    ssg_disp[1]  = 7'b1111001; // '1'
    ssg_disp[2]  = 7'b0100100; // '2'
    ssg_disp[3]  = 7'b0110000; // '3'
    ssg_disp[4]  = 7'b0011001; // '4'
    ssg_disp[5]  = 7'b0010010; // '5'
    ssg_disp[6]  = 7'b0000010; // '6'
    ssg_disp[7]  = 7'b1111000; // '7'
    ssg_disp[8]  = 7'b0000000; // '8'
    ssg_disp[9]  = 7'b0010000; // '9'
    ssg_disp[10] = 7'b0001000; // 'A'
    ssg_disp[11] = 7'b0000011; // 'B'
    ssg_disp[12] = 7'b1000110; // 'C'
    ssg_disp[13] = 7'b0100001; // 'D'
    ssg_disp[14] = 7'b0000110; // 'E'
    ssg_disp[15] = 7'b0001110; // 'F'
end // init_seven_segment

// Seven segment anode driver
reg [3:0] ssg_on = 4'b1111; // 4'b1111 = all off.
wire [1:0] ssg_an_sel;
assign ssg_an_sel = clk_count[CCW-1:CCW-2];
wire ssg_an_on;
assign ssg_an_on = ssg_on[ssg_an_sel];
assign SSG_AN_n[0] = ssg_an_on | ~( ssg_an_sel == 2'd0 );
assign SSG_AN_n[1] = ssg_an_on | ~( ssg_an_sel == 2'd1 );
assign SSG_AN_n[2] = ssg_an_on | ~( ssg_an_sel == 2'd2 );
assign SSG_AN_n[3] = ssg_an_on | ~( ssg_an_sel == 2'd3 );
// Seven segment decimal point decoder
reg [3:0] ssg_dp = 4'b1111; // 4'b1111 = all off.
assign SSG_DP_n = ssg_dp[ssg_an_sel];
// Seven segment decoder
reg [3:0] ssg_digit[0:3];
wire [3:0] ssg_digit_sel;
assign ssg_digit_sel = ssg_digit[ssg_an_sel];
assign SSG_n = ssg_dp[ssg_an_sel] ? ssg_disp[ssg_digit_sel] : 7'h7F;

assign LED[0] = uart2_rx_d[0] | ~rst_n;
assign LED[3:1] = uart2_rx_d[3:1];
assign LED[4] = uart2_rx_d[4] | BTN[0];
assign LED[5] = uart2_rx_d[5] | BTN[1];
assign LED[6] = uart2_rx_d[6] | BTN[2];
assign LED[7] = uart2_rx_d[7] | ARST;

localparam RXFW = clog2( RX_FIFO );

reg [RXFW:0] u_rx_count = 0; // +1
reg [7:0] u_rxd;
reg [7:0] u_rxd_cmd = 0;
reg [15:0] u_rxd_param = 0;
reg [15:0] u_txd = 0;
reg [2:0] u_tx_count = 0;
reg u_rx_end = 0;
reg u_tx_enable = 0;

wire u_rxd_0_9;
assign u_rxd_0_9 = (( uart_io_rx_d >= "0" ) && ( uart_io_rx_d <= "9" ));
wire u_rxd_a_f;
assign u_rxd_a_f = (( uart_io_rx_d >= "a" ) && ( uart_io_rx_d <= "f" ));
wire u_rxd_A_F;
assign u_rxd_A_F = (( uart_io_rx_d >= "A" ) && ( uart_io_rx_d <= "F" ));
wire u_txd_0_9;
assign u_txd_0_9 = ( u_txd[15:12] < 4'hA );

/*============================================================================*/
always @(*) begin : atoi_uart_rxd
/*============================================================================*/
    u_rxd = 0;
    if ( u_rxd_0_9 ) begin
        u_rxd = uart_io_rx_d - "0";
    end
    if ( u_rxd_a_f ) begin
        u_rxd = uart_io_rx_d - "a" + 8'h0A;
    end
    if ( u_rxd_A_F ) begin
        u_rxd = uart_io_rx_d - "A" + 8'h0A;
    end
end // atoi_uart_rxd

localparam [7:0] CR = 8'h0D;

/*============================================================================*/
always @(posedge clk) begin : uart_cmd
/*============================================================================*/
    u_rx_end <= 0;
    if ( uart_io_rx_dv && uart_io_rx_dr ) begin
        ssg_dp <= {1'b0, ssg_dp[3:1]};

        if ( u_rxd_0_9 || u_rxd_a_f || u_rxd_A_F ) begin
            ssg_on <= {1'b0, ssg_on[3:1]};
            ssg_dp <= {1'b1, ssg_dp[3:1]};

            if ( 0 == u_rx_count ) begin
                u_rxd_cmd[7:4] <= u_rxd[3:0]; // Set upper nibble
            end
            if ( 1 == u_rx_count ) begin
                u_rxd_cmd[3:0] <= u_rxd[3:0]; // Set lower nibble
            end
            if ( 2 == u_rx_count ) begin
                u_rxd_param[15:12] <= u_rxd[3:0]; // Set upper nibble high byte word
            end
            if ( 3 == u_rx_count ) begin
                u_rxd_param[11:8] <= u_rxd[3:0]; // Set lower nibble high byte word
            end
            if ( 4 == u_rx_count ) begin
                u_rxd_param[7:4] <= u_rxd[3:0]; // Set upper nibble low byte word
            end
            if ( 5 == u_rx_count ) begin
                u_rxd_param[3:0] <= u_rxd[3:0]; // Set lower nibble low byte word
            end

            u_rx_count <= u_rx_count + 1;
        end
        u_rx_end <= ~rx_fifo_nz;
        // Display UART RX 0..F
        ssg_digit[0] <= ssg_digit[1];
        ssg_digit[1] <= ssg_digit[2];
        ssg_digit[2] <= ssg_digit[3];
        ssg_digit[3] <= u_rxd[3:0];
    end
    if ( u_rx_end ) begin
        case ( u_rxd_cmd[7:4] )
        4'h0 : begin
            if ( 1 == u_rx_count ) begin
                u_txd <= {SWT, uart1_rx_d};
                u_tx_enable <= 1;
            end
            if ( 5 == u_rx_count ) begin
                ssg_on <= 4'b1111; // 4'b1111 = all off.
                u_txd <= u_rxd_param;
                u_tx_enable <= 1;
            end
        end
        endcase
        u_rx_count <= 0;
        u_tx_count <= 0;
    end
    uart_io_tx_dv <= 0;
    if ( u_tx_enable ) begin
        if ( uart_io_tx_dr && !uart_io_tx_dv ) begin
            uart_io_tx_d <= {4'h0, u_txd[15:12]} + ( u_txd_0_9 ? "0" : ( "A" - 8'h0A ));
            uart_io_tx_dv <= 1;
            if ( 4 == u_tx_count ) begin
                uart_io_tx_d <= CR;
                u_tx_enable <= 0;
            end else begin
                u_tx_count <= u_tx_count + 1;
            end
            u_txd <= {u_txd[11:0], 4'h0};
        end
    end
    if ( !rst_n ) begin
        uart_io_rx_dr <= 1;
        u_tx_enable <= 0;
    end
end // uart_cmd

endmodule // xc3s_uart
