module image_rom (
    input wire clk,
    input wire [16:0] addr,  // 0-76799 for 4 images of 19200 each
    output reg [11:0] data
);

    // ROM memory for 4 images of 160x120 = 4 * 19200 = 76800 pixels
    reg [11:0] rom [0:76799];

    initial begin
        $readmemh("image.mem", rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
