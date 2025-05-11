module vga_controller(
    input clk25,   // 25 MHz pixel clock
    input reset,
    output hsync,
    output vsync,
    output [11:0] rgb,         // New: packed RGB output
    output [16:0] pixel_addr,
    input [7:0] pixel_data     // Assuming grayscale or 8-bit index
);

    reg [9:0] h_count = 0, v_count = 0;
    wire visible;

    assign visible = (h_count < 640 && v_count < 480);
    assign hsync = ~(h_count >= 656 && h_count < 752);
    assign vsync = ~(v_count >= 490 && v_count < 492);

    // Map 8-bit pixel data to 4-4-4 RGB
    wire [3:0] r = visible ? pixel_data[7:5] << 1 : 0;
    wire [3:0] g = visible ? pixel_data[4:2] << 1 : 0;
    wire [3:0] b = visible ? pixel_data[1:0] << 2 : 0;

    assign rgb = {r, g, b};

    // Convert 640x480 to 320x240 image by skipping every other pixel
    assign pixel_addr = (v_count >> 1) * 320 + (h_count >> 1);

    always @(posedge clk25) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            h_count <= (h_count == 799) ? 0 : h_count + 1;
            if (h_count == 799)
                v_count <= (v_count == 524) ? 0 : v_count + 1;
        end
    end
endmodule
