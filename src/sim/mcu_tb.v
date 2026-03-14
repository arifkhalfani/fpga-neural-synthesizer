module mcu_tb();
    reg clk, reset; 
    reg play_button, next_button, mode_button, song_done;
    wire play, reset_player;
    wire [1:0] song, mode;
    
    reg expected_play;
    reg [1:0] expected_song, expected_mode;
    
    reg errors;
    
    wire [4:0] out = {play, song, mode};
                       
    wire [4:0] expected = {expected_play, expected_song, expected_mode};
    
    mcu dut(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .mode_button(mode_button),
        .play(play),
        .reset_player(reset_player),
        .song(song),
        .mode(mode),
        .song_done(song_done)
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
        play_button = 0;
        next_button = 0;
        mode_button = 0;
        song_done = 0;
        errors = 0;        

        // 1. Initial states: play = 0, song = 0, mode = 0 (forward)
        #10
        expected_play = 1'b0;
        expected_song = 2'b00;
        expected_mode = 2'b00;  // normal
        #10
        
        $display("1. Initial states: play = 0, song = 0, mode = 0 (forward)");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end
        
        // 2. Test play functionality: play button pulsed to play song
        #10
        play_button = 1;
        #10
        play_button = 0;    // pulsed
        #10
        expected_play = 1'b1;   // play
        expected_song = 2'b00;
        expected_mode = 2'b00;  // normal
        #10
        
        $display("2. Test play functionality: ");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 2");
        end
        
        // 3. Test next_button functionality: skips songs and pauses
        #10
        next_button = 1;
        #10                   
        next_button = 0;  
        #10
        next_button = 1;
        #10                   
        next_button = 0; 
        #10
        next_button = 1;
        #10                   
        next_button = 0; 
        #10
        next_button = 1;
        #10                   
        next_button = 0;    // next_button pressed 4 times, song will loop back to 00
        #10
        expected_play = 1'b0;   // pause
        expected_song = 2'b00;  // loop back to 00
        expected_mode = 2'b00;  // normal
        #10
        
        $display("3. Test play functionality: skips songs and pauses");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end
        
        // 4. Test song_done functionality: skips to next song and pauses when song is done
        #10
        play_button = 1;    // play first, then song completes
        #10
        play_button = 0;
        #10
        song_done = 1;
        #10
        song_done = 0;
        #10
        expected_play = 1'b0;
        expected_song = 2'b01;  // next song
        expected_mode = 2'b00;  // normal
        #10
        
        $display("4. Test song_done functionality: skips to next song and pauses when song is done");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 4");
        end 
        
        // 5. Test mode_button functionality: changes mode and pauses, doesn't change current song
        #10
        play_button = 1;    // play first, then mode_button will pause the song
        #10
        play_button = 0;
        #10
        mode_button = 1;
        #10                   
        mode_button = 0;  
        #10
        mode_button = 1;
        #10                   
        mode_button = 0; 
        #10
        mode_button = 1;
        #10                   
        mode_button = 0; 
        #10
        mode_button = 1;
        #10                   
        mode_button = 0;    // mode_button pressed 4 times, mode will loop back to 00
        #10
        expected_play = 1'b0;   // pause
        expected_song = 2'b01;  // doesn't change song
        expected_mode = 2'b00;  // loop back to 00 (normal)
        #10
        
        $display("5. Test mode_button functionality: changes mode and pauses, doesn't change current song");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 5");
        end   
        
        // 6. Test REWIND functionality: if in REWIND mode, songs skips to the previous one.
        #10
        mode_button = 1;
        #10                   
        mode_button = 0; 
        #10
        next_button = 1;
        #10                 // next_button is pressed, skips to previous song
        next_button = 0;
        #10 
        song_done = 1;
        #10                 // song is done, skips to previous song
        song_done = 0;
        #10
        expected_play = 1'b0;   // stays paused
        expected_song = 2'b11;  // 1 --> 0 --> 3
        expected_mode = 2'b01;  // rewind
        #10
        
        $display("6. Test REWIND functionality: if in REWIND mode, songs skips to the previous one.");
        $display("play = %d, expected = %d", play, expected_play);
        $display("song = %d, expected = %d", song, expected_song);
        $display("mode = %d, expected = %d", mode, expected_mode);
        
        if (expected !== out) begin
            errors = 1'b1;
            $display ("Error at test 6");
        end
              
    
        if (errors == 1'b0) begin
            $display ("No errors!");
        end
        
        #50
        $finish;
    end
    
endmodule