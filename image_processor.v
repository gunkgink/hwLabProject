`timescale 1ns / 1ps

module image_processor_12bit(
    input clk,
    input reset,
    // SD card interface
    input [7:0] sd_data_in,
    input sd_data_valid,
    output [31:0] sd_block_addr,
    output reg sd_read_block, //read_enable of sd_controller
    input sd_ready,
    // Image control
    input [3:0] image_select,
    input [16:0] addrb,
    output [11:0] dataOut // 12-bit color //rgb
);

    // Frame buffer interface
    wire [16:0] fb_write_addr; //addra
    wire [11:0] fb_write_data; // 12-bit color //dina
    reg fb_write_en;

    // 320x240 = 76800 pixels (17-bit address)
    reg [11:0] ram [0:76799]; // 12-bit color depth

    // Image block addresses (example for 4 images)
    reg [31:0] current_block;
    reg [8:0] byte_counter;
    reg [1:0] pixel_phase; // Tracks which byte we're processing
    reg [23:0] pixel_buffer; // Temporary storage for 24-bit RGB
    
    // Image block addresses (example for 4 images)
    parameter IMAGE1_START = 32'h00000000;
    parameter IMAGE2_START = 32'h00010000;
    parameter IMAGE3_START = 32'h00020000;
    parameter IMAGE4_START = 32'h00030000;
    
    assign sd_block_addr = current_block;
    assign fb_write_addr = (current_block - IMAGE1_START) * 256 + byte_counter/3;
    
    // Convert 24-bit RGB (8-8-8) to 12-bit RGB (4-4-4)
    assign fb_write_data = {pixel_buffer[23:20], pixel_buffer[15:12], pixel_buffer[7:4]};

    // VGA_READ
    assign dataOut = ram[addrb];
    
    always @(posedge clk) begin
        if (fb_write_en) begin
            ram[fb_write_addr] <= fb_write_data;
        end
        if (reset) begin
            current_block <= IMAGE1_START;
            byte_counter <= 0;
            pixel_phase <= 0;
            fb_write_en <= 0;
            sd_read_block <= 0;
            pixel_buffer <= 0;
        end else begin
            // Handle image selection changes
            case (image_select)
                0: current_block <= IMAGE1_START;
                1: current_block <= IMAGE2_START;
                2: current_block <= IMAGE3_START;
                3: current_block <= IMAGE4_START;
                default: current_block <= IMAGE1_START;
            endcase
            
            // Read new block if needed
            if (sd_ready && !sd_read_block && byte_counter == 0) begin
                sd_read_block <= 1;
            end else if (sd_read_block) begin
                sd_read_block <= 0;
            end
            
            // Process incoming data (3 bytes per pixel)
            if (sd_data_valid) begin
                case (pixel_phase)      
                    0: begin
                        pixel_buffer[23:16] <= sd_data_in; // Red
                        pixel_phase <= 1;
                    end
                    1: begin
                        pixel_buffer[15:8] <= sd_data_in; // Green
                        pixel_phase <= 2;
                    end
                    2: begin
                        pixel_buffer[7:0] <= sd_data_in; // Blue
                        pixel_phase <= 0;
                        fb_write_en <= 1;
                        byte_counter <= byte_counter + 1;
                    end
                endcase
            end else begin
                fb_write_en <= 0;
            end
            
            // Reset counter at end of block
            if (byte_counter == 511) begin
                byte_counter <= 0;
                current_block <= current_block + 1;
            end
        end
    end
    
endmodule
>>>>>>> Stashed changes
