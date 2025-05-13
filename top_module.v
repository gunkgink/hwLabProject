`timescale 1ns / 1ps

module top_module (
    // sd card interface
    input wire clk100, // 100 MHz clock
    input wire reset, // active high reset
    input wire button, // button input
    input miso // sd card data input
    output mosi, // sd card data output
    output sclk, // sd card clock
    output cs, // sd card chip select

    //VGA
    input sw,                // switch input for image selection
    output wire hsync,       // VGA horizontal sync
    output wire vsync,       // VGA vertical sync
    input wire [11:0] rgb   // VGA RGB output 
);

// VGA signals
wire [9:0] x, y;
wire video_on;

// basic signal declarations
wire clk25;  // 25 MHz clock for VGA
wire locked; // Clock locked signal
wire rst = ~locked | reset; // Reset signal for the design

//SD CARD
reg readEnable = 0;
wire [7:0] sd_dataOut;
wire sd_data_ready;
wire sd_ready;
wire [4:0] status;

//DEBOUNCER
wire btn_debounced;

//ROM
wire [11:0] read_data;
wire [16:0] read_addr; 

// Sector reading logic
reg [31:0] current_sector = 32'd0;    // Current sector being read (0-71)
reg [31:0] sector_base = 32'd0;       // Base sector for the current group
reg [9:0] bytes_read = 0;            // Counter for bytes read in current sector
reg reading = 0;               // Flag to indicate reading in progress
reg [6:0] sectors_read = 0;          // Counter for number of sectors read (0-71)

// VGA-related signals
wire video_on;         // VGA display active area
wire p_tick;           // 25MHz pixel clock tick
wire [9:0] pixel_x, pixel_y; // Current pixel coordinates

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
    .reset(reset),
    .ready(sd_ready),
    .address(current_sector),
    .status(status),
);

debouncer debouncer (
    .clk(clk25),
    .reset(reset),
    .button_in(sw),
    .button_out(btn_debounced)
);

assign read_addr = in_image ? (sw * 19200 + (orig_y * 160 + orig_x)) : 20'd0;

image_processor image_processor(
    .clk(clk25),
    .reset(reset),
    // SD card interface
    .sd_data_in(sd_dataOut),
    .sd_data_valid(sd_data_ready),
    .sd_block_addr(current_sector),
    .sd_read_block(readEnable), //read_enable of sd_controller
    .sd_ready(sd_ready),
    // Image control
    .image_select(btn_debounced),
    .addrb(read_addr),
    .dataOut(read_data) // 12-bit color //rgb
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
    .reset(reset),
	.hsync(hsync),
    .vsync(vsync),
    .video_on(),
    .p_tick(),
    .x(),
    .y()
);


endmodule