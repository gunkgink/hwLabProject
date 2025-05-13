<<<<<<< Updated upstream
    `timescale 1ns / 1ps

module sd_controller(
    input clk,              // 50MHz clock
    input reset,
    // Physical interface
    output reg cs,          // Chip select (active low)
    output reg sclk,        // SPI clock
    output reg mosi,        // Master out slave in
    input miso,             // Master in slave out
    // Logical interface
    input [31:0] block_addr,// Block address to read
    input read_block,       // Trigger block read
    output reg [7:0] data_out, // Data from SD card
    output reg data_valid,  // Data valid flag
    output reg busy         // Controller busy flag
);

    // States
    localparam STATE_IDLE       = 0;
    localparam STATE_INIT       = 1;
    localparam STATE_CMD0       = 2;
    localparam STATE_CMD8       = 3;
    localparam STATE_CMD55      = 4;
    localparam STATE_ACMD41     = 5;
    localparam STATE_READ_CMD   = 6;
    localparam STATE_READ_WAIT  = 7;
    localparam STATE_READ_DATA  = 8;
    localparam STATE_READ_END   = 9;
    
    reg [3:0] state = STATE_IDLE;
    reg [3:0] next_state;
    
    // SPI signals
    reg [7:0] spi_data_out;
    reg spi_start;
    wire spi_busy;
    wire [7:0] spi_data_in;
    
    // Command signals
    reg [47:0] cmd;
    reg [5:0] cmd_index;
    reg cmd_start;
    wire cmd_busy;
    wire cmd_response;
    
    // Data receive signals
    reg [8:0] data_counter;
    reg [7:0] data_buffer[511:0];
    reg data_receiving;
    
    // Initialize SD card in SPI mode
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            cs <= 1'b1;
            sclk <= 1'b0;
            mosi <= 1'b1;
            busy <= 1'b0;
            cmd_start <= 1'b0;
            data_receiving <= 1'b0;
            data_valid <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (read_block) begin
                        state <= STATE_READ_CMD;
                        busy <= 1'b1;
                    end
                end
                
                STATE_READ_CMD: begin
                    // Send CMD17 (READ_SINGLE_BLOCK)
                    cmd <= {8'h51, block_addr, 8'hFF};
                    cmd_start <= 1'b1;
                    if (cmd_busy) cmd_start <= 1'b0;
                    if (!cmd_busy && cmd_start == 1'b0) begin
                        if (cmd_response) begin
                            state <= STATE_READ_WAIT;
                        end else begin
                            state <= STATE_IDLE; // Error
                        end
                    end
                end
                
                STATE_READ_WAIT: begin
                    // Wait for data token (0xFE)
                    if (spi_data_in == 8'hFE) begin
                        state <= STATE_READ_DATA;
                        data_counter <= 0;
                        data_receiving <= 1'b1;
                    end
                end
                
                STATE_READ_DATA: begin
                    if (data_counter < 512) begin
                        data_buffer[data_counter] <= spi_data_in;
                        data_counter <= data_counter + 1;
                    end else begin
                        // CRC bytes (ignored)
                        state <= STATE_READ_END;
                        data_receiving <= 1'b0;
                    end
                end
                
                STATE_READ_END: begin
                    data_valid <= 1'b1;
                    data_out <= data_buffer[0]; // First byte
                    state <= STATE_IDLE;
                    busy <= 1'b0;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
    
    // SPI interface
    always @(posedge clk) begin
        if (spi_start && !spi_busy) begin
            // Shift out data
            mosi <= spi_data_out[7];
            spi_data_out <= {spi_data_out[6:0], 1'b0};
        end
        if (!spi_busy) sclk <= ~sclk;
    end
    
    assign spi_data_in = {miso, spi_data_out[6:0]};
    
endmodule
||||||| Stash base
=======
`timescale 1ns / 1ps

