`default_nettype none
module synchronizer (clk, rst, sin, sout);
  input wire clk, rst, sin;
  output wire sout;
  //registers
  reg [1:0] mem;
  
  always @(posedge clk or negedge rst) begin
    if(!rst) // Reset all registers to 0 on reset
      mem <= 2'b11;
    else 
      mem <= {mem[0], sin}; // Shift in the new input value on each clock cycle
  end
  
  assign sout = mem[1]; // Output the last register as the synchronized signal
endmodule
