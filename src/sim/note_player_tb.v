module note_player_tb();

    reg clk, reset, play_enable, generate_next_sample;
    reg [5:0] note_to_load;
    reg [5:0] duration_to_load;
    reg load_new_note;
    wire done_with_note, new_sample_ready, beat;
    wire [15:0] sample_out;
    
    reg expected_done; // check whether note is done
    reg errors;

    note_player np(
        .clk(clk),
        .reset(reset),

        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .load_new_note(load_new_note),
        .done_with_note(done_with_note),

        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out),
        .new_sample_ready(new_sample_ready)
    );

    beat_generator #(.WIDTH(17), .STOP(4)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .beat(beat)
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
        play_enable = 0;
        generate_next_sample = 1;
        load_new_note = 0;
        note_to_load = 0;
        duration_to_load = 0;
        errors = 0;

        reset = 1;
        #20; 
        reset = 0;
        #10;

        // 1. load note 35 with duration 5
        // at STOP=4, this note should take 20+4 cycles to finish)
        note_to_load = 6'd35;
        duration_to_load = 6'd5;
        load_new_note = 1;
        #10; 
        load_new_note = 0;
        play_enable = 1;

        #230; // 20+4 cycles (beat mismatch)
        
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end

        // 2. play/pause functionality
        note_to_load = 6'd55;
        duration_to_load = 6'd5;    // finish in 20 cycles
        load_new_note = 1;
        #10;
        load_new_note = 0;
        
        #100;
        play_enable = 0; // pause
        #150;
        
        // if truly paused, the note wouldn't end
        expected_done = 0;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 2");
        end
        
        
        play_enable = 1; // resume
        
        #140;
        
        // note ends at 20+4th cycle
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end

        if (errors == 1'b0) begin
            $display ("No errors!");
        end
        
    end

endmodule
