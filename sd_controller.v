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