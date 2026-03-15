`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module note_player_tb();

    reg clk, reset, play_enable, generate_next_sample;
    reg [1:0] mode;
    reg [5:0] note_to_load;
    reg [5:0] duration_to_load;
    reg load_new_note;
    reg [2:0] harmonic_to_load; // Added to match your note_player definition
    wire done_with_note, new_sample_ready, beat;
    wire [15:0] sample_out;
    
    reg expected_done; // check whether note is done
    reg errors;

    note_player np(
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .harmonic_to_load(harmonic_to_load),
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
        mode = `NORMAL;
        play_enable = 0;
        generate_next_sample = 1;
        load_new_note = 0;
        note_to_load = 0;
        duration_to_load = 0;
        harmonic_to_load = 0;
        errors = 0;

        reset = 1;
        #20; 
        reset = 0;
        #10;

        // 1. NORMAL: load note 35 with duration 5
        // This note should take exactly 5 beats to finish
        mode = `NORMAL;
        note_to_load = 6'd35;
        duration_to_load = 6'd5;
        
        play_enable = 1;
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk); 
        load_new_note = 0;

        repeat (5) @(negedge beat);
        @(negedge clk);
        
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end

        // 2&3. NORMAL play/pause functionality
        note_to_load = 6'd55;
        duration_to_load = 6'd5;    // finish in 5 beats
        
        play_enable = 1;
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk);
        load_new_note = 0;
        
        // Play for 2 beats, then pause
        repeat (2) @(negedge beat);
        @(negedge clk);
        play_enable = 0; // pause
        
        // Wait 2 beats while paused
        repeat (2) @(negedge beat);
        @(negedge clk);
        
        // if truly paused, the note wouldn't end
        expected_done = 0;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 2");
        end
        
        @(negedge clk);
        play_enable = 1; // resume
        
        // Wait for the remaining 3 beats
        repeat (3) @(negedge beat);
        @(negedge clk);
        
        // note ends after the final beats play out
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end

        // 4. FAST_FORWARD: load note 35 with duration 5
        // FF counts down by 2 (5 -> 3 -> 1 -> done). Takes exactly 3 beats.
        mode = `FAST_FORWARD;
        note_to_load = 6'd35;
        duration_to_load = 6'd5;
        
        play_enable = 1;
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk); 
        load_new_note = 0;

        repeat (3) @(negedge beat);
        @(negedge clk);
        
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 4");
        end

        // 5&6. FAST_FORWARD play/pause functionality
        note_to_load = 6'd55;
        duration_to_load = 6'd5;    // finish in 3 beats
        
        play_enable = 1;
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk);
        load_new_note = 0;
        
        // Play for 1 beat, then pause
        repeat (1) @(negedge beat);
        @(negedge clk);
        play_enable = 0; // pause
        
        // Wait 2 beats while paused
        repeat (2) @(negedge beat);
        @(negedge clk);
        
        // if truly paused, the note wouldn't end
        expected_done = 0;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 5");
        end
        
        @(negedge clk);
        play_enable = 1; // resume
        
        // Wait for remaining 2 beats
        repeat (2) @(negedge beat);
        @(negedge clk);
        
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 6");
        end
        
        // 7. REWIND: load note 35 with duration 8
        // REWIND counts down by 1. Takes exactly 8 beats.
        mode = `REWIND;
        note_to_load = 6'd35;
        duration_to_load = 6'd8;
        
        play_enable = 1; 
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk); 
        load_new_note = 0;

        repeat (8) @(negedge beat);
        @(negedge clk); 
        
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 7");
        end

        // 8&9. REWIND play/pause functionality
        note_to_load = 6'd35;
        duration_to_load = 6'd8;    // finish in 8 beats
        
        play_enable = 1;
        @(negedge clk);
        load_new_note = 1;
        @(negedge clk);
        load_new_note = 0;
        
        // Play for 3 beats, then pause
        repeat (3) @(negedge beat);
        @(negedge clk);
        play_enable = 0; // pause
        
        // Wait 4 beats while paused
        repeat (4) @(negedge beat);
        @(negedge clk);
        
        // if truly paused, the note wouldn't end
        expected_done = 0;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 8");
        end
        
        @(negedge clk);
        play_enable = 1; // resume
        
        // Wait for remaining 5 beats
        repeat (5) @(negedge beat);
        @(negedge clk);
        
        // note ends after the final beats play out
        expected_done = 1;
        
        $display ("done_with_note = %d, expected = %d", done_with_note, expected_done);
        if (expected_done !== done_with_note) begin
            errors = 1'b1;
            $display ("Error at test 9");
        end

        if (errors == 1'b0) begin
            $display ("No errors!");
        end
        
        $finish;
    end

endmodule