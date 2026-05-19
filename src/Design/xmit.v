`default_nettype none
module xmit #(parameter data_width = 8, s0 = 0, s1 = 1, s2 = 2, s3 = 3)(baud_clk, sys_rst_l, xmitH, xmit_dataH, uart_XMIT_dataH, xmit_doneH, xmit_active);
  input wire baud_clk, sys_rst_l, xmitH;
  input wire [data_width - 1: 0] xmit_dataH;
  output reg uart_XMIT_dataH, xmit_doneH, xmit_active;
  
 // wire xmitH_pulse;

  //registers
  //reg xmitH_d;
  reg [data_width - 1 : 0] mem;
  reg [2:0] cnt;       
  reg [3:0] tick_cnt;  // Counts 16 baud_clk cycles per transmitted bit
  reg [1:0] cs, ns;
  
  // Edge detector for the start signal
 // assign xmitH_pulse = xmitH & ~xmitH_d;
    
  always @(posedge baud_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) begin // Reset all registers and counters
    //  xmitH_d <= 0;
      mem <= 0;
      cs <= s0;
      cnt <= 0;
      tick_cnt <= 0;
    end
    else begin
    //  xmitH_d <= xmitH; //edge detection for xmitH signal
      cs <= ns; // Update current state to next state on each clock cycle

     
      if(cs != ns) begin
        tick_cnt <= 0;
      end
      else begin
        tick_cnt <= tick_cnt + 1;
      end

      // Load memory on start pulse
      if (cs == s0 && xmitH) begin
        mem <= xmit_dataH;
      end

      
      if(cs != ns) begin // Reset bit counter on state change
        if (ns == s2 && cs == s1) 
          cnt <= 0; // Reset bit count when entering data state
        else if (cs != s2)
          cnt <= 0;
      end
      else if(cs == s2 && tick_cnt == 15) begin
        cnt <= cnt + 1;
        mem <= {1'b0, mem[data_width - 1:1]}; // Shift data right
      end
    end
  end 
  
  always @(*) begin
    // Default outputs
    uart_XMIT_dataH = 1;
    xmit_doneH = 1;
    xmit_active = 0;
    ns = cs;
    
    case(cs)
      s0: begin // Idle State
        uart_XMIT_dataH = 1;
        xmit_doneH = 1;
        xmit_active = 0;
        if(xmitH)
          ns = s1;
        else
          ns = s0;
      end
      
      s1: begin // Start Bit
        uart_XMIT_dataH = 0;
        xmit_doneH = 0;
        xmit_active = 1;
        
        if(tick_cnt == 15) 
          ns = s2;
        else
          ns = s1;
      end
      
      s2: begin // Data Bits
        uart_XMIT_dataH = mem[0];
        xmit_doneH = 0;
        xmit_active = 1;
        
        // Move to stop bit after sending all bits and completing the final tick
        if(tick_cnt == 15 && cnt == data_width - 1)
          ns = s3;
        else
          ns = s2;
      end
      
      s3: begin // Stop Bit
        uart_XMIT_dataH = 1;
        xmit_doneH = 0;
        xmit_active = 1;
        
        
        if(tick_cnt == 15) begin
          ns = s0;
          xmit_doneH = 1;
        end
        else
          ns = s3;
      end
      
      default: begin // Default case to handle unexpected states
        uart_XMIT_dataH = 1;
        xmit_doneH = 1;
        xmit_active = 0;
        ns = s0;
      end
    endcase
  end
  
endmodule
