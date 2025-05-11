module frame_buffer(
    input clk,
    input we,
    input [16:0] write_addr, // Up to 76800
    input [7:0] write_data,
    input [16:0] read_addr,
    output reg [7:0] read_data
);
    reg [7:0] mem [0:76799];

    always @(posedge clk) begin
        if (we)
            mem[write_addr] <= write_data;
        read_data <= mem[read_addr];
    end
endmodule
