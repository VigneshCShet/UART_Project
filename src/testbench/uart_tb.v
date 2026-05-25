`timescale 1ns / 1ps

module tb_top_uart;

    // Parameters 
    localparam DATA_WIDTH = 8;
    localparam BAUD_RATE  = 2400;  // 9600 baud for standard UART
    localparam CLK_FREQ   = 50_000_000; // 50 MHz
    
    // Baud period in nanoseconds
    localparam real BAUD_PERIOD_NS = 1000000000.0 / BAUD_RATE;
    
    // Testbench Signals
    reg sys_clk;
    reg sys_rst_l;
    reg xmitH;
    reg [DATA_WIDTH-1:0] xmit_dataH;
    reg uart_REC_dataH;

    // DUT Outputs
    wire dut_uart_XMIT_dataH;
    wire dut_xmit_doneH;
    wire dut_rec_readyH;
    wire [DATA_WIDTH-1:0] dut_rec_dataH;
    wire dut_rec_busy;
    wire dut_xmit_active;

    // REF Outputs
    wire ref_uart_XMIT_dataH;
    wire ref_xmit_doneH;
    wire ref_rec_readyH;
    wire [DATA_WIDTH-1:0] ref_rec_dataH;
    wire ref_rec_busy;
    wire ref_xmit_active;

    // Logging & Scoreboard Variables
    integer f_pass, f_fail;
    integer total_cnt = 0;
    integer pass_cnt  = 0;
    integer fail_cnt  = 0;
    
    reg [639:0] current_test_name;
    reg error_flag;
    reg log_errors;
    reg [5:0] mismatch_tracker;
  
    top_uart #(
        .data_width(DATA_WIDTH), 
        .baud_rate(BAUD_RATE), 
        .clk_freq(CLK_FREQ)
    ) DUT (
        .sys_clk(sys_clk), 
        .sys_rst_l(sys_rst_l), 
        .xmitH(xmitH), 
        .xmit_dataH(xmit_dataH), 
        .uart_REC_dataH(uart_REC_dataH), 
        .uart_XMIT_dataH(dut_uart_XMIT_dataH), 
        .xmit_doneH(dut_xmit_doneH), 
        .rec_readyH(dut_rec_readyH), 
        .rec_dataH(dut_rec_dataH), 
        .rec_busy(dut_rec_busy), 
        .xmit_active(dut_xmit_active)
    );

    // REF Instantiation
    top_uart_ref #(
        .data_width(DATA_WIDTH), 
        .baud_rate(BAUD_RATE), 
        .clk_freq(CLK_FREQ)
    ) REF (
        .sys_clk(sys_clk), 
        .sys_rst_l(sys_rst_l), 
        .xmitH(xmitH), 
        .xmit_dataH(xmit_dataH), 
        .uart_REC_dataH(uart_REC_dataH), 
        .uart_XMIT_dataH(ref_uart_XMIT_dataH), 
        .xmit_doneH(ref_xmit_doneH), 
        .rec_readyH(ref_rec_readyH), 
        .rec_dataH(ref_rec_dataH), 
        .rec_busy(ref_rec_busy), 
        .xmit_active(ref_xmit_active)
    );

    // Clock Generation (50MHz -> 20ns period)
    initial begin
        sys_clk = 0;
        forever #10 sys_clk = ~sys_clk;
    end

    // Concurrent Scoreboard Checker
    always @(posedge sys_clk) begin
        if (sys_rst_l && log_errors) begin
            if (dut_uart_XMIT_dataH !== ref_uart_XMIT_dataH) mismatch_tracker[0] = 1;
            if (dut_xmit_doneH      !== ref_xmit_doneH)      mismatch_tracker[1] = 1;
            if (dut_rec_readyH      !== ref_rec_readyH)      mismatch_tracker[2] = 1;
            if (dut_rec_dataH       !== ref_rec_dataH)       mismatch_tracker[3] = 1;
            if (dut_rec_busy        !== ref_rec_busy)        mismatch_tracker[4] = 1;
            if (dut_xmit_active     !== ref_xmit_active)     mismatch_tracker[5] = 1;

            if (mismatch_tracker != 0) error_flag = 1;
        end
    end

    // Tasks for Scoreboard Logging
    task start_test(input [639:0] name);
        begin
            current_test_name = name;
            error_flag = 0;
            mismatch_tracker = 0;
            log_errors = 1;
        end
    endtask

    task end_test;
        begin
            log_errors = 0;
            total_cnt = total_cnt + 1;
            if (error_flag) begin
                fail_cnt = fail_cnt + 1;
                $fwrite(f_fail, "TEST %0d FAILED: %0s\n", total_cnt, current_test_name);
                $fwrite(f_fail, "--- Failure Breakdown ---\n");
              
                if (mismatch_tracker[0]) $fwrite(f_fail, " -> Mismatch on uart_XMIT_dataH\n");
                if (mismatch_tracker[1]) $fwrite(f_fail, " -> Mismatch on xmit_doneH\n");
                if (mismatch_tracker[2]) $fwrite(f_fail, " -> Mismatch on rec_readyH\n");
                if (mismatch_tracker[3]) $fwrite(f_fail, " -> Mismatch on rec_dataH\n");
                if (mismatch_tracker[4]) $fwrite(f_fail, " -> Mismatch on rec_busy\n");
                if (mismatch_tracker[5]) $fwrite(f_fail, " -> Mismatch on xmit_active\n");
              
                $fwrite(f_fail, "\nState at End of Test\n");
                $fwrite(f_fail, "Inputs: sys_rst_l=%b, xmitH=%b, xmit_dataH=%h, uart_REC_dataH=%b\n", sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH);
                $fwrite(f_fail, "DUT Out: TX=%b, xmit_done=%b, xmit_act=%b | RX_ready=%b, RX_data=%h, RX_busy=%b\n", 
                        dut_uart_XMIT_dataH, dut_xmit_doneH, dut_xmit_active, dut_rec_readyH, dut_rec_dataH, dut_rec_busy);
                $fwrite(f_fail, "REF Out: TX=%b, xmit_done=%b, xmit_act=%b | RX_ready=%b, RX_data=%h, RX_busy=%b\n", 
                        ref_uart_XMIT_dataH, ref_xmit_doneH, ref_xmit_active, ref_rec_readyH, ref_rec_dataH, ref_rec_busy);
                $display("[FAIL] %0s", current_test_name);
            end else begin
                pass_cnt = pass_cnt + 1;
                $fwrite(f_pass, "TEST %0d PASSED: %0s\n", total_cnt, current_test_name);
                $fwrite(f_pass, "Inputs Driven: xmitH=%b, xmit_dataH=%h, rx_in=%b\n", xmitH, xmit_dataH, uart_REC_dataH);
                $fwrite(f_pass, "Final Outputs: TX=%b, xmit_done=%b | RX_ready=%b, RX_data=%h\n", 
                        dut_uart_XMIT_dataH, dut_xmit_doneH, dut_rec_readyH, dut_rec_dataH);
                $display("[PASS] %0s", current_test_name);
            end
        end
    endtask

    // Task to drive serial RX data stream
    task drive_rx_serial(input [7:0] data, input valid_stop);
        integer i;
        begin
            uart_REC_dataH = 0; // Start bit
            #(BAUD_PERIOD_NS);
            for (i = 0; i < 8; i = i + 1) begin
                uart_REC_dataH = data[i]; // LSB first
                #(BAUD_PERIOD_NS);
            end
            uart_REC_dataH = valid_stop ? 1'b1 : 1'b0; // Stop bit
            #(BAUD_PERIOD_NS);
            uart_REC_dataH = 1; // Idle
        end
    endtask

    // Test Sequences
    initial begin
        // Initialize log files
        f_pass = $fopen("pass_log.txt", "w");
        f_fail = $fopen("fail_log.txt", "w");
        
        #100;

        // Initial Values
        sys_rst_l = 1;
        xmitH = 0;
        xmit_dataH = 0;
        uart_REC_dataH = 1;
        log_errors = 0;

        // 1. Reset Test (async_reset_assert_deassert & clk_toggle)
        start_test("async_reset_assert_deassert");
        sys_rst_l = 0;
        #200;
        sys_rst_l = 1;
        #200;
        end_test();

        // 2. Idle Line High
        start_test("idle_line_high");
        #1000; // Observe idle conditions
        end_test();

        // 3. TX Normal Data Transmission
        start_test("Send_data_for_tx (0xA5)");
        xmit_dataH = 8'hA5;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        wait(ref_xmit_doneH == 1);
        #100;
        end_test();

        // 4. Data Captured at Pulse (Change mid-transmission)
        start_test("data_captured_at_pulse");
        xmit_dataH = 8'h33;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        xmit_dataH = 8'hFF; // Change data while transmitting
        wait(ref_xmit_doneH == 1);
        #100;
        end_test();

        // 5. TX Back to Back Frames
        start_test("back_to_back_frames");
        xmit_dataH = 8'h11;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        wait(ref_xmit_doneH == 1);
        
        xmit_dataH = 8'h22;       // Immediately start second frame
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        wait(ref_xmit_doneH == 1);
        #100;
        end_test();

        // 6-9. Corner Cases (All 0s, All 1s, Alternating)
        start_test("data_all_zeros");
        xmit_dataH = 8'h00;
        xmitH = 1; #(BAUD_PERIOD_NS * 1.5); xmitH = 0;
        wait(ref_xmit_doneH == 1);
        end_test();

        start_test("data_all_ones");
        xmit_dataH = 8'hFF;
        xmitH = 1; #(BAUD_PERIOD_NS * 1.5); xmitH = 0;
        wait(ref_xmit_doneH == 1);
        end_test();

        start_test("alternating_0and1");
        xmit_dataH = 8'h55;
        xmitH = 1; #(BAUD_PERIOD_NS * 1.5); xmitH = 0;
        wait(ref_xmit_doneH == 1);
        end_test();

        start_test("alternating_1and0");
        xmit_dataH = 8'hAA;
        xmitH = 1; #(BAUD_PERIOD_NS * 1.5); xmitH = 0;
        wait(ref_xmit_doneH == 1);
        end_test();

        // Reset Mid-Simulation Check
        start_test("Reset");
        sys_rst_l = 0;
        #(BAUD_PERIOD_NS * 1.5);
        sys_rst_l = 1;
        end_test();
        
        repeat(200) begin
            start_test("start_bit_detection & valid frame");
            drive_rx_serial($urandom_range(255), 1'b1); // Changed to 255 to match standard Verilog syntax
            wait(ref_rec_readyH == 1);
            #100;
            end_test();
        end
        
        // 10. TX Held High No Restart
        start_test("xmitH_held_high_no_restart");
        xmit_dataH = 8'h7E;
        xmitH = 1; // Held high continuously across the entire frame
        wait(ref_xmit_doneH == 1);
        #500;
        xmitH = 0;
        end_test();

        // 11. RX Valid Frame Reception
        start_test("start_bit_detection & valid frame");
        drive_rx_serial(8'hD4, 1'b1); // Send D4 with valid stop bit
        wait(ref_rec_readyH == 1);
        #100;
        end_test();
        
        start_test("start_bit_detection & valid frame_1");
        drive_rx_serial(8'hFF, 1'b1); // Send D4 with valid stop bit
        wait(ref_rec_readyH == 1);
        #100;
        end_test();
        
        start_test("start_bit_detection & valid frame_2");
        drive_rx_serial(8'h00, 1'b1); // Send D4 with valid stop bit
        wait(ref_rec_readyH == 1);
        #100;
        end_test();

                
        // 12. RX Back to Back
        start_test("rec_back_to_back");
        drive_rx_serial(8'h12, 1'b1);
        wait(ref_rec_readyH == 1);
        drive_rx_serial(8'h34, 1'b1); // Immediately drive next
        wait(ref_rec_readyH == 1);
        #100;
        end_test();

        // 13. RX False Start Rejection
        start_test("false_start_rejection");
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS / 4); // Hold low for less than 8 ticks (less than half baud)
        uart_REC_dataH = 1;
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 14. RX Frame Error (stop_bit_0)
        start_test("stop_bit_0");
        drive_rx_serial(8'h88, 1'b0); // Send 88 but force stop bit to 0
        #(BAUD_PERIOD_NS * 2);
        end_test();
        
        // 15. RX Late False Start 
        start_test("false_start_late_rejection");
        uart_REC_dataH = 0; // Drive start bit to enter s1
        #(BAUD_PERIOD_NS * 0.85); 
        
        // Glitch high so data_in == 1 exactly when tick_cnt hits 15
        uart_REC_dataH = 1; 
        
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 16. TX Late Restart during Stop Bit
        start_test("tx_late_restart_in_stop_bit");
        
        // Start first frame (Manual toggle)
        xmit_dataH = 8'hC3;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        
        // We already waited 1.5 baud periods. 
        // Wait 8 more baud periods to reach the middle of the stop bit (9.5 total)
        #(BAUD_PERIOD_NS * 8);
        
        @(posedge sys_clk);
        xmit_dataH = 8'h3C;
        xmitH = 1; // Assert xmitH while still in s3 so it is high exactly at tick 15
        
        wait(ref_xmit_doneH == 1); // Triggers at s3 tick 15 of the first frame
        @(posedge sys_clk);
        xmitH = 0;
        
        wait(ref_xmit_doneH == 1); // Wait for the second frame to finish
        end_test();
        
        // 17. TX Reset in s1
        start_test("tx_reset_in_s1_start_bit");
        xmit_dataH = 8'hAA;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 0.5); // Wait half a baud period (now in s1)
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        xmitH = 0;     // Clear input
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 18. TX Reset in s2
        start_test("tx_reset_in_s2_data_bits");
        xmit_dataH = 8'h55;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        
        #(BAUD_PERIOD_NS * 3); // Wait 3 more baud periods (now deep in s2)
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 19. TX Reset in s3
        start_test("tx_reset_in_s3_stop_bit");
        xmit_dataH = 8'hC3;
        xmitH = 1; 
        #(BAUD_PERIOD_NS * 1.5); 
        xmitH = 0;
        
        // 1.5 periods elapsed. Wait 8 more to reach the middle of the stop bit (s3)
        #(BAUD_PERIOD_NS * 8); 
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 20. RX Reset in s1 (Start Bit)
        start_test("rx_reset_in_s1_start_bit");
        uart_REC_dataH = 0; // Pull low to start
        #(BAUD_PERIOD_NS * 0.5); // Wait half a baud period (now in s1)
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        uart_REC_dataH = 1; // Return line to idle
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 21. RX Reset in s2 (Data Bits)
        start_test("rx_reset_in_s2_data_bits");
        uart_REC_dataH = 0; // Start bit
        #(BAUD_PERIOD_NS);
        uart_REC_dataH = 1; // Send a '1' for the first data bit
        
        #(BAUD_PERIOD_NS * 2); // Wait to get deep into s2
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        uart_REC_dataH = 1; // Return line to idle
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 22. RX Reset in s3 (Stop Bit)
        start_test("rx_reset_in_s3_stop_bit");
        uart_REC_dataH = 0; // Start bit
        #(BAUD_PERIOD_NS);
        
        // Send 8 bits of data (all 0s for simplicity)
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS * 8);
        
        // Enter Stop Bit (s3) - drive high
        uart_REC_dataH = 1;
        #(BAUD_PERIOD_NS * 0.5); // Wait halfway into the stop bit
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();
        
        // 20. RX Reset in s1 
        start_test("rx_reset_in_s1_start_bit_2");
        uart_REC_dataH = 0; // Pull low to trigger start bit
        #(BAUD_PERIOD_NS * 0.5); // Wait half a baud period 
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        uart_REC_dataH = 1; // Return line to idle while reset is active
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 21. RX Reset in s2 (Coverage Fix)
        start_test("rx_reset_in_s2_data_bits_coverage");

        // Pull low for the start bit and HOLD it low long enough to safely clear tick_cnt == 15 and enter s2.
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS * 1.5); 

        // We are now physically in s2. Drop the reset hammer.
        sys_rst_l = 0;
        #(BAUD_PERIOD_NS);
        sys_rst_l = 1;

        // 3. Clean up the line
        uart_REC_dataH = 1;
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 22. RX Reset in s3 
        start_test("rx_reset_in_s3_stop_bit_2");
        uart_REC_dataH = 0; // Start bit
        #(BAUD_PERIOD_NS);
        
        // Send 8 bits of data (driving all 0s for simplicity)
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS * 8);
        uart_REC_dataH = 1;
        #(BAUD_PERIOD_NS * 0.5); // Wait halfway into the stop bit (tick ~8)
        
        sys_rst_l = 0; // Assert Reset
        #(BAUD_PERIOD_NS);
        sys_rst_l = 1; // Release Reset
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // 23. RX Early False Start (Target: tick_cnt == 7 in s1)
        start_test("rx_early_false_start_tick_7");
        uart_REC_dataH = 0; // Pull low to enter start bit
        #(BAUD_PERIOD_NS * 0.45); 
        uart_REC_dataH = 1; 
        #(BAUD_PERIOD_NS * 2);
        end_test();
      
        // 24. Clean RX Frame (Target: tick_cnt == 15 in s3)
        start_test("rx_clean_stop_bit_completion");
        drive_rx_serial(8'hFF, 1'b1);
        #(BAUD_PERIOD_NS * 5); 
        end_test();
      
        // 26. RX Early False Start (Target: 'data_in != 0' at tick 7)
        // Sweep A: Pull high exactly at 6.5 ticks
        start_test("rx_false_start_tick_7_sweep_A");
        uart_REC_dataH = 0; // Trigger start bit
        #(BAUD_PERIOD_NS * 6.5 / 16.0); 
        uart_REC_dataH = 1; 
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // Sweep B: Pull high exactly at 7.0 ticks
        start_test("rx_false_start_tick_7_sweep_B");
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS * 7.0 / 16.0); 
        uart_REC_dataH = 1; 
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // Sweep C: Pull high exactly at 7.5 ticks
        start_test("rx_false_start_tick_7_sweep_C");
        uart_REC_dataH = 0; 
        #(BAUD_PERIOD_NS * 7.5 / 16.0); 
        uart_REC_dataH = 1; 
        #(BAUD_PERIOD_NS * 2);
        end_test();
      
        // 28. RX Toggle Coverage Fix (Targeting bits 3 and 0)
        start_test("rx_toggle_coverage_fix_0x09");
        
        // Send 8'h09 (0000_1001) to force rec_dataH[3] and rec_dataH[0] to 1
        drive_rx_serial(8'h09, 1'b1); 
        
        // Wait for the receiver to assert ready
        wait(ref_rec_readyH == 1);
        
        // Give the scoreboard a moment to check the values
        #100;
        
        // Return the line to idle
        uart_REC_dataH = 1;
        #(BAUD_PERIOD_NS * 2);
        end_test();

        // Final Summary
        $display("TESTBENCH COMPLETE");
        $display(" TOTAL TESTS RUN : %0d", total_cnt);
        $display(" TESTS PASSED    : %0d", pass_cnt);
        $display(" TESTS FAILED    : %0d", fail_cnt);

        $fclose(f_pass);
        $fclose(f_fail);
        $finish;
    end
    
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top_uart);
    end
endmodule
