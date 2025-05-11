module spi_master(
    input clk,              // 50 MHz system clock
    input reset,
    input start,
    input [7:0] data_in,
    output reg [7:0] data_out,
    output reg done,
    output reg sclk,
    output reg mosi,
    input miso,
    output reg cs
);
    reg [4:0] bit_cnt;
    reg [7:0] shift_reg;

    localparam IDLE = 0, TRANSFER = 1, DONE = 2;
    reg [1:0] state;

    reg [7:0] clk_div;
    wire tick;
    assign tick = (clk_div == 8'd124); // 50MHz / (2*125) = 200kHz SPI

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            cs <= 1;
            sclk <= 1;
            clk_div <= 0;
            done <= 0;
        end else begin
            clk_div <= tick ? 0 : clk_div + 1;

            if (tick) begin
                case (state)
                    IDLE: begin
                        if (start) begin
                            state <= TRANSFER;
                            shift_reg <= data_in;
                            bit_cnt <= 0;
                            cs <= 0;
                            sclk <= 0;
                            done <= 0;
                        end
                    end
                    TRANSFER: begin
                        mosi <= shift_reg[7];
                        sclk <= ~sclk;
                        if (sclk == 1) begin
                            shift_reg <= {shift_reg[6:0], miso};
                            bit_cnt <= bit_cnt + 1;
                            if (bit_cnt == 7) state <= DONE;
                        end
                    end
                    DONE: begin
                        data_out <= shift_reg;
                        done <= 1;
                        cs <= 1;
                        state <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule
