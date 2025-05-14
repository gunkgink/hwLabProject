module rgb_processor(
    input [9:0] x,
    input [9:0] y,
    input video_on,
    output reg [3:0] vga_red,
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,

    input reg [15:0] buffer [0:18431],
    input reg [3:0]  main_state
);

// Color and pixel address calculation
wire [15:0] pixel_data; // Current pixel color data
reg [12:0] scaled_x, scaled_y;
//buffer
reg [12:0] buffer_pixel_addr;
wire [14:0] buffer_addr_read;
// Scale coordinates from 640x480 to 64x48
always @* begin
    scaled_x = pixel_x / 10;  // 640/64 = 10
    scaled_y = pixel_y / 10;  // 480/48 = 10
        
    // Calculate pixel address within the buffer
    buffer_pixel_addr = (scaled_y * 64) + scaled_x;
end
    

   
// Assign buffer read address for VGA display
//assign buffer_addr_read = (scaled_x < 64 && scaled_y < 48) ? frame_base_addr + buffer_pixel_addr : frame_base_addr; // Default to first pixel if out of bounds
assign buffer_addr_read = (scaled_x < 64 && scaled_y < 48) ? buffer_pixel_addr : 0; // Default to first pixel if out of bounds
    
// Get data from buffer
//assign led = tled;
assign pixel_data = (video_on && main_state == DONE) ? buffer[buffer_addr_read] : 16'h0000;
    
// Extract RGB components (assuming 16-bit RGB565 format)
assign vga_red = video_on ? pixel_data[15:12] : 4'h0; // Red: bits 15-11, take top 4
assign vga_green = video_on ? pixel_data[10:7] : 4'h0;  // Green: bits 10-5, take middle 4
assign vga_blue = video_on ? pixel_data[4:1] : 4'h0;   // Blue: bits 4-0, take top 4

endmodule