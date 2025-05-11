module sd_controller (
    input clk,
    input reset,
    input start_read,
    input [31:0] block_address,
    output reg done,
    output reg [7:0] data_out,
    output reg data_valid,
    output reg [16:0] addr_out,

    // SPI interface
    output reg [7:0] spi_data_in,
    input [7:0] spi_data_out,
    output reg spi_start,
    input spi_done,
    input miso,
    output mosi,
    output cs,
    output sclk
);
    // SPI Instance
    reg spi_ready;
    spi_master spi (
        .clk(clk),
        .reset(reset),
        .start(spi_start),
        .data_in(spi_data_in),
        .data_out(spi_data_out),
        .done(spi_done),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs(cs)
    );
    //initialize state
    localparam IDLE = 0;
    localparam SEND_CMD0 = 1;
    localparam WAIT_CMD0 = 2;
    localparam SEND_CMD8 = 3;
    localparam WAIT_CMD8 = 4; //WAIT_R7
    localparam SEND_CMD55 = 5;
    localparam WAIT_CMD55 = 6;
    localparam SEND_ACMD41 = 7;
    localparam WAIT_ACMD41 = 8;
    localparam SEND_CMD16 = 9;
    localparam WAIT_CMD16 = 10;
    localparam SEND_CMD17 = 11;
    localparam WAIT_CMD17 = 12;
    localparam WAIT_FE = 13;
    localparam READ_BLOCK = 14;
    localparam DONE = 15;
    reg [3:0] state = IDLE;
    
    reg [5:0] cmd_number;
    reg [3:0] argument[7:0];
    reg [7:0] crc;
    wire [47:0] cmd;
    assign cmd = {1'b0, 1'b1, cmd_number, argument[0], argument[1], argument[2], argument[3], crc};
    reg [2:0] cmd_index;

    reg [7:0] response;
    reg [9:0] byte_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            spi_start <= 0;
            spi_data_in <= 8'hFF;
            done <= 0;
            data_valid <= 0;
            addr_out <= 0;
            byte_cnt <= 0;
        end else begin
            spi_start <= 0;
            data_valid <= 0;
            done <= 0;

            case (state)
                IDLE: begin
                    if (start_read) begin
                        cmd_index <= 0;
                        cmd_number <= 0; //CMD0
                        argument[0] <= 0;
                        argument[1] <= 0;
                        argument[2] <= 0;
                        argument[3] <= 0;
                        crc <= 8'h95; // CRC for CMD0
                        state <= SEND_CMD0;
                    end
                end

                SEND_CMD0, SEND_CMD8, SEND_CMD55, SEND_ACMD41, SEND_CMD16, SEND_CMD17: begin
                    if (~spi_start && cmd_index < 6) begin
                        spi_data_in <= cmd[cmd_index];
                        spi_start <= 1;
                        cmd_index <= cmd_index + 1;
                    end else if (spi_done && cmd_index == 6) begin
                        cmd_index <= 0;
                        state <= (state == SEND_CMD0) ? WAIT_CMD0 :
                                (state == SEND_CMD8) ? WAIT_CMD8 :
                                (state == SEND_CMD55) ? WAIT_CMD55 :
                                (state == SEND_ACMD41) ? WAIT_ACMD41 :
                                (state == SEND_CMD16) ? WAIT_CMD16 : WAIT_CMD17;
                    end
                end

                WAIT_CMD0, WAIT_CMD55, WAIT_ACMD41, WAIT_CMD16, WAIT_CMD17: begin
                    if (spi_done) begin
                        cmd_index <= 0;
                        response <= spi_data_out;
                        if (state == WAIT_CMD0 && spi_data_out == 1) begin
                            cmd_number <= 8'h08; // CMD8
                            argument[0] <= 8'h00;
                            argument[1] <= 8'h00;
                            argument[2] <= 8'h01;
                            argument[3] <= 8'hAA;
                            //crc <= 8'h87; // CRC for CMD8
                            crc <= 8'h0F; // CRC for CMD8
                            state <= SEND_CMD8;
                        end else if (state == WAIT_CMD55 && spi_data_out == 1) begin
                            cmd_number <= 41; // ACMD41
                            argument[0] <= 8'h40;
                            argument[1] <= 0;
                            argument[2] <= 0;
                            argument[3] <= 0;
                            crc <= 8'h01; // CRC for ACMD41
                            state <= SEND_ACMD41;
                        end else if (state == WAIT_ACMD41) begin
                            if (spi_data_out == 0) begin
                                // Ready, proceed to CMD16 to run CMD17
                                cmd_number <= 16; // CMD16
                                argument[0] <= 0; // 512 bytes
                                argument[1] <= 0;
                                argument[2] <= 2;
                                argument[3] <= 0;
                                crc <= 8'h01; // CRC for CMD16
                                state <= SEND_CMD16;
                            end else begin
                                // Retry CMD55
                                state <= SEND_CMD55;
                            end
                        end else if (state == WAIT_CMD16 && spi_data_out == 1) begin
                            // Ready, proceed to CMD17
                            cmd_number <= 17; // CMD17
                            argument[0] <= block_address[31:24];
                            argument[1] <= block_address[23:16];
                            argument[2] <= block_address[15:8];
                            argument[3] <= block_address[7:0];
                            crc <= 8'h01; // CRC for CMD17
                            state <= SEND_CMD17;
                        end else if (state == WAIT_CMD17) begin
                            if (spi_data_out == 0) begin
                                // Ready, proceed to read data
                                byte_cnt <= 0;
                                state <= READ_BLOCK;
                            end else begin
                                // Retry CMD17
                                state <= SEND_CMD17;
                            end
                        end else if (state == WAIT_CMD17 && spi_data_out == 0) begin
                            state <= WAIT_FE;
                        end else begin
                            // retry current command
                            state <= state - 1;
                        end
                    end
                end

                WAIT_CMD8: begin
                    if (~spi_start) begin
                        spi_data_in <= 8'hFF;
                        spi_start <= 1;
                        cmd_index <= cmd_index + 1;
                    end else if (spi_done && cmd_index < 5) begin
                        spi_start <= 0;
                    end else if (spi_done && cmd_index == 5) begin
                        cmd_index <= 0;
                        // Continue to CMD55 (init loop)
                        cmd_number <= 55; // CMD55
                        argument[0] <= 0;
                        argument[1] <= 0;
                        argument[2] <= 0;
                        argument[3] <= 0;
                        crc <= 8'h01;
                        state <= SEND_CMD55;
                    end
                end

                WAIT_FE: begin
                    if (~spi_start) begin
                        spi_data_in <= 8'hFF;
                        spi_start <= 1;
                    end else if (spi_done && spi_data_out == 8'hFE) begin
                        byte_cnt <= 0;
                        addr_out <= 0;
                        state <= READ_BLOCK;
                    end
                end

                READ_BLOCK: begin
                    if (~spi_start) begin
                        spi_data_in <= 8'hFF;
                        spi_start <= 1;
                    end else if (spi_done) begin
                        data_out <= spi_data_out;
                        data_valid <= 1;
                        addr_out <= byte_cnt;
                        byte_cnt <= byte_cnt + 1;
                        if (byte_cnt == 511)
                            state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
