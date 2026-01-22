`timescale 1ns / 1ps

module tb;

    reg clk, rst_n, start, miso;
    wire init_done, data_ready;
    wire signed [15:0] accel_x, accel_y, accel_z;
    wire cs_n, sclk, mosi;
    
    adxl345_simple #(.CLOCK_DIV(5)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .init_done(init_done),
        .data_ready(data_ready),
        .accel_x(accel_x),
        .accel_y(accel_y),
        .accel_z(accel_z),
        .cs_n(cs_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso)
    );
    
    // Clock
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Test
    initial begin
        $display("=== ADXL345 XYZ Reader Test ===");
        rst_n = 0; start = 0; miso = 0;
        #100 rst_n = 1;
        #50 start = 1;
        #20 start = 0;
        
        $display("Waiting for init...");
        wait(init_done);
        $display("Init done!");
        
        $display("Waiting for data...");
        repeat(3) begin
            wait(data_ready);
            $display("Data: X=%d Y=%d Z=%d", accel_x, accel_y, accel_z);
            #10;
        end
        
        #1000 $finish;
    end
    
    initial begin
        $dumpfile("xyz.vcd");
        $dumpvars(0, tb);
    end

endmodule