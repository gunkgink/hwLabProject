module vga_test (
    input wire clk, reset,
    input wire [1:0] sw,  // 2-bit input for switch (selects one of 4 images)
    output wire hsync, vsync,
    output wire [11:0] rgb
);

    // VGA signals
    wire [9:0] x, y;
    wire video_on;

    // ROM interface
    wire [11:0] rom_data;
    wire [19:0] rom_addr;  // Total ROM size: 4 images * 320*240 = 307200 entries

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
    
    assign rom_addr = in_image ? (sw * 19200 + (orig_y * 160 + orig_x)) : 20'd0;
    // 160x120 = 19200 pixels per image

    // Instantiate VGA sync module
    vga_sync vga_sync_unit (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .p_tick(),  // Ignored here
        .x(x),
        .y(y)
    );

    // Instantiate image ROM
    image_rom rom_unit (
        .clk(clk),
        .addr(rom_addr),
        .data(rom_data)
    );

    // Output RGB only when visible and in image
    assign rgb = (video_on && in_image) ? rom_data : 12'b0;

endmodule
