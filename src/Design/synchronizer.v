`default_nettype none
module synchronizer #(parameter reg_size = 2)(clk, rst, sin, sout);
  input wire clk, rst, sin;
  output wire sout;
  //registers
  reg [(reg_size - 1):0] mem;
  
  always @(posedge clk or negedge rst) begin
    if(!rst) // Reset all registers to 0 on reset
      mem <= 0;
    else 
      mem <= {mem[reg_size - 2: 0], sin}; // Shift in the new input value on each clock cycle
  end
  assign sout = mem[reg_size - 1]; // Output the last register as the synchronized signal
  
endmodule
