`default_nettype none
module top_uart #(parameter data_width = 8, baud_rate = 2400, clk_freq = 50000000)(sys_clk, sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH, uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_dataH, rec_busy, xmit_active);
  input wire sys_clk, sys_rst_l, xmitH, uart_REC_dataH;
  input wire [data_width - 1 : 0] xmit_dataH;
  output wire uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_busy, xmit_active;
  output wire [data_width - 1 : 0] rec_dataH;
  
  wire synch_in;
  wire baud_clk;
  synchronizer u4 (.clk(sys_clk), .rst(sys_rst_l), .sin(uart_REC_dataH), .sout(synch_in));
  baud_clk u3 #(.baud_rate(baud_rate), .clk_freq(clk_freq))(.clk(sys_clk), .rst(sys_rst_l), .clk_out(baud_clk));
  xmit u1 #(.data_width(data_width))(.baud_clk(baud_clk), .sys_rst_l(sys_rst_l), .xmitH(xmitH), .xmit_dataH(xmit_dataH), .uart_XMIT_dataH(uart_XMIT_dataH), .xmit_doneH(xmit_doneH), .xmit_active(xmit_active));
  rec u2 #(.data_width(data_width))(.clk(baud_clk), .rst(sys_rst_l), .data_in(synch_in), .rec_readyH(rec_readyH), .rec_dataH(rec_dataH), .rec_busyH(rec_busy));

endmodule
