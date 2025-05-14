module top_sd_display(
    input clk,                      // 100 MHz Basys clock
    input reset,
    input miso,
    input rd,
    input wr,
    input [7:0] din,
    input [31:0] address,
    
    output mosi,
    output sclk,
    output cs,
    output [6:0] seg0,       // Lower nibble
    output [6:0] seg1,       // Upper nibble
    output [3:0] an          // Common anode control
);

    wire [7:0] dout;
    wire byte_available;
    wire ready;
    wire [15:0] debug;
    wire ready_for_next_byte;
    wire [4:0] status;
    
    assign an = 4'b1110; // Enable only seg0 (digit 0) and seg1 (digit 1)

    sd_controller sd_inst (
        .clk(clk),
        .reset(reset),
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .rd(rd),
        .wr(wr),
        .din(din),
        .dout(dout),
        .byte_available(byte_available),
        .ready_for_next_byte(ready_for_next_byte),
        .ready(ready),
        .address(address),
        .status(status),
        .fuck(debug)
    );

    wire [3:0] upper_nibble = dout[7:4];
    wire [3:0] lower_nibble = dout[3:0];

    seven_seg_decoder seg_l (
        .nibble(lower_nibble),
        .seg(seg0)
    );

    seven_seg_decoder seg_u (
        .nibble(upper_nibble),
        .seg(seg1)
    );

endmodule
