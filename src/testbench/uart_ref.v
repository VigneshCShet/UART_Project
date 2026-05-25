`default_nettype none
module top_uart_ref #(
    parameter data_width = 8, 
    parameter baud_rate  = 9600, 
    parameter clk_freq   = 50000000
)(
    input  wire sys_clk, 
    input  wire sys_rst_l, 
    input  wire xmitH, 
    input  wire [data_width - 1 : 0] xmit_dataH, 
    input  wire uart_REC_dataH, 

    //Outputs
    output reg  uart_XMIT_dataH = 1, 
    output reg  xmit_doneH = 1, 
    output reg  rec_readyH = 1, 
    output reg  [data_width - 1 : 0] rec_dataH = 0, 
    output reg  rec_busy = 0, 
    output reg  xmit_active = 0
);

    wire synch_in;
    reg [1:0] sync_mem;
    reg baud_clk;
    integer baud_cnt;

    localparam MAX_CNT = clk_freq / (baud_rate * 16 * 2);

  

    // 2. Baud Clock Generator 
    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            baud_clk <= 0;
            baud_cnt <= 0;
        end else begin
            if (baud_cnt == (MAX_CNT - 1)) begin
                baud_clk <= ~baud_clk;
                baud_cnt <= 0;
            end else begin
                baud_cnt <= baud_cnt + 1;
            end
        end
    end

      // 1. Synchronizer 
    always @(posedge baud_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            sync_mem <= 2'b11; 
        end else begin
            sync_mem <= {sync_mem[0], uart_REC_dataH};
        end
    end
    
    assign synch_in = sync_mem[1];

    // 3. Transmitter FSM
    reg [1:0] tx_cs = 0; 
    reg [data_width - 1 : 0] tx_mem;
    integer i;
    localparam TX_IDLE = 0, TX_START = 1, TX_DATA = 2, TX_STOP = 3;

    always begin : TX_FSM
        if (!sys_rst_l) begin
            uart_XMIT_dataH = 1;
            xmit_doneH      = 1;
            xmit_active     = 0;
            tx_cs           = TX_IDLE;
            @(posedge sys_rst_l); // Wait here until reset is lifted
        end else begin
            case (tx_cs)
                TX_IDLE: begin
                    uart_XMIT_dataH = 1;
                    xmit_doneH      = 1;
                    xmit_active     = 0;
                    
                    @(posedge baud_clk); 
                    if (xmitH) begin
                        tx_mem = xmit_dataH;
                        tx_cs  = TX_START;
                    end
                end

                TX_START: begin
                    uart_XMIT_dataH = 0;
                    xmit_doneH      = 0;
                    xmit_active     = 1;
                    
                    repeat (16) @(posedge baud_clk);
                    tx_cs = TX_DATA;
                end

                TX_DATA: begin
                    for (i = 0; i < data_width; i = i + 1) begin
                        uart_XMIT_dataH = tx_mem[i];
                        repeat (16) @(posedge baud_clk);
                    end
                    tx_cs = TX_STOP;
                end

                TX_STOP: begin
                    uart_XMIT_dataH = 1;
                    repeat (15) @(posedge baud_clk);
                    
                    xmit_doneH = 1; 
                    @(posedge baud_clk);
                    
                    if (xmitH) begin
                        tx_mem = xmit_dataH;
                        tx_cs  = TX_START;
                    end else begin
                        tx_cs = TX_IDLE;
                    end
                end
                
                default: begin
                    tx_cs = TX_IDLE;
                    @(posedge baud_clk); 
                end
            endcase
        end
    end

    // 4. Receiver FSM 
    reg [1:0] rx_cs = 0;
    reg [data_width - 1 : 0] rx_temp;
    integer j;
    localparam RX_IDLE = 0, RX_START = 1, RX_DATA = 2, RX_STOP = 3;

    always begin : RX_FSM
        if (!sys_rst_l) begin
            rec_busy   = 0;
            rec_readyH = 1;
            rec_dataH  = 0;
            rx_temp    = 0;
            rx_cs      = RX_IDLE;
            @(posedge sys_rst_l); // Wait here until reset is lifted
        end else begin
            case (rx_cs)
                RX_IDLE: begin
                    rec_busy   = 0;
                    rec_readyH = 1;
                    
                    @(posedge baud_clk);
                    if (synch_in === 1'b0) begin
                        rx_cs = RX_START;
                    end
                end

                RX_START: begin
                    rec_readyH = 0; 
                    rec_busy   = 1;
                    
                    repeat (8) @(posedge baud_clk); 
                    
                    if (synch_in !== 0) begin
                        rx_cs = RX_IDLE;
                    end else begin
                        repeat (8) @(posedge baud_clk); 
                        
                        if (synch_in === 0) begin
                            rx_cs = RX_DATA;
                        end else begin
                            rx_cs = RX_IDLE; 
                        end
                    end
                end

                RX_DATA: begin
                    for (j = 0; j < data_width; j = j + 1) begin
                        repeat (8) @(posedge baud_clk); 
                        
                        rx_temp = {synch_in, rx_temp[data_width - 1 : 1]};          
                        
                        repeat (8) @(posedge baud_clk); 
                    end
                    rx_cs = RX_STOP;
                end

                RX_STOP: begin
                    repeat (8) @(posedge baud_clk); 
                    
                    if (synch_in === 1'b1) begin
                        rec_dataH = rx_temp;
                    end
                    
                    repeat (8) @(posedge baud_clk);
                    if (synch_in === 1'b1) 
                        rx_cs = RX_IDLE;
                    else
                        rx_cs = RX_START; // If stop bit is invalid, try to resync by looking for the next start bit
                end

                default: begin
                    rx_cs = RX_IDLE;
                    @(posedge baud_clk);
                end
            endcase
        end
    end

    // 5. Asynchronous Reset Handler
    always @(negedge sys_rst_l) begin
        disable TX_FSM;
        disable RX_FSM;
    end

endmodule