module sd_controller (
    output reg cs,
    output sclk,
    output mosi,
    input miso,
    input readEnable,
    output reg [7:0] dataOut,
    output reg data_ready,
    input clk,
    input reset,
    output ready,
    input [31:0] address,
    output [4:0] status
);

    localparam RESET  = 0;
    localparam INIT = 1;
    localparam CMD0 = 2;
    localparam CMD8 = 3;
    localparam CMD58 = 4;
    localparam CMD55 = 5;
    localparam ACMD41 = 6;
    localparam POLL_CMD = 7;
    localparam IDLE = 8;
    localparam CMD16 = 9;
    localparam READ_BLOCK = 10; //CMD17
    localparam READ_BLOCK_WAIT = 11;
    localparam READ_BLOCK_DATA = 12;
    localparam READ_BLOCK_CRC = 13;
    localparam SEND_CMD = 14;
    localparam RECEIVE_BYTE_WAIT = 15;
    localparam RECEIVE_BYTE = 16;

    reg [4:0] state = RESET;
    assign status = state;

    reg [4:0] return_state;
    reg sclk_signal = 0;
    reg [55:0] cmd_out; //8 buffer bits + 48 data bits
    reg [7:0] response;
    
    reg [9:0] byte_count;
    reg [9:0] bit_count;

    reg [26:0] reset_buffer = 27'd100_000_000;


    always@(posedge clk) begin
        if (reset) begin
            state <= RESET;
            sclk_signal <= 0;
            reset_buffer <= 27'd100_000_000;
        end else begin
            case (state)
                RESET: begin
                    if (reset_buffer == 0) begin
                        state <= INIT;
                        sclk_signal <= 0;
                        cmd_out <= {56{1'b1}};
                        byte_count <= 0;
                        data_ready <= 0;
                        bit_count <= 180; // minimum 74 cycles
                        cs <= 1;
                    end else begin
                        reset_buffer <= reset_buffer - 1;
                    end
                end

                INIT: begin
                    if (bit_count == 0) begin
                        state <= CMD0;
                        cs <= 0;
                    end else begin
                        bit_count <= bit_count - 1;
                        sclk_signal <= ~sclk_signal;
                    end
                end

                CMD0: begin
                    state <= SEND_CMD;
                    return_state <= CMD8;
                    cmd_out <= {8'hFF ,2'b01, 6'd0, 32'h00_00_00_00, 8'h95};
                    bit_count <= 55;
                end

                CMD8: begin
                    state <= SEND_CMD;
                    return_state <= CMD55;
                    cmd_out <= {8'hFF, 2'b01, 6'd8, 32'h00_00_01_AA, 8'h87};
                    bit_count <= 55;
                end

                CMD58: begin
                    state <= SEND_CMD;
                    return_state <= CMD55;
                    cmd_out <= {8'hFF ,2'b01, 6'd58, 32'h00_00_00_00, 8'h95};
                    bit_count <= 55;
                end

                CMD55: begin
                    state <= SEND_CMD;
                    return_state <= ACMD41;
                    cmd_out <= {8'hFF ,2'b01, 6'd55, 32'h00_00_00_00, 8'h65};
                    bit_count <= 55;
                end

                ACMD41: begin
                    state <= SEND_CMD;
                    return_state <= POLL_CMD;
                    cmd_out <= {8'hFF ,2'b01, 6'd41, 32'h40_00_00_00, 8'h77};
                    bit_count <= 55;
                end

                POLL_CMD: begin
                    if(response[0] == 0) begin
                        state <= IDLE;
                    end else begin
                        state <= CMD55; // Retry ACMD41 sequence
                    end
                end

                IDLE: begin
                    if(readEnable == 1) begin
                        state <= CMD16;
                    end else begin
                        state <= IDLE; // Retry ACMD41 sequence
                    end
                end

                CMD16: begin
                    state <= SEND_CMD;
                    return_state <= READ_BLOCK;
                    cmd_out <= {8'hFF, 2'b01, 6'd16, 32'd512, 8'h2B};
                    bit_count <= 55;
                end

                READ_BLOCK: begin //CMD17
                    state <= SEND_CMD;
                    return_state <= READ_BLOCK_WAIT;
                    cmd_out <= {8'hFF, 2'b01, 6'd17, address, 8'hFF};
                    bit_count <= 55;
                end

                READ_BLOCK_WAIT: begin
                    if(sclk_signal == 1 && miso == 0) begin
                        byte_count <= 511;
                        bit_count <= 7;
                        return_state <= READ_BLOCK_DATA;
                        state <= RECEIVE_BYTE;
                    end
                    sclk_signal <= ~sclk_signal;
                end

                READ_BLOCK_DATA: begin
                    dataOut <= response;
                    data_ready <= 1;
                    if (byte_count == 0) begin
                        bit_count <= 7;
                        return_state <= READ_BLOCK_CRC;
                        state <= RECEIVE_BYTE;
                    end else begin
                        byte_count <= byte_count - 1;
                        return_state <= READ_BLOCK_DATA;
                        bit_count <= 7;
                        state <= RECEIVE_BYTE;
                    end
                end

                READ_BLOCK_CRC: begin
                    bit_count <= 7;
                    return_state <= POLL_CMD;
                    state <= RECEIVE_BYTE;
                end

                SEND_CMD: begin
                    if (sclk_signal == 1) begin
                        if (bit_count == 0) begin
                            state <= RECEIVE_BYTE_WAIT;
                        end
                        else begin
                            bit_count <= bit_count - 1;
                            cmd_out <= {cmd_out[54:0], 1'b1};
                        end
                    end
                end

                RECEIVE_BYTE_WAIT: begin
                    if (sclk_signal == 1) begin
                        if (miso == 0) begin
                            response <= 0;
                            bit_count <= 6;
                            state <= RECEIVE_BYTE;
                        end
                    end
                end

                RECEIVE_BYTE: begin
                    data_ready <= 0;
                    if (sclk_signal == 1) begin
                        response <= {response[6:0], miso};
                        if (bit_count == 0) begin
                            state <= return_state;
                        end
                        else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                end
            endcase
        end
    end
    assign sclk = sclk_signal;
    assign mosi = cmd_out[55];
    assign ready = (state == IDLE);

endmodule
>>>>>>> Stashed changes
