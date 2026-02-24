module wave_capture_tb ();

    reg clk, reset, new_sample_ready, wave_display_idle;
    reg [15:0] new_sample_in;
    wire [8:0] write_address;
    wire write_enable, read_index;
    wire [7:0] write_sample;
    
    reg expected_write_enable, expected_read_index;
    reg [8:0] expected_write_address;
    reg [7:0] expected_write_sample;
    
    reg errors;
    
    wire [18:0] out = {write_address, write_enable, 
                       read_index, write_sample};
                       
    wire [18:0] expected = {expected_write_address, expected_write_enable, 
                            expected_read_index, expected_write_sample};
    
    wave_capture dut(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample_ready),
        .new_sample_in(new_sample_in),
        .wave_display_idle(wave_display_idle),
        .write_enable(write_enable),
        .write_address(write_address),
        .write_sample(write_sample),
        .read_index(read_index)
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
        new_sample_ready = 0;
        wave_display_idle = 0;
        errors = 0;
        #10
        
        // 1. test ARMED functionality: sample still negative, not a zero crossing
        new_sample_ready = 1;
        new_sample_in = -16'd1000; // 1111 1100 0001 1000
        #10
        new_sample_ready = 0;
        #10
        new_sample_ready = 1;
        new_sample_in = -16'd500; // 1111 1110 0000 1100
        
        expected_write_address = 9'd256; // start at 256-511
        expected_write_enable = 0;
        expected_read_index = 0;
        expected_write_sample = new_sample_in[15:8] + 8'd128; // top 8 bits of sample
        #10
        new_sample_ready = 0;
        
        $display("1. test ARMED functionality: sample still negative, not a zero crossing");
        $display("write_address = %d, expected = %d", write_address, expected_write_address);
        $display("write_enable = %d, expected = %d", write_enable, expected_write_enable);
        $display("read_index = %d, expected = %d", read_index, expected_read_index);
        $display("write_sample = %d, expected = %d", write_sample, expected_write_sample);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end
        
        // 2. test ARMED functionality: zero crossing --> switch case to ACTIVE
        #10
        new_sample_ready = 1;
        new_sample_in = 16'd100; // 0000 0000 0110 0100
        
        expected_write_address = 9'd256; // start at 256-511
        expected_write_enable = 0;  // ACTIVE
        expected_read_index = 0;
        expected_write_sample = new_sample_in[15:8] + 8'd128; // top 8 bits of sample
        #10
        new_sample_ready = 0;
        
        $display("2. test ARMED functionality: zero crossing --> switch case to ACTIVE");
        $display("write_address = %d, expected = %d", write_address, expected_write_address);
        $display("write_enable = %d, expected = %d", write_enable, expected_write_enable);
        $display("read_index = %d, expected = %d", read_index, expected_read_index);
        $display("write_sample = %d, expected = %d", write_sample, expected_write_sample);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 2");
        end
        
        // 3. test ACTIVE functionality: normal processing
        #10
        new_sample_ready = 1;
        new_sample_in = 16'd1000; // 0000 0011 1110 1000
        
        expected_write_address = 9'd257;
        expected_write_enable = 1;  // ACTIVE
        expected_read_index = 0;
        expected_write_sample = new_sample_in[15:8] + 8'd128; // top 8 bits of sample
        #10
        new_sample_ready = 0;
        
        $display("3. test ACTIVE functionality");
        $display("write_address = %d, expected = %d", write_address, expected_write_address);
        $display("write_enable = %d, expected = %d", write_enable, expected_write_enable);
        $display("read_index = %d, expected = %d", read_index, expected_read_index);
        $display("write_sample = %d, expected = %d", write_sample, expected_write_sample);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end
        
        // 4. after 256 samples, state becomes WAIT
        repeat(255) begin
            #10
            new_sample_ready = 1;
            new_sample_in = new_sample_in + 16'd512;
        end
        
        expected_write_address = 9'd256;    
        expected_write_enable = 0;  // WAIT
        expected_read_index = 0;    // hasn't changed yet
        expected_write_sample = new_sample_in[15:8] + 8'd128; // top 8 bits of sample
        #10
        new_sample_ready = 0;
        
        $display("4. after 256 samples, state becomes WAIT");
        $display("write_address = %d, expected = %d", write_address, expected_write_address);
        $display("write_enable = %d, expected = %d", write_enable, expected_write_enable);
        $display("read_index = %d, expected = %d", read_index, expected_read_index);
        $display("write_sample = %d, expected = %d", write_sample, expected_write_sample);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 4");
        end
        
        // 5. wait until wave_display_idle, now the state becomes ARMED
        #10
        new_sample_ready = 1;
        new_sample_in = new_sample_in + 16'd512;
        wave_display_idle = 1;
        #10
        wave_display_idle = 0;
        
        expected_write_address = 9'd0;     
        expected_write_enable = 0;  // ARMED
        expected_read_index = 1;    // now changed
        expected_write_sample = new_sample_in[15:8] + 8'd128; // top 8 bits of sample
        #10
        new_sample_ready = 0;
        
        $display("5. wave_display_idle, now the state becomes ARMED");
        $display("write_address = %d, expected = %d", write_address, expected_write_address);
        $display("write_enable = %d, expected = %d", write_enable, expected_write_enable);
        $display("read_index = %d, expected = %d", read_index, expected_read_index);
        $display("write_sample = %d, expected = %d", write_sample, expected_write_sample);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 5");
        end
        
        
        if (errors == 1'b0) begin
            $display ("No errors!");
        end
        
        #50
        $finish;
    end
endmodule