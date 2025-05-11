`timescale 1ns / 1ps

module image_selector(
    input clk,
    input reset,
    input btn_pressed,
    output reg [3:0] image_select
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            image_select <= 0;
        end else if (btn_pressed) begin
            if (image_select < 3)
                image_select <= image_select + 1;
            else
                image_select <= 0;
        end
    end
    
endmodule