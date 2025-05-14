`timescale 1ns / 1ps

module top(
    input wire          clk100mhz,      // 100MHz clock
    input wire          reset,          // Reset button
    input wire          btn,            // Button input
    input               miso,           // SD card MISO
    output              mosi,           // SD card MOSI
    output              sclk,           // SD card SCLK
    output              cs,             // SD card CS
    output reg [7:0]    led             // 8 LEDs on Basys3
);

    // Clock and reset signals
    wire clk;           // 25MHz clock
    wire locked;        // PLL locked
    wire rst = ~locked | reset;

    // SD card controller signals
    reg rd = 0;
    wire [7:0] sd_dout;
    wire byte_available;
    wire ready;
    wire [4:0] status;
    
    // State machine
    reg [3:0] main_state = INIT;
    parameter INIT = 0,
              WAIT_READY = 1,
              READ_SD = 2,
              DONE = 3;
    
    // Sector reading
    reg [31:0] current_sector = 0;
    reg [9:0] bytes_read = 0;
    reg reading = 0;

    // Clock divider (100MHz -> 25MHz)
    clk_wiz_0 clock_gen (
        .clk_in1(clk100mhz),
        .clk_out1(clk),
        .locked(locked),
        .reset(reset)
    );

    // SD card controller
    sd_controller sd_ctrl (
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .rd(rd),
        .dout(sd_dout),
        .byte_available(byte_available),
        .wr(1'b0),
        .din(8'h00),
        .ready_for_next_byte(),
        .reset(rst),
        .ready(ready),
        .address(current_sector),
        .clk(clk),
        .status(status)
    );

    // Main state machine
    always @(posedge clk) begin
        if (rst) begin
            main_state <= INIT;
            rd <= 0;
            reading <= 0;
            bytes_read <= 0;
            led <= 8'h00;
            current_sector <= 0;
        end else begin
            case (main_state)
                INIT: begin
                    main_state <= WAIT_READY;
                    led <= 8'b00000001; // Show init state
                end
                
                WAIT_READY: begin
                    if (ready) begin
                        main_state <= READ_SD;
                        led <= 8'b00000010; // Show ready state
                    end
                end
                
                READ_SD: begin
                    if (!reading && !rd) begin
                        rd <= 1;
                        reading <= 1;
                    end else if (rd) begin
                        rd <= 0;
                    end
                    
                    // Display each byte on LEDs as it arrives
                    if (byte_available) begin
                        led <= sd_dout; // Directly display the byte
                        bytes_read <= bytes_read + 1;
                        
                        if (bytes_read == 511) begin
                            reading <= 0;
                            main_state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    led <= 8'b11111111; // Show completion
                    if (btn) begin
                        // Restart reading when button pressed
                        main_state <= INIT;
                        current_sector <= current_sector + 1;
                        bytes_read <= 0;
                    end
                end
            endcase
        end
    end

endmodule