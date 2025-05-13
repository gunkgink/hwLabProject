`timescale 1ns / 1ps

module top_module (
    // sd card interface
    input wire clk100, // 100 MHz clock
    input wire reset, // active high reset
    input wire button, // button input
    input miso, // sd card data input
    output mosi, // sd card data output
    output sclk, // sd card clock
    output cs, // sd card chip select

    //VGA
    input [15:0] sw,                // switch input for image selection
    output wire hsync,       // VGA horizontal sync
    output wire vsync,       // VGA vertical sync
    //output wire [3:0] vga_red,
    //output wire [3:0] vga_green,
    //output wire [3:0] vga_blue
    output wire [11:0] rgb
);

// basic signal declarations
wire clk25;  // 25 MHz clock for VGA
wire locked; // Clock locked signal
wire rst = ~locked | reset; // Reset signal for the design

//SD CARD
wire readEnable = 0;
wire [7:0] sd_dataOut;
wire sd_data_ready;
wire sd_ready;
wire [4:0] status;

//DEBOUNCER
wire btn_debounced;

// Sector reading logic
reg [31:0] current_sector = 32'd0;    // Current sector being read (0-71)

// VGA signals
wire video_on;         // VGA display active area
wire p_tick;           // 25MHz pixel clock tick
wire [9:0] x, y; // Current pixel coordinates

// ROM interface
//wire [11:0] read_data; //rom_data;
wire [19:0] read_addr; //rom_addr;  // Total ROM size: 4 images * 320*240 = 307200 entries

// Display window origin (centered)
localparam X_START = (640 - 320) / 2;  // = 160
localparam Y_START = (480 - 240) / 2;  // = 120

// Offset coordinates inside image
wire [8:0] img_x = x - X_START;  // 0-319
wire [7:0] img_y = y - Y_START;  // 0-239

// Only access ROM when within image bounds
wire in_image = (x >= X_START) && (x < X_START + 320) &&
                (y >= Y_START) && (y < Y_START + 240);

// Address calculation for multiple images
// Downscale screen coordinate to original 160x120 coordinate
wire [7:0] orig_x = img_x >> 1;  // divide by 2
wire [6:0] orig_y = img_y >> 1;  // divide by 2
    
assign rom_addr = in_image ? (sw * 19200 + (orig_y * 160 + orig_x)) : 20'd0; // 160x120 = 19200 pixels per image

//buffer
reg [11:0] buffer[0:18431]; // 64x48 pixel buffer (12-bit color)
reg [14:0] buffer_addr_write = 0;

// Clock wizard instance for 25MHz clock
clk_wiz_0 u_clk_wiz_0 (
    .reset       (reset),
    .clk_in1     (clk100), // input 100MHz
    .locked      (locked),
    .clk_out1    (clk25) // output 25MHz
);

sd_controller sd_controller (
    .cs(cs),
    .sclk(sclk),
    .mosi(mosi),
    .miso(miso),
    .readEnable(readEnable),
    .dataOut(sd_dataOut),
    .data_ready(sd_data_ready),
    .clk(clk25),
    .reset(rst),
    .ready(sd_ready),
    .address(current_sector),
    .status(status)
);

debouncer debouncer (
    .clk(clk25),
    .reset(rst),
    .button_in(button),
    .button_out(btn_debounced)
);

assign read_addr = in_image ? (sw * 19200 + (orig_y * 160 + orig_x)) : 20'd0;

image_processor image_processor(
    .clk(clk25),
    .reset(rst),
    // SD card interface
    .sd_data_in(sd_dataOut),
    .sd_data_valid(sd_data_ready),
    .sd_block_addr(current_sector),
    .sd_read_block(readEnable), //read_enable of sd_controller
    .sd_ready(sd_ready),
    // Image control
    .image_select(btn_debounced),
    .addrb(read_addr),
    //.dataOut(read_data) // 12-bit color //rgb
    .dataOut(rgb) // 12-bit color //rgb
);

// image_buffer image_buffer (
//     // Port A (write from SD card)
//     .input clk(clk25),
//     .wea(data_ready),
//     .addra(current_sector),
//     .dina(sd_out),      // Now 12-bit color
//     // Port B (read for VGA)
//     .input clkb,
//     .addrb(read_addr),
//     .doutb(read_data)     // Now 12-bit color
// );

vga_sync vga_sync (
    .clk(clk25),
    .reset(rst),
	.hsync(hsync),
    .vsync(vsync),
    .video_on(video_on),
    .p_tick(p_tick),
    .x(x),
    .y(y)
);
/*
rgb_processor rgb(
    .x(x),
    .y(y),
    .video_on(video_on),
    .vga_red(vga_red),
    .vga_green(vga_green),
    .vga_blue(vga_blue),
    .buffer(buffer),
    .main_state(main_state)
);
*/
reg btn_prev = 0;
reg btn_pressed = 0;
reg change_sector_group = 0;
always @(posedge clk25) begin
        if (rst) begin
            btn_prev <= 0;
            btn_pressed <= 0;
            change_sector_group <= 0;
        end else begin
            btn_prev <= btn_debounced;
            btn_pressed <= ~btn_prev & btn_debounced; // Rising edge detection
            
            // Set the flag when button is pressed and we're in DONE state
            if (btn_pressed && main_state == DONE) begin
                change_sector_group <= 1;
            end else begin
                change_sector_group <= 0;
            end
        end
    end

reg [3:0] main_state = INIT;
/*
main main(
    .clk(clk25),
    .reset(rst), //rst
    .main(main_state),
    .readEnable(readEnable),
    .current_sectorWire(current_sector),
    .change_sector_group(change_sector_group),
    .ready(sd_ready),
    .byte_available(sd_data_ready),
    .sd_dout(sd_dataOut)
);
*/
    localparam INIT = 0,
            SD_WAIT_READY = 1,
            READ_SD = 2,
            WAIT_SECTOR = 3,
            DONE = 4,
            CALCULATE_CHECKSUM = 5,
            DISPLAY_CHECKSUM = 6;
reg readEnableReg;
assign readEnable = readEnableReg;
// Sector reading logic
reg [31:0] sector_base = 32'd0;       // Base sector for the current group
reg [9:0] bytes_read = 0;            // Counter for bytes read in current sector
reg reading = 0;               // Flag to indicate reading in progress
reg [6:0] sectors_read = 0;          // Counter for number of sectors read (0-71)
// Byte pairing for 16-bit buffer storage
reg [7:0] byte_buffer;     // Buffer for first byte in the pair
reg byte_ready = 0;  // Flag indicating byte buffer has data
// Checksum calculation
reg [31:0] checksum = 0;        // Holds the running sum (needs to be 32-bit to handle overflow before modulo)
reg [14:0] checksum_addr = 0;   // Address counter for reading buffer during checksum calculation
reg [1:0] checksum_state = 0;
    // Main state machine
    always @(posedge clk25) begin
        if (rst) begin
            main_state <= INIT;
            readEnableReg <= 0;
            reading <= 0;
            buffer_addr_write <= 0;
            bytes_read <= 0;
            //led <= 16'h0000;
            //done <= 0;
            byte_ready <= 0;
            checksum <= 0;
            checksum_addr <= 0;
            checksum_state <= 0;
            // Initialize sector variables
            sector_base <= 32'd0;
            current_sector <= 32'd0;
            sectors_read <= 0;
        end else begin
            // Handle sector group change request from button press
            if (change_sector_group) begin
                // Change sector group when button is pressed and we're in DONE state
                // Cycle through the 6 sector groups
                if (sector_base == 0)          sector_base <= 32'd100;    // Move to Sectors 100-171
                else if (sector_base == 100)   sector_base <= 32'd200;    // Move to Sectors 200-271
                else if (sector_base == 200)   sector_base <= 32'd300;    // Move to Sectors 300-371
                else if (sector_base == 300)   sector_base <= 32'd400;    // Move to Sectors 400-471
                else if (sector_base == 400)   sector_base <= 32'd0;      // Back to Sectors 0-71
                else                           sector_base <= 32'd0;      // Default case
                
                // Reset current sector to base sector
                current_sector <= sector_base;
                sectors_read <= 0;
                buffer_addr_write <= 0;  // Reset buffer address for new sector group
                main_state <= INIT;
            end else begin
                // Normal state machine operation
                case (main_state)
                    INIT: begin
                        main_state <= SD_WAIT_READY;
                        bytes_read <= 0;
                        readEnableReg <= 0;
                        reading <= 0;
                        byte_ready <= 0;
                        
                        // Use current sector position
                        current_sector <= sector_base + sectors_read;
                        
                        if (sectors_read >= 72) begin
                            //done <= 1;  // Signal all sectors are read
                            main_state <= DONE;
                        //end else begin
                            //done <= 0;
                        end
                    end
                    
                    SD_WAIT_READY: begin
                        // Wait for SD careadEnable to be ready
                        if (sd_ready) begin
                            main_state <= READ_SD;
                        end
                    end
                    
                    READ_SD: begin
                        // Start reading if not already reading
                        if (sd_ready && !reading && !readEnable) begin
                            readEnableReg <= 1;
                            reading <= 1;
                        end else if (readEnable) begin
                            readEnableReg <= 0;  // Clear read signal after one clock cycle
                        end
                        
                        // Process bytes from SD careadEnable
                        if (reading && sd_data_ready) begin
                            // Handle 16-bit buffer writing (pair of bytes)
                            if (!byte_ready) begin
                                // Store first byte
                                byte_buffer <= sd_dataOut;
                                byte_ready <= 1;
                            end else begin
                                // Combine with second byte and write to buffer
                                buffer[buffer_addr_write] <= {byte_buffer, sd_dataOut};
                                buffer_addr_write <= buffer_addr_write + 1;
                                byte_ready <= 0;
                            end
                            
                            bytes_read <= bytes_read + 1;
                            
                            // Update debug LEDs with the last two bytes
//                            if (bytes_read[0])  // Every other byte
//                                led[15:8] <= sd_dout;
//                            else
//                                led[7:0] <= sd_dout;
                                
                            // Check if we've read a full sector (512 bytes)
                            if (bytes_read == 511) begin
                                reading <= 0;      // Stop reading
                                main_state <= WAIT_SECTOR;
                                sectors_read <= sectors_read + 1;  // Increment sector counter
                            end
                        end
                        
                        // Handle read completion
                        if (reading && sd_ready && !sd_data_ready && bytes_read > 0) begin
                            reading <= 0;
                            main_state <= WAIT_SECTOR;
                            sectors_read <= sectors_read + 1;  // Increment sector counter
                        end
                    end
                    
                    WAIT_SECTOR: begin
                        // Wait until SD controller is ready again
                        if (sd_ready) begin
                            if (sectors_read < 72) begin
                                main_state <= INIT;  // Read next sector
                            end else begin
                                main_state <= CALCULATE_CHECKSUM;  // All sectors read, calculate checksum
                                checksum <= 0;       // Reset checksum
                                checksum_addr <= 0;  // Start from first buffer address
                                checksum_state <= 0; // Reset checksum calculation state
                                //done <= 1;           // Signal all sectors are read
                            end
                        end
                    end
                    
                    CALCULATE_CHECKSUM: begin
                        case (checksum_state)
                            0: begin
                                // Add the current buffer value to checksum
                                checksum <= (checksum + buffer[checksum_addr]) % 65521; // Modulo 65521 (largest prime under 16 bits)
                                checksum_state <= 1;
                            end
                            1: begin
                                // Move to next address or finish
                                if (checksum_addr < buffer_addr_write - 1) begin // Check against actual data stored
                                    checksum_addr <= checksum_addr + 1;
                                    checksum_state <= 0; // Go back to state 0 for next read
                                end else begin
                                    main_state <= DISPLAY_CHECKSUM;
                                end
                                checksum_state <= 0;
                            end
                        endcase
                    end
                    
                    DISPLAY_CHECKSUM: begin
                        // Display the checksum on LEDs
                        //led <= checksum[15:0];  // Show the 16 least significant bits
                        main_state <= DONE;     // Move to DONE state
                    end
                    
                    DONE: begin
                        // Wait for button press to change sector group
                        //done <= 1;  // Signal all sectors are read
                        //led <= current_frame;
                        //led <= buffer[frame_base_addr + ((47 * 64) + 63)];
                        // Keep displaying the checksum - LEDs are not updated here anymore
                    end
                    
                    default: main_state <= INIT;
                endcase
            end
        end
    end
endmodule