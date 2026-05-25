`default_nettype none
module baud_clk #(parameter baud_rate = 2400, clk_freq = 50000000)(clk, rst, clk_out);
  input wire clk, rst;
  output reg clk_out;
    
  localparam max = clk_freq / (baud_rate * 16 * 2); // Calculate the number of system clock cycles for half a baud period at 16x oversampling

  reg [$clog2(max) - 1 : 0] cnt;
  
  always @(posedge clk or negedge rst) begin
  
    if(!rst) begin // Reset counter and output clock on reset
      cnt <= 0;
      clk_out <= 0;
    end
    
    else begin
      if(cnt == (max - 1)) begin 
        clk_out <= ~clk_out; // Toggle the output clock
        cnt <= 0;
      end
      
      else
        cnt <= cnt + 1; // Increment the counter on each clock cycle
    end
  end
endmodule
