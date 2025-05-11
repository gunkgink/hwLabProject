`timescale 1ns / 1ps

module sd_vga_top(
    input clk,                  // 100MHz Basys 3 clock
    input reset,                // CPU reset button
    input [3:0] btn,            // For image switching
    // SD card SPI interface
    output sd_cs,               // SD card chip select (active low)
    output sd_sclk,             // SD card serial clock
    output sd_mosi,             // SD card master out slave in
    input sd_miso,              // SD card master in slave out
    // VGA output
    output hsync,               // VGA horizontal sync
    output vsync,               // VGA vertical sync
    output [3:0] vga_r,         // VGA red (4 bits)
    output [3:0] vga_g,         // VGA green (4 bits)
    output [3:0] vga_b          // VGA blue (4 bits)
);

    // Clock signals
    wire clk_25mhz;
    wire clk_50mhz;
    wire clk_locked;
    
    // VGA signals
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire [11:0] rgb;            // 12-bit RGB (R[3:0], G[3:0], B[3:0])
    wire display_on;
    
    // SD card interface signals
    wire [7:0] sd_data_out;
    wire sd_data_valid;
    wire [31:0] sd_block_addr;
    wire sd_read_block;
    wire sd_busy;
    
    // Frame buffer signals
    wire [16:0] fb_write_addr;
    wire [11:0] fb_write_data;  // Now 12-bit color
    wire fb_write_en;
    wire [16:0] fb_read_addr;
    wire [11:0] fb_read_data;
    
    // Image control signals
    wire btn_pressed;
    wire [3:0] image_select;
    
    // ==============================================
    // Clock generation (100MHz -> 25MHz for VGA)
    // ==============================================
    clk_wiz_0 clk_gen (
        .clk_in1(clk),
        .clk_out1(clk_25mhz),  // 25MHz for VGA
        .clk_out2(clk_50mhz),   // 50MHz for SD card
        .locked(clk_locked),
        .reset(reset)
    );
    
    // ==============================================
    // SD Card Controller (unchanged)
    // ==============================================
    sd_controller sd_ctrl (
        .clk(clk_50mhz),
        .reset(reset || !clk_locked),
        .cs(sd_cs),
        .sclk(sd_sclk),
        .mosi(sd_mosi),
        .miso(sd_miso),
        .block_addr(sd_block_addr),
        .read_block(sd_read_block),
        .data_out(sd_data_out),
        .data_valid(sd_data_valid),
        .busy(sd_busy)
    );
    
    // ==============================================
    // Frame Buffer (BRAM) - Updated for 12-bit color
    // ==============================================
    frame_buffer_12bit fb (
        // Port A (write from SD card)
        .clka(clk_50mhz),
        .wea(fb_write_en),
        .addra(fb_write_addr),
        .dina(fb_write_data),
        // Port B (read for VGA)
        .clkb(clk_25mhz),
        .addrb(fb_read_addr),
        .doutb(fb_read_data)
    );
    
    // ==============================================
    // VGA Controller (unchanged)
    // ==============================================
    vga_controller vga (
        .clk(clk_25mhz),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .display_on(display_on)
    );
    
    // ==============================================
    // Image Data Processor - Updated for 12-bit RGB
    // ==============================================
    image_processor_12bit img_proc (
        .clk(clk_50mhz),
        .reset(reset),
        // SD card interface
        .sd_data_in(sd_data_out),
        .sd_data_valid(sd_data_valid),
        .sd_block_addr(sd_block_addr),
        .sd_read_block(sd_read_block),
        .sd_busy(sd_busy),
        // Frame buffer interface
        .fb_write_addr(fb_write_addr),
        .fb_write_data(fb_write_data),
        .fb_write_en(fb_write_en),
        // Image control
        .image_select(image_select)
    );
    
    // ==============================================
    // Button Debouncer and Image Selector (unchanged)
    // ==============================================
    debouncer btn_db (
        .clk(clk_25mhz),
        .button_in(btn[0]),  // Use btn[0] to switch images
        .button_out(btn_pressed)
    );
    
    image_selector img_sel (
        .clk(clk_25mhz),
        .reset(reset),
        .btn_pressed(btn_pressed),
        .image_select(image_select)
    );
    
    // ==============================================
    // VGA Output Mapping
    // ==============================================
    assign fb_read_addr = (display_on) ? (pixel_y * 320 + pixel_x) : 0;
    assign rgb = fb_read_data;
    assign vga_r = rgb[11:8];
    assign vga_g = rgb[7:4];
    assign vga_b = rgb[3:0];

endmodule