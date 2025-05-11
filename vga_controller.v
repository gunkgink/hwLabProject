`timescale 1ns / 1ps

module vga_controller(
    input clk,              // 25MHz clock
    input reset,
    output reg hsync,       // Horizontal sync
    output reg vsync,       // Vertical sync
    output reg [11:0] rgb,  // 12-bit RGB (4-4-4)
    output reg [9:0] pixel_x, // Current pixel X position
    output reg [9:0] pixel_y, // Current pixel Y position
    output reg display_on   // Display enable flag
);

    // VGA 320x240 @ 60Hz timings (25MHz pixel clock)
    parameter H_DISPLAY = 320;
    parameter H_FRONT = 8;
    parameter H_SYNC = 40;
    parameter H_BACK = 48;
    parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;
    
    parameter V_DISPLAY = 240;
    parameter V_FRONT = 3;
    parameter V_SYNC = 4;
    parameter V_BACK = 15;
    parameter V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;
    
    reg [9:0] h_count;
    reg [9:0] v_count;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
            hsync <= 1;
            vsync <= 1;
            display_on <= 0;
        end else begin
            // Horizontal counter
            if (h_count < H_TOTAL - 1)
                h_count <= h_count + 1;
            else begin
                h_count <= 0;
                // Vertical counter
                if (v_count < V_TOTAL - 1)
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
            end
            
            // Generate sync pulses (active low)
            hsync <= !((h_count >= H_DISPLAY + H_FRONT) && 
                       (h_count < H_DISPLAY + H_FRONT + H_SYNC));
            
            vsync <= !((v_count >= V_DISPLAY + V_FRONT) && 
                       (v_count < V_DISPLAY + V_FRONT + V_SYNC));
            
            // Set display area
            display_on <= (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
            
            // Current pixel position
            pixel_x <= h_count;
            pixel_y <= v_count;
        end
    end
    
endmodule