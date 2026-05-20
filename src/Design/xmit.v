`default_nettype none
module top_uart #(parameter data_width = 8, baud_rate = 9600, clk_freq = 50000000)(sys_clk, sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH, uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_dataH, rec_busy, xmit_active);
  input wire sys_clk, sys_rst_l, xmitH, uart_REC_dataH;
  input wire [data_width - 1 : 0] xmit_dataH;
  output wire uart_XMIT_dataH, xmit_doneH, rec_readyH, rec_busy, xmit_active;
  output wire [data_width - 1 : 0] rec_dataH;
  
  wire synch_in;
  wire baud_clk;
  synchronizer u4 (.clk(sys_clk), .rst(sys_rst_l), .sin(uart_REC_dataH), .sout(synch_in));
  baud_clk  #(.baud_rate(baud_rate), .clk_freq(clk_freq)) u3 (.clk(sys_clk), .rst(sys_rst_l), .clk_out(baud_clk));
  xmit  #(.data_width(data_width)) u1 (.baud_clk(baud_clk), .sys_rst_l(sys_rst_l), .xmitH(xmitH), .xmit_dataH(xmit_dataH), .uart_XMIT_dataH(uart_XMIT_dataH), .xmit_doneH(xmit_doneH), .xmit_active(xmit_active));
  rec  #(.data_width(data_width)) u2 (.clk(baud_clk), .rst(sys_rst_l), .data_in(synch_in), .rec_readyH(rec_readyH), .rec_dataH(rec_dataH), .rec_busyH(rec_busy));

endmodule


module baud_clk #(parameter baud_rate = 2400, clk_freq = 50000000)(clk, rst, clk_out);
  input wire clk, rst;
  output reg clk_out;
  
  reg [31:0] cnt;
  
  
  localparam max = clk_freq / (baud_rate * 16 * 2); // Calculate the number of system clock cycles for half a baud period at 16x oversampling
  
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


module xmit #(parameter data_width = 8, s0 = 0, s1 = 1, s2 = 2, s3 = 3)(baud_clk, sys_rst_l, xmitH, xmit_dataH, uart_XMIT_dataH, xmit_doneH, xmit_active);
  input wire baud_clk, sys_rst_l, xmitH;
  input wire [data_width - 1: 0] xmit_dataH;
  output reg uart_XMIT_dataH, xmit_doneH, xmit_active;
  
  //wire xmitH_pulse;

  //registers
 // reg xmitH_d;
  reg [data_width - 1 : 0] mem;
  reg [2:0] cnt;       
  reg [3:0] tick_cnt;  // Counts 16 baud_clk cycles per transmitted bit
  reg [1:0] cs, ns;
  
  // Edge detector for the start signal
  //assign xmitH_pulse = xmitH & ~xmitH_d;
    
  always @(posedge baud_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) begin // Reset all registers and counters
    //  xmitH_d <= 0;
      mem <= 0;
      cs <= s0;
      cnt <= 0;
      tick_cnt <= 0;
    end
    else begin
      //xmitH_d <= xmitH; //edge detection for xmitH signal
      cs <= ns; // Update current state to next state on each clock cycle

     
      if(cs != ns) begin
        tick_cnt <= 0;
      end
      else if(tick_cnt == 15) begin
        tick_cnt <= 0; // Reset tick counter at the end of each bit cell
      end
      
      else begin
        tick_cnt <= tick_cnt + 1;
      end

      // Load memory on start pulse
      if (cs == s0 && xmitH) begin
        mem <= xmit_dataH;
      end

      
      if(cs != ns) begin // Reset bit counter on state change
        /*if (ns == s2 && cs == s1) 
          cnt <= 0; // Reset bit count when entering data state
        else if (cs != s2)
          cnt <= 0;*/
          cnt <= 0;
      end
      else if(tick_cnt == 15) begin
        cnt <= cnt + 1;
        if(cs == s2)
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
          if(xmitH) begin
            ns = s1;
            xmit_doneH = 1;
            mem = xmit_dataH;
          end
          else begin
            ns = s0;
            xmit_doneH = 1;
          end
          
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
   
      // Shift data (tick 7)
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
