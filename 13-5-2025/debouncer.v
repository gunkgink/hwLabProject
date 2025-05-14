`timescale 1ns / 1ps

module debouncer(
    input clk,
    input reset,
    input button_in,
    output reg button_out
);
    localparam DEBOUNCE_PERIOD = 250000;
    reg [19:0] counter;
    reg button_sync;
    
    always @(posedge clk) begin
        if (reset) begin
            button_out <= 0;
            counter <= 0;
            button_sync <= 0;
        end
        else begin
            // Synchronize button input
            if (button_in != button_sync) begin
                counter <= 0;
                button_sync <= button_in;
            end
            else begin
                counter <= counter + 1;
                if (counter == DEBOUNCE_PERIOD) begin // 20ms at 50MHz
                    button_out <= button_sync;
                    // counter <= 0;
                end
            end
        end

    end
    
endmodule