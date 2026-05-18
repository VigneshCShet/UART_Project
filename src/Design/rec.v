`default_nettype none
module rec #(parameter data_width = 8, s0 = 0, s1 = 1, s2 = 2, s3 = 3)(clk, rst, data_in, rec_readyH, rec_dataH, rec_busyH);
  input wire clk, rst, data_in;
  output reg rec_readyH, rec_busyH;
  output reg [data_width - 1 : 0] rec_dataH;

  reg [data_width - 1 : 0] mem;
  reg [2:0] cnt;
  reg [3:0] tick_cnt; 
  reg [1:0] cs, ns;

//To handle data shifting
  always @(posedge clk or negedge rst) begin
    if(!rst) begin  // Reset all registers and counters
      mem <= 0;
      rec_dataH <= 0; 
      cs <= s0;
      cnt <= 0;
      tick_cnt <= 0;
    end
    else begin
      cs <= ns;

      if(cs != ns) // Reset tick counter on state change
        tick_cnt <= 0;
      else // Increment tick counter on each clock cycle within the same state
        tick_cnt <= tick_cnt + 1;

      if(cs != ns) // Reset bit counter on state change
        cnt <= 0;
      else if(cs == s2 && tick_cnt == 15)  // Increment bit counter at the end of each bit cell during data reception
        cnt <= cnt + 1;
   
      // Shift data
      if(cs == s2 && tick_cnt == 7) 
        mem <= {data_in, mem[data_width - 1:1]};
        
      // Output data 
      if(cs == s3 && tick_cnt == 15 && data_in == 1'b1) begin
        rec_dataH <= mem;
      end
    end
  end
  

  always @(*) begin
    // Default outputs
    rec_readyH = 0;
    rec_busyH = 1;  
    ns = cs;

    case(cs)
      s0: begin // Idle
        rec_readyH = 1;
        rec_busyH = 0;        
        if(!data_in)
          ns = s1;
        else
          ns = s0;
      end
      
      s1: begin // Start bit 
        if(tick_cnt == 7) begin
          if(data_in == 0)
            ns = s2;
          else
            ns = s0; // False start, return to idle
        end
        else begin
          ns = s1;
        end
      end

      s2: begin // Receiving data
        if(tick_cnt == 15 && cnt == data_width - 1)
          ns = s3;
        else
          ns = s2;
      end

      s3: begin // Stop bit 
        if(tick_cnt == 15)
          ns = s0; 
        else
          ns = s3;
      end

      default: begin // Default case to handle unexpected states
        ns = s0;
        rec_readyH = 1;
        rec_busyH = 0;    
      end
    endcase
  end
endmodule
