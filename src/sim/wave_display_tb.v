module wave_display_tb ();

    reg clk, reset;
    reg [10:0] x;
    reg [9:0]  y;
    reg valid;
    reg [7:0] read_value;
    reg read_index;

    wire valid_pixel;
    wire [8:0] read_address;
    wire [7:0] r,g,b;

    reg expected_valid_pixel;
    reg errors;

    wire out = valid_pixel;
    wire expected = expected_valid_pixel;

    wave_display dut(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_value(read_value),
        .read_index(read_index),
        .read_address(read_address),
        .valid_pixel(valid_pixel),
        .r(r), .g(g), .b(b)
    );

    // clock
    initial begin
        clk = 0;
        reset = 1;
        repeat(4) #5 clk = ~clk;
        reset = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        errors = 0;
        valid = 1;
        read_value = 100;
        read_index = 0;

        // x too small
        x = 11'd100;
        y = 10'd100;
        expected_valid_pixel = 0;
        #10;

        $display("Test1 small x  actual=%0d expected=%0d", valid_pixel, expected_valid_pixel);
        if(out !== expected) begin errors=1; $display("FAIL 1"); end

        // x too large, wrong quadrant
        x = 11'd900;
        y = 10'd100;
        expected_valid_pixel = 0;
        #10;

        $display("Test2 large x  actual=%0d expected=%0d", valid_pixel, expected_valid_pixel);
        if(out !== expected) begin errors=1; $display("FAIL 2"); end

        // invalid: y bottom half
        x = 11'd400;
        y = 10'd700;
        expected_valid_pixel = 0;
        #10;

        $display("Test3 bottom half y  actual=%0d expected=%0d", valid_pixel, expected_valid_pixel);
        if(out !== expected) begin errors=1; $display("FAIL 3"); end

        if(errors==0)
            $display("PASS");

        #20;
        $finish;
    end

endmodule