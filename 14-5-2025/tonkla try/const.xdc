## Clock signal (100 MHz)
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

## Reset button (BTN0)
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## SPI Interface for microSD card

#Sch name = XA1_P
set_property PACKAGE_PIN M2 [get_ports sclk]					
	set_property IOSTANDARD LVCMOS33 [get_ports sclk]
#Sch name = XA2_P
set_property PACKAGE_PIN L3 [get_ports mosi]					
	set_property IOSTANDARD LVCMOS33 [get_ports mosi]
#Sch name = XA3_P
set_property PACKAGE_PIN J3 [get_ports miso]					
	set_property IOSTANDARD LVCMOS33 [get_ports miso]
#Sch name = XA4_P
set_property PACKAGE_PIN N2 [get_ports cs]					
	set_property IOSTANDARD LVCMOS33 [get_ports cs]

## Seven-Segment Display (Common Anode)

# seg[0] to seg[6] (a to g segments)
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg0[0]}]
set_property PACKAGE_PIN W7 [get_ports {seg0[7]}]
set_property PACKAGE_PIN W6 [get_ports {seg0[6]}]
set_property PACKAGE_PIN U8 [get_ports {seg0[5]}]
set_property PACKAGE_PIN V8 [get_ports {seg0[4]}]
set_property PACKAGE_PIN U5 [get_ports {seg0[3]}]
set_property PACKAGE_PIN V5 [get_ports {seg0[2]}]
set_property PACKAGE_PIN U7 [get_ports {seg0[1]}]
set_property PACKAGE_PIN V7 [get_ports {seg0[0]}]

# Second digit (seg1, upper nibble)
# Uses the same physical lines as seg0 (same segments) — display multiplexing assumed
# You can map seg1 to same pins if you're multiplexing

## Anodes for display digits 0 to 3 (right to left)  
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
set_property PACKAGE_PIN U2 [get_ports {an[0]}]

## Optional: buttons for rd/wr if desired
# BTN1 for rd
#set_property PACKAGE_PIN P4 [get_ports rd]
#set_property IOSTANDARD LVCMOS33 [get_ports rd]

# BTN2 for wr
#set_property PACKAGE_PIN P5 [get_ports wr]
#set_property IOSTANDARD LVCMOS33 [get_ports wr]