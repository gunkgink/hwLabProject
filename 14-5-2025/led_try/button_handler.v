module button_handler (
    input        clk,
    input        reset,
    input        btn_in,
    input  [1:0] main_state,  // Adjust width as needed
    output reg   change_sector_group
);
    parameter DEBOUNCE_PERIOD = 250000;  // 10ms at 25MHz
    parameter DONE = 2'b10;              // Example encoding of DONE state

    reg [19:0] counter = 0;
    reg        btn_state = 0;
    reg        btn_out = 0;
    reg        btn_prev = 0;
    reg        btn_pressed = 0;

    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            btn_state <= 0;
            btn_out <= 0;
            btn_prev <= 0;
            btn_pressed <= 0;
            change_sector_group <= 0;
        end else begin
            // --- Debounce Logic ---
            if (btn_in != btn_state) begin
                counter <= 0;
                btn_state <= btn_in;
            end else if (counter < DEBOUNCE_PERIOD) begin
                counter <= counter + 1;
            end else begin
                btn_out <= btn_state;
            end

            // --- Edge Detection ---
            btn_prev <= btn_out;
            btn_pressed <= ~btn_prev & btn_out;

            // --- Output Control ---
            if (btn_pressed && main_state == DONE) begin
                change_sector_group <= 1;
            end else begin
                change_sector_group <= 0;
            end
        end
    end
endmodule
