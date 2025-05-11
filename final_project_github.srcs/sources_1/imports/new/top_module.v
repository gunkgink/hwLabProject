module top_module(
    input clk,
    input reset,
    input btn,               // For image switching
    output hsync,
    output vsync,
    output [11:0] rgb,

    // SD card SPI
    output sclk,
    output mosi,
    input miso,
    output cs
);
    wire clk25;
    wire [16:0] pixel_addr;
    wire [7:0] pixel_data;

    // Clock divider or Clock Wizard for 25 MHz
    clk_wiz_0 clk_gen(
        .clk_in1(clk),
        .clk_out1(clk25)
    );

    wire [7:0] sd_data;
    wire sd_we;
    wire [16:0] sd_addr;

    // SD controller would control BRAM writing here
    sd_controller sd (
        .clk(clk),
        .reset(reset),
        .start_read(btn), // Simple trigger
        .block_address(0),
        .done(),
        .data_out(sd_data),
        .data_valid(sd_we),
        .addr_out(sd_addr),
        .spi_data_in(),
        .spi_data_out(),
        .spi_start(),
        .spi_done(),
        .miso(miso),
        .mosi(mosi),
        .cs(cs),
        .sclk(sclk)
    );

    frame_buffer fb (
        .clk(clk),
        .we(sd_we),
        .write_addr(sd_addr),
        .write_data(sd_data),
        .read_addr(pixel_addr),
        .read_data(pixel_data)
    );
    
    vga_controller vga (
        .clk25(clk25),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb),
        .pixel_addr(pixel_addr),
        .pixel_data(pixel_data)
    );
    
    wire debounced_btn;

    debouncer db (
        .clk(clk),
        .reset(reset),
        .noisy_in(btn),
        .clean_out(debounced_btn)
    );
endmodule
