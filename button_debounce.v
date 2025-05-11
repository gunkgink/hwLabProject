`timescale 1ns / 1ps

module debouncer(
    input clk,
    input button_in,
    output reg button_out
);

    reg [19:0] counter;
    reg button_sync;
    
    always @(posedge clk) begin
        // Synchronize button input
        button_sync <= button_in;
        
        // Debounce logic
        if (button_out == button_sync) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
            if (counter == 20'd999999) begin // 20ms at 50MHz
                button_out <= button_sync;
                counter <= 0;
            end
        end
    end
    
endmodule