module main(
    input clk,
    input reset, //rst
    output [3:0] main,
    output wire readEnable,
    output wire [31:0] current_sectorWire,
    input change_sector_group,
    input ready,
    input byte_available,
    input [7:0] sd_dout
);

localparam INIT = 0,
            SD_WAIT_READY = 1,
            READ_SD = 2,
            WAIT_SECTOR = 3,
            DONE = 4,
            CALCULATE_CHECKSUM = 5,
            DISPLAY_CHECKSUM = 6;

reg readEnableReg;
assign readEnable = readEnableReg;
reg main_state;
assign main = main_state;
//buffer
reg [11:0] buffer[0:18431]; // 64x48 pixel buffer (12-bit color)
reg [14:0] buffer_addr_write = 0;
// Sector reading logic
//current_sector = 32'd0;    // Current sector being read (0-71)
reg [31:0] current_sector;
assign current_sectorWire = current_sector;
reg [31:0] sector_base = 32'd0;       // Base sector for the current group
reg [9:0] bytes_read = 0;            // Counter for bytes read in current sector
reg reading = 0;               // Flag to indicate reading in progress
reg [6:0] sectors_read = 0;          // Counter for number of sectors read (0-71)
// Byte pairing for 16-bit buffer storage
reg [7:0] byte_buffer;     // Buffer for first byte in the pair
reg byte_ready = 0;  // Flag indicating byte buffer has data
// Checksum calculation
reg [31:0] checksum = 0;        // Holds the running sum (needs to be 32-bit to handle overflow before modulo)
reg [14:0] checksum_addr = 0;   // Address counter for reading buffer during checksum calculation
reg [1:0] checksum_state = 0;  // Sub-state for checksum calculation

always @(posedge clk) begin
        if (reset) begin
            main_state <= INIT;
            readEnableReg <= 0;
            reading <= 0;
            buffer_addr_write <= 0;
            bytes_read <= 0;
            //led <= 16'h0000;
            //done <= 0;
            byte_ready <= 0;
            checksum <= 0;
            checksum_addr <= 0;
            checksum_state <= 0;
            // Initialize sector variables
            sector_base <= 32'd0;
            current_sector <= 32'd0;
            sectors_read <= 0;
        end else begin
            // Handle sector group change request from button press
            if (change_sector_group) begin
                // Change sector group when button is pressed and we're in DONE state
                // Cycle through the 6 sector groups
                if (sector_base == 0)          sector_base <= 32'd100;    // Move to Sectors 100-171
                else if (sector_base == 100)   sector_base <= 32'd200;    // Move to Sectors 200-271
                else if (sector_base == 200)   sector_base <= 32'd300;    // Move to Sectors 300-371
                else if (sector_base == 300)   sector_base <= 32'd400;    // Move to Sectors 400-471
                else if (sector_base == 400)   sector_base <= 32'd0;      // Back to Sectors 0-71
                else                           sector_base <= 32'd0;      // Default case
                
                // Reset current sector to base sector
                current_sector <= sector_base;
                sectors_read <= 0;
                buffer_addr_write <= 0;  // Reset buffer address for new sector group
                main_state <= INIT;
            end else begin
                // Normal state machine operation
                case (main_state)
                    INIT: begin
                        main_state <= SD_WAIT_READY;
                        bytes_read <= 0;
                        readEnableReg <= 0;
                        reading <= 0;
                        byte_ready <= 0;
                        
                        // Use current sector position
                        current_sector <= sector_base + sectors_read;
                        
                        if (sectors_read >= 72) begin
                            //done <= 1;  // Signal all sectors are read
                            main_state <= DONE;
                        //end else begin
                            //done <= 0;
                        end
                    end
                    
                    SD_WAIT_READY: begin
                        // Wait for SD careadEnable to be ready
                        if (ready) begin
                            main_state <= READ_SD;
                        end
                    end
                    
                    READ_SD: begin
                        // Start reading if not already reading
                        if (ready && !reading && !readEnable) begin
                            readEnableReg <= 1;
                            reading <= 1;
                        end else if (readEnable) begin
                            readEnableReg <= 0;  // Clear read signal after one clock cycle
                        end
                        
                        // Process bytes from SD careadEnable
                        if (reading && byte_available) begin
                            // Handle 16-bit buffer writing (pair of bytes)
                            if (!byte_ready) begin
                                // Store first byte
                                byte_buffer <= sd_dout;
                                byte_ready <= 1;
                            end else begin
                                // Combine with second byte and write to buffer
                                buffer[buffer_addr_write] <= {byte_buffer, sd_dout};
                                buffer_addr_write <= buffer_addr_write + 1;
                                byte_ready <= 0;
                            end
                            
                            bytes_read <= bytes_read + 1;
                            
                            // Update debug LEDs with the last two bytes
//                            if (bytes_read[0])  // Every other byte
//                                led[15:8] <= sd_dout;
//                            else
//                                led[7:0] <= sd_dout;
                                
                            // Check if we've read a full sector (512 bytes)
                            if (bytes_read == 511) begin
                                reading <= 0;      // Stop reading
                                main_state <= WAIT_SECTOR;
                                sectors_read <= sectors_read + 1;  // Increment sector counter
                            end
                        end
                        
                        // Handle read completion
                        if (reading && ready && !byte_available && bytes_read > 0) begin
                            reading <= 0;
                            main_state <= WAIT_SECTOR;
                            sectors_read <= sectors_read + 1;  // Increment sector counter
                        end
                    end
                    
                    WAIT_SECTOR: begin
                        // Wait until SD controller is ready again
                        if (ready) begin
                            if (sectors_read < 72) begin
                                main_state <= INIT;  // Read next sector
                            end else begin
                                main_state <= CALCULATE_CHECKSUM;  // All sectors read, calculate checksum
                                checksum <= 0;       // Reset checksum
                                checksum_addr <= 0;  // Start from first buffer address
                                checksum_state <= 0; // Reset checksum calculation state
                                //done <= 1;           // Signal all sectors are read
                            end
                        end
                    end
                    
                    CALCULATE_CHECKSUM: begin
                        case (checksum_state)
                            0: begin
                                // Add the current buffer value to checksum
                                checksum <= (checksum + buffer[checksum_addr]) % 65521; // Modulo 65521 (largest prime under 16 bits)
                                checksum_state <= 1;
                            end
                            1: begin
                                // Move to next address or finish
                                if (checksum_addr < buffer_addr_write - 1) begin // Check against actual data stored
                                    checksum_addr <= checksum_addr + 1;
                                    checksum_state <= 0; // Go back to state 0 for next read
                                end else begin
                                    main_state <= DISPLAY_CHECKSUM;
                                end
                                checksum_state <= 0;
                            end
                        endcase
                    end
                    
                    DISPLAY_CHECKSUM: begin
                        // Display the checksum on LEDs
                        //led <= checksum[15:0];  // Show the 16 least significant bits
                        main_state <= DONE;     // Move to DONE state
                    end
                    
                    DONE: begin
                        // Wait for button press to change sector group
                        //done <= 1;  // Signal all sectors are read
                        //led <= current_frame;
                        //led <= buffer[frame_base_addr + ((47 * 64) + 63)];
                        // Keep displaying the checksum - LEDs are not updated here anymore
                    end
                    
                    default: main_state <= INIT;
                endcase
            end
        end
    end
endmodule