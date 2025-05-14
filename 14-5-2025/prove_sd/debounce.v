module debounce (
    input      clk,
    input      reset,
    input      btn_in,
    output reg btn_out
);
    parameter DEBOUNCE_PERIOD = 250000;  // 10ms at 25MHz
    
    reg [19:0] counter = 0;
    reg        btn_state = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            btn_state <= 0;
            btn_out <= 0;
        end else begin
            if (btn_in != btn_state) begin
                // Button state changed, start counting
                counter <= 0;
                btn_state <= btn_in;
            end else if (counter < DEBOUNCE_PERIOD) begin
                // Still counting
                counter <= counter + 1;
            end else begin
                // Debounce period elapsed, update output
                btn_out <= btn_state;
            end
        end
    end
endmodule