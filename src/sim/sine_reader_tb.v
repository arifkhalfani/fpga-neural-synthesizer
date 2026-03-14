module sine_reader_tb();

    reg clk, reset, generate_next;
    reg [1:0] mode;
    reg [19:0] step_size;
    wire sample_ready;
    wire [15:0] sample;
    sine_reader reader(
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .step_size(step_size),
        .generate_next(generate_next),
        .sample_ready(sample_ready),
        .sample(sample)
    );
    
    reg [9:0] expected_addr;
    wire [15:0] expected_out;
    reg errors;
    sine_rom rom(
        .clk(clk),
        .addr(expected_addr),
        .dout(expected_out)
    );

    // Clock and reset
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        repeat (4) #5 clk = ~clk;
        reset = 1'b0;
        forever #5 clk = ~clk;
    end

    // Tests
    initial begin
        $display("step_size = 128.25");
        $display("1. quadrant 1, floating point addition rounded down");
        mode = `NORMAL;
        errors = 0;
        #10
        step_size = 20'b00100000000100000000; // 128.25
        generate_next = 1;
        expected_addr = 10'd256; // 256.50
        #10 // one cycle to initialize reader
        #10 // 0
        $display("take two steps, expected_addr = 256(.50)");
        #20 // 128, 256
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end
        $display();
        
        $display("2. quadrant 1, floating point addition results in an extra address shift");
        expected_addr = 10'd513; // 513.00
        $display("take two steps, expected_addr = 256.50 + 256.50 = 513(.00)");
        #20
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 2");
        end
        $display();
        
        $display("3. quadrant 2, sample is flipped horizontally");
        expected_addr = 10'd1021; // 1026.00 - 1024 = 2.00 --> 1023 - 2.00 = 1021
        $display("take four steps, expected_addr = 513.00 + 513.00 = 1026(.00) --> 2(.00)");
        $display("since this is quadrant 2, flip horizontally");
        $display("expected_addr = 1023 - 2.00 = 1021(.00)");
        #40
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end
        $display();
        
        $display("4. quadrant 3, sample is flipped vertically");
        expected_addr = 10'd4; // 1026.00 - 1021.00 - 1 = 4
        $display("take eight steps, expected_addr = 1026.00 - 1021.00 - 1 = 4(.00)");
        $display("since this is quadrant 3, flip vertically");
        #80
        $display ("sample = %d, expected = %d", $signed(sample), $signed(0 - expected_out));
        if (((16'b0 - expected_out) !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 4");
        end
        $display();
        
        $display("5. quadrant 4, sample is flipped horizontally and vertically");
        expected_addr = 10'd1017; // 4.00 + 1026.00 - 1024 = 6.00 --> 1023 - 6 = 1017 
        $display("take eight steps, expected_addr = 4.00 + 1026.00 = 1030(.00) --> 6(.00)");
        $display("since this is quadrant 4, flip horizontally and vertically");
        $display("expected_addr = 1023 - 6.00 = 1017(.00)");
        #80
        $display ("sample = %d, expected = %d", $signed(sample), $signed(0 - expected_out));
        if (((16'b0 - expected_out) !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 5");
        end
        $display();
        
        $display("6. back to quadrant 1");
        expected_addr = 10'd8; // 1026.00 - 1017 - 1 = 8.00
        $display("take eight steps, expected_addr = 1026.00 - 1017.00 - 1 = 8(.00)");
        #80
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 6");
        end
        $display();
        
        $display("7. off, shift 1 step_size but not played");
        generate_next = 0;
        expected_addr = 10'd136; // 8.00 + 128.25 = 136.25
        $display("take eight steps, but it's paused");
        $display("expected_addr = 8.00 + 128.25 = 136(.25)");
        #80
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 7");
        end
        $display();
        
        $display("8. test REWIND functionality: resumes from same point at sample");
        mode = `REWIND;
        generate_next = 1;
        expected_addr = 10'd8; // 136.25 - 128.25 = 8.00
        #10 
        $display("take one step in reverse");
        $display("expected_addr = 136.25 - 128.25 = 8(.00)");
        #10
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 8");
        end
        $display();
        
        $display("9. test REWIND functionality: continuous sine wave");
        generate_next = 1;
        expected_addr = 10'd1017; 
        $display("take eight steps in reverse");
        $display("expected_addr = 8.00 - 1026.00 = 3078.00 -> Quad 3, raw 6 -> 1017(.00)");
        #80
        $display ("sample = %d, expected = %d", $signed(sample), $signed(16'b0 - expected_out));
        if (((16'b0 - expected_out) !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 9");
        end
        $display();

$display("10. test FAST_FORWARD functionality: double speed step");
        mode = `FAST_FORWARD;
        generate_next = 1;
        expected_addr = 10'd889; 
        #10 
        $display("take one step in fast forward");
        $display("Due to pipeline, hardware adds to the hidden advanced state: 2949.75");
        $display("expected_addr = 2949.75 + 256.50 = 3206.25 -> Quad 4, raw 134 -> 889(.00)");
        #10
        $display ("sample = %d, expected = %d", $signed(sample), $signed(16'b0 - expected_out));
        if (((16'b0 - expected_out) !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 10");
        end
        $display();
        
        $display("11. test FAST_FORWARD functionality: continuous sine wave");
        generate_next = 1;
        expected_addr = 10'd885; 
        $display("take eight steps in fast forward");
        $display("expected_addr = 3206.25 + 2052.00 = 5258.25 (wrap to 1162.25) -> Quad 2, raw 138 -> 885(.00)");
        #80
        $display ("sample = %d, expected = %d", sample, expected_out);
        if ((expected_out !== sample) || (!sample_ready)) begin
            errors = 1'b1;
            $display ("Error at test 11");
        end
        $display();
        
        if (errors == 1'b0) begin
            $display ("No errors!");
        end
        
    end
    
endmodule