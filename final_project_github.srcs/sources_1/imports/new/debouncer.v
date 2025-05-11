module debouncer (
    input clk,            // 100 MHz clock
    input reset,
    input noisy_in,       // Raw button input
    output reg clean_out  // Debounced output (1-clock pulse)
);
    reg [19:0] count;     // ~10ms debounce time @ 100MHz
    reg state, prev_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            state <= 0;
            clean_out <= 0;
            prev_state <= 0;
        end else begin
            if (noisy_in == state)
                count <= 0;
            else begin
                count <= count + 1;
                if (count == 20'd999_999) begin // ~10ms
                    state <= noisy_in;
                    count <= 0;
                end
            end

            // Generate one-clock pulse on rising edge
            clean_out <= (state == 1 && prev_state == 0);
            prev_state <= state;
        end
    end
endmodule
