module mcu_tb();
    reg clk, reset; 
    reg play_button, next_button, song_done;
    wire play, reset_player;
    wire [1:0] song;
    
    mcu dut(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play),
        .reset_player(reset_player),
        .song(song),
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
    song_done = 0;
    #31
    $display("Round 1: Just starting");
    $display("Current song number is %b. Intended song number is 00", song);
    $display("Current play state is %b. Play state should be 0", play);
    
    play_button = 1;
    #10;
    play_button = 0;
    #700
    
    song_done = 1;
    #10;
    song_done = 0;
    #10;
    $display("Round 2: Pushed play button and waited 120 cycles");
    $display("Current song number is %b. Intended song number is 01", song);
    $display("Current play state is %b. Play state should be 0", play); 

    play_button = 1;
    #10;
    play_button = 0;
    #10;
    $display("Turned on play");
    $display("Current play state is %b. Play state should be 1", play);
    #20
    next_button = 1;
    #10
    next_button = 0;
    #10
    $display("Hit next button");
    $display("Current song number is %b. Intended song number is 10", song);
    $display("Current play state is %b. Play state should be 0", play);
    
    play_button = 1;
    #10;
    play_button = 0;
    #10
    $display("Hit play");
    $display("Current play state is %b. Play state should be 1", play);
    
    next_button = 1;
    #10
    next_button = 0;
    #30
    next_button = 1;
    #10
    next_button = 0;
    #10
    $display("Skipped forward twice");
    $display("Current song number is %b. Intended song number is 00", song);
    $display("Current play state is %b. Play state should be 0", play);
    
    next_button = 1;
    #10
    next_button = 0;
    #10
    $display("Skipped foward again");
    $display("Current song number is %b. Intended song number is 01", song);
    $display("Current play state is %b. Play state should be 0", play);
    
    play_button = 1;
    #10;
    play_button = 0;
    #10
    $display("Hit play");
    $display("Current play state is %b. Play state should be 1", play);
    
    reset = 1;
    #10;
    reset = 0;
    #10
    $display("reset");
    $display("Current song number is %b. Intended song number is 00", song);
    $display("Current play state is %b. Play state should be 0", play);
    
    end
    
endmodule