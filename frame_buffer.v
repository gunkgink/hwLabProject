`timescale 1ns / 1ps

module frame_buffer_12bit(
    // Port A (write from SD card)
    input clka,
    input wea,
    input [16:0] addra,
    input [11:0] dina,      // Now 12-bit color
    // Port B (read for VGA)
    input clkb,
    input [16:0] addrb,
    output [11:0] doutb     // Now 12-bit color
);

    // 320x240 = 76800 pixels (17-bit address)
    reg [11:0] ram [0:76799]; // 12-bit color depth
    
    // Port A (write)
    always @(posedge clka) begin
        if (wea)
            ram[addra] <= dina;
    end
    
    // Port B (read)
    assign doutb = ram[addrb];
    
endmodule