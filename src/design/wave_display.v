module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
    input valid,
    input [7:0] read_value,
    input read_index,
    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    wire valid_x;
    wire valid_y;

    // Validate coordinate, x valid when the 3 MSB is 001 or 010, x > 11'b00100000010 handles
    // the edge case at the beginning
    assign valid_x = ((x[9:8] == 2'b01) || (x[9:8] == 2'b10)) & (x > 11'b00100000010);
    assign valid_y = ~y[9];

    // Read address following the rules as provided in spec
    assign read_address = {read_index, x[9], x[7:1]};

    // Keep track of prev_address in order to check y coordinate validity later
    wire [8:0] prev_address;
    dffr #(9) address_ff(
        .clk(clk),
        .r(reset),
        .d(read_address),
        .q(prev_address)
    );

    // Only activate the value flip flop if the address has changed, we use
    // this signal address_changed to achieve that
    wire address_changed = (prev_address != read_address);
    wire [7:0] prev_value;
    wire [7:0] read_value_adjusted = (read_value >> 1) + 8'd32;

    dffre #(8) value_dff(
        .clk(clk),
        .r(reset),
        .en(address_changed),
        .d(read_value_adjusted),
        .q(prev_value)
    );

    reg display;
    wire [7:0] y_cap = y[8:1];

    always @(*) begin
        // Handles both cases when gradient of the curve is positive and negative, in any case we want y_cap
        // to be in between prev_value and read_value_adjusted (both can be the upper and lower bound)
        if ((y_cap >= prev_value && y_cap <= read_value_adjusted) || (y_cap >= read_value_adjusted && y_cap <= prev_value))
            display = 1;
        else
            display = 0;
    end

    // Only valid if coordinates are valid, the input from VGA is valid, and we should display
    // a pixel at the given (x, y) coordinate
    assign valid_pixel = valid & valid_x & valid_y & display;
    assign {r, g, b} = valid_pixel ? 24'hFFFFFF : 24'h000000;

endmodule