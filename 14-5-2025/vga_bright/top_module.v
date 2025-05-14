module vga_test (
    input wire clk,
    input wire reset,
    input wire [1:0] sw,      // 2-bit input to select one of 4 images
    input wire [1:0] filter,  // 2-bit filter selector (0-3)
    output wire hsync,
    output wire vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);

    // VGA sync signals
    wire [9:0] x, y;
    wire video_on;

    // ROM interface
    wire [11:0] rom_data;
    wire [19:0] rom_addr;

    // Display window origin
    localparam X_START = (640 - 320) / 2;
    localparam Y_START = (480 - 240) / 2;

    // Image offset coordinates
    wire [8:0] img_x = x - X_START;
    wire [7:0] img_y = y - Y_START;

    // Inside image bounds
    wire in_image = (x >= X_START) && (x < X_START + 320) &&
                    (y >= Y_START) && (y < Y_START + 240);

    // Downscale to 160x120
    wire [7:0] orig_x = img_x >> 1;
    wire [6:0] orig_y = img_y >> 1;

    assign rom_addr = in_image ? (sw * 19200 + (orig_y * 160 + orig_x)) : 20'd0;

    // Instantiate VGA sync
    vga_sync vga_sync_unit (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .p_tick(), // unused
        .x(x),
        .y(y)
    );

    // Instantiate image ROM
    image_rom rom_unit (
        .clk(clk),
        .addr(rom_addr),
        .data(rom_data)
    );

    // Extract RGB channels
    wire [3:0] r = rom_data[11:8];
    wire [3:0] g = rom_data[7:4];
    wire [3:0] b = rom_data[3:0];

    wire [4:0] avg5 = (r + g + b) / 3;
    wire [3:0] avg = avg5[3:0];

    // Clamp helpers
    function [3:0] clamp_add(input [4:0] val);
        begin
            clamp_add = (val > 4'd15) ? 4'd15 : val[3:0];
        end
    endfunction

    function [3:0] clamp_sub(input [4:0] val);
        begin
            clamp_sub = (val[4]) ? 4'd0 : val[3:0];
        end
    endfunction

    // Filtered RGB Output
    assign vga_r = (video_on && in_image) ?
                   (filter == 2'b00) ? r :
                   (filter == 2'b01) ? ~r :
                   (filter == 2'b10) ? r :
                   (filter == 2'b11) ? clamp_add(avg + 1) :
                   4'd0 : 4'd0;

    assign vga_g = (video_on && in_image) ?
                   (filter == 2'b00) ? g :
                   (filter == 2'b01) ? ~g :
                   (filter == 2'b10) ? r :
                   (filter == 2'b11) ? avg :
                   4'd0 : 4'd0;

    assign vga_b = (video_on && in_image) ?
                   (filter == 2'b00) ? b :
                   (filter == 2'b01) ? ~b :
                   (filter == 2'b10) ? b :
                   (filter == 2'b11) ? clamp_sub(avg - 1) :
                   4'd0 : 4'd0;

endmodule
