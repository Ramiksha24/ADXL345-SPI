`timescale 1ns / 1ps

module adxl345_simple #(
    parameter CLOCK_DIV = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg init_done,
    output reg data_ready,
    output reg signed [15:0] accel_x,
    output reg signed [15:0] accel_y,
    output reg signed [15:0] accel_z,
    output reg cs_n,
    output reg sclk,
    output reg mosi,
    input wire miso,
    output reg [5:0] state
);

    
    reg [7:0] byte_to_send;
    reg [7:0] byte_received;
    reg [3:0] bit_counter;
    reg [7:0] clk_counter;
    reg [15:0] wait_counter;
    reg [7:0] data_buffer[0:5];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            cs_n <= 1;
            sclk <= 1;
            mosi <= 0;
            bit_counter <= 0;
            clk_counter <= 0;
            wait_counter <= 0;
            init_done <= 0;
            data_ready <= 0;
            accel_x <= 0;
            accel_y <= 0;
            accel_z <= 0;
        end else begin
            data_ready <= 0;
            
            case (state)
                // IDLE
                0: if (start) state <= 1;
                
                // Write DATA_FORMAT - send address
                1: begin
                    cs_n <= 0;
                    byte_to_send <= 8'h31;  // Write to 0x31
                    bit_counter <= 0;
                    clk_counter <= 0;
                    mosi <= 0;
                    state <= 2;
                end
                
                // Send bits
                2: begin
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                                mosi <= byte_to_send[7 - bit_counter];
                            end else begin
                                sclk <= 1;
                                byte_received[7 - bit_counter] <= miso;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        state <= 3;
                    end
                end
                
                // Write DATA_FORMAT - send data
                3: begin
                    byte_to_send <= 8'h00;  // 4-wire SPI
                    bit_counter <= 0;
                    state <= 4;
                end
                
                4: begin
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                                mosi <= byte_to_send[7 - bit_counter];
                            end else begin
                                sclk <= 1;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        cs_n <= 1;
                        wait_counter <= 1000;
                        state <= 5;
                    end
                end
                
                // Wait
                5: begin
                    if (wait_counter > 0) wait_counter <= wait_counter - 1;
                    else state <= 6;
                end
                
                // Write POWER_CTL - send address
                6: begin
                    cs_n <= 0;
                    byte_to_send <= 8'h2D;  // Write to 0x2D
                    bit_counter <= 0;
                    mosi <= 0;
                    state <= 7;
                end
                
                7: begin
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                                mosi <= byte_to_send[7 - bit_counter];
                            end else begin
                                sclk <= 1;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        state <= 8;
                    end
                end
                
                // Write POWER_CTL - send data
                8: begin
                    byte_to_send <= 8'h08;  // Measure mode
                    bit_counter <= 0;
                    state <= 9;
                end
                
                9: begin
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                                mosi <= byte_to_send[7 - bit_counter];
                            end else begin
                                sclk <= 1;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        cs_n <= 1;
                        init_done <= 1;
                        wait_counter <= 5000;
                        state <= 10;
                    end
                end
                
                // Wait before reading
                10: begin
                    if (wait_counter > 0) wait_counter <= wait_counter - 1;
                    else state <= 11;
                end
                
                // Read XYZ - send command
                11: begin
                    cs_n <= 0;
                    byte_to_send <= 8'hF2;  // Read multi-byte from 0x32
                    bit_counter <= 0;
                    mosi <= 1;
                    state <= 12;
                end
                
                12: begin
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                                mosi <= byte_to_send[7 - bit_counter];
                            end else begin
                                sclk <= 1;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        state <= 13;  // Read X0
                    end
                end
                
                // Read 6 bytes (states 13-24, each byte has 2 states)
                13, 15, 17, 19, 21, 23: begin  // Setup byte read
                    byte_to_send <= 8'h00;
                    bit_counter <= 0;
                    mosi <= 0;
                    state <= state + 1;
                end
                
                14, 16, 18, 20, 22, 24: begin  // Read byte
                    if (bit_counter < 8) begin
                        if (clk_counter < CLOCK_DIV - 1) begin
                            clk_counter <= clk_counter + 1;
                        end else begin
                            clk_counter <= 0;
                            if (sclk) begin
                                sclk <= 0;
                            end else begin
                                sclk <= 1;
                                byte_received[7 - bit_counter] <= miso;
                                bit_counter <= bit_counter + 1;
                            end
                        end
                    end else begin
                        // Store byte
                        case (state)
                            14: data_buffer[0] <= byte_received;  // X0
                            16: data_buffer[1] <= byte_received;  // X1
                            18: data_buffer[2] <= byte_received;  // Y0
                            20: data_buffer[3] <= byte_received;  // Y1
                            22: data_buffer[4] <= byte_received;  // Z0
                            24: data_buffer[5] <= byte_received;  // Z1
                        endcase
                        
                        if (state == 24) begin
                            cs_n <= 1;
                            state <= 25;
                        end else begin
                            state <= state + 1;
                        end
                    end
                end
                
                // Update outputs
                25: begin
                    accel_x <= {data_buffer[1], data_buffer[0]};
                    accel_y <= {data_buffer[3], data_buffer[2]};
                    accel_z <= {data_buffer[5], data_buffer[4]};
                    data_ready <= 1;
                    wait_counter <= 10000;
                    state <= 26;
                end
                
                // Wait before next read
                26: begin
                    if (wait_counter > 0) wait_counter <= wait_counter - 1;
                    else state <= 11;  // Loop back to read again
                end
            endcase
        end
    end

endmodule