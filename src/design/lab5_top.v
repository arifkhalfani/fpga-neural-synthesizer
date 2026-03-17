`define CODE_WHITE 3'd0
`define CODE_BLUE  3'd1
`define CODE_RED   3'd2
`define CODE_GREEN 3'd3
`define CODE_PINK  3'd4

module lab5_top(
    /*
    'define H_SYNC_PULSE 112
    'define H_BACK_PORCH 248
    'define H_FRONT_PORCH 48
    'define V_SYNC_PULSE 3
    'define V_BACK_PORCH 38
    'define V_FRONT_PORCH 1
    */     

    // System Clock (125MHz)
    input sysclk,
        
    // ADAU_1761 interface
    output  AC_ADR0,            // I2C Address pin (DO NOT CHANGE)
    output  AC_ADR1,            // I2C Address pin (DO NOT CHANGE)
    
    output  AC_DOUT,           // I2S Signals
    input   AC_DIN,            // I2S Signals
    input   AC_BCLK,           // I2S Byte Clock
    input   AC_WCLK,           // I2S Channel Clock
    
    output  AC_MCLK,            // Master clock (48MHz)
    output  AC_SCK,             // I2C SCK
    inout   AC_SDA,             // I2C SDA 
    
    // LEDs
    output wire [3:0] led,
    output wire [2:0] leds_rgb_0,
    output wire [2:0] leds_rgb_1,

    input [3:0] btn,

    /* //VGA OUTPUT 
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS*/
  
    // HDMI output
    output TMDS_Clk_p,
    output TMDS_Clk_n,
    output [2:0] TMDS_Data_p,
    output [2:0] TMDS_Data_n
    
    // TODO: output LED0 onto something
  
);  

    wire reset, play_button, next_button, mode_button;
    assign {reset, play_button, next_button, mode_button} = btn;

    // Clock converter
    wire clk_100, display_clk, serial_clk;
    wire LED0;      // TODO: assign this to a real LED
 
    clk_wiz_0 U2 (
        .clk_out1(clk_100),     // 100 MHz
        .clk_out2(display_clk), // 30 MHz
        .clk_out3(serial_clk),  // 150 Mhz
        .reset(reset),
        .locked(LED0),
        .clk_in1(sysclk)
    );


  
    // button_press_unit's WIDTH parameter is exposed here so that you can
    // reduce it in simulation.  Setting it to 1 effectively disables it.
    parameter BPU_WIDTH = 20;
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    // If you reduce this to 100 your simulation will be 10x faster.
    parameter BEAT_COUNT = 1000;

   
    // These signals are for determining which color to display
    wire [11:0] x;  // [0..1279]
    wire [11:0] y;  // [0..1023] 
    
    // Color to display at the given x,y
    wire [31:0] pix_data;
    wire [3:0]  r, g, b;
    wire [7:0] r_1, g_1, b_1;
      
  wire [3:0] VGA_R;
  wire [3:0] VGA_G;
  wire [3:0] VGA_B;
  wire VGA_HS;
  wire VGA_VS;
 
//   
//  ****************************************************************************
//      Button processor units
//  ****************************************************************************
//  
    wire play;
    button_press_unit #(.WIDTH(BPU_WIDTH)) play_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(play_button),
        .out(play)
    );

    wire next;
    button_press_unit #(.WIDTH(BPU_WIDTH)) next_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(next_button),
        .out(next)
    );
    
    wire mode;
    button_press_unit #(.WIDTH(BPU_WIDTH)) mode_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(mode_button),
        .out(mode)
    );
        
//   
//  ****************************************************************************
//      The music player
//  ****************************************************************************
//         
    wire new_frame, new_frame_1;
    wire [15:0] codec_sample, flopped_sample;
    wire new_sample, flopped_new_sample;

    wire [15:0] sample_out_1, sample_out_2, sample_out_3, sample_out_4;
    wire new_sample_ready_1, new_sample_ready_2, new_sample_ready_3, new_sample_ready_4;
    
    wire [15:0] flopped_sample_1, flopped_sample_2, flopped_sample_3, flopped_sample_4;
    wire flopped_new_sample_1, flopped_new_sample_2, flopped_new_sample_3, flopped_new_sample_4;

    // ---> NEW: Declare the is_playing wires from the music player
    wire is_playing_0, is_playing_1, is_playing_2, is_playing_3, is_playing_4;

    music_player #(.BEAT_COUNT(BEAT_COUNT)) music_player(
        .clk(clk_100),
        .reset(reset),
        .play_button(play),
        .next_button(next),
        .mode_button(mode),
        .new_frame(new_frame_1), 
        .sample_out(codec_sample),
        .new_sample_generated(new_sample),
        .sample_out_1(sample_out_1),
        .new_sample_ready_1(new_sample_ready_1),
        .sample_out_2(sample_out_2),
        .new_sample_ready_2(new_sample_ready_2),
        .sample_out_3(sample_out_3),
        .new_sample_ready_3(new_sample_ready_3),
        .sample_out_4(sample_out_4),
        .new_sample_ready_4(new_sample_ready_4),
        
        // ---> NEW: Hook up the playing flags
        .is_playing_0(is_playing_0),
        .is_playing_1(is_playing_1),
        .is_playing_2(is_playing_2),
        .is_playing_3(is_playing_3),
        .is_playing_4(is_playing_4)
    );
    
    dffr abc_dff(
        .clk(clk_100),
        .r(reset),
        .d(new_frame),
        .q(new_frame_1)
    );
    
    dff #(.WIDTH(17)) sample_reg (
        .clk(clk_100),
        .d({new_sample, codec_sample}),
        .q({flopped_new_sample, flopped_sample})
    );

    dff #(.WIDTH(17)) sample_reg_1 (
        .clk(clk_100),
        .d({new_sample_ready_1, sample_out_1}),
        .q({flopped_new_sample_1, flopped_sample_1})
    );
    dff #(.WIDTH(17)) sample_reg_2 (
        .clk(clk_100),
        .d({new_sample_ready_2, sample_out_2}),
        .q({flopped_new_sample_2, flopped_sample_2})
    );
    dff #(.WIDTH(17)) sample_reg_3 (
        .clk(clk_100),
        .d({new_sample_ready_3, sample_out_3}),
        .q({flopped_new_sample_3, flopped_sample_3})
    );
    dff #(.WIDTH(17)) sample_reg_4 (
        .clk(clk_100),
        .d({new_sample_ready_4, sample_out_4}),
        .q({flopped_new_sample_4, flopped_sample_4})
    );

//   
//  ****************************************************************************
//      Codec interface
//  ****************************************************************************
//  
    wire [23:0] hphone_r = 0;
    wire [23:0] line_in_l = 0;  
    wire [23:0] line_in_r =  0; 
    
    // Output the sample onto the LEDs for the fun of it.
    assign leds_rgb_0 = codec_sample[15:13];
    assign leds_rgb_1 = codec_sample[11:9];
    assign led = codec_sample[15:12];

    adau1761_codec adau1761_codec(
        .clk_100(clk_100),
        .reset(reset),
        .AC_ADR0(AC_ADR0),
        .AC_ADR1(AC_ADR1),
        .I2S_MISO(AC_DOUT),
        .I2S_MOSI(AC_DIN),
        .I2S_bclk(AC_BCLK),
        .I2S_LR(AC_WCLK),
        .AC_MCLK(AC_MCLK),
        .AC_SCK(AC_SCK),
        .AC_SDA(AC_SDA),
        .hphone_l({codec_sample, 8'h00}),
        .hphone_r(hphone_r),
        .line_in_l(line_in_l),
        .line_in_r(line_in_r),
        .new_sample(new_frame)
    );  
    
//   
//  ****************************************************************************
//      Display management
//  ****************************************************************************
//  
 
    //==========================================================================
    // Display management -> do not touch!
    //==========================================================================
    
//  wire valid, de;
//    vga_generator vga_g (
//        .clk(clk_100),
//        .r(r), 
//        .g(g),
//        .b(b),
//        .color({r_1, g_1, b_1}),
//        .xpos(x),
//        .ypos(y),
//        .valid(valid),
//        .de(de),
//        .vsync(VGA_VS),
//        .hsync(VGA_HS)
//    );

    wire vde, hsync, vsync, blank;
    vga_controller_800x480_60 vga_control (
        .pixel_clk(display_clk),
        .rst(reset),
        .HS(hsync),
        .VS(vsync),
        .VDE(vde),
        .hcount(x),
        .vcount(y),
        .blank(blank)
    );
    
    wire [7:0] r_0, g_0, b_0; 
    wire [7:0] rw_1, gw_1, bw_1; 
    wire [7:0] rw_2, gw_2, bw_2; 
    wire [7:0] rw_3, gw_3, bw_3; 
    wire [7:0] rw_4, gw_4, bw_4; 
    
    wave_display_top wd_top (
        .clk (clk_100),
        .reset (reset),
        .new_sample (flopped_new_sample),
        .sample (flopped_sample),
        .x(x[10:0]),
        .y(y[9:0]),
        //.valid(valid),
        .valid(vde),
        .vsync(vsync),
        .color_code(`CODE_WHITE),
        .r(r_0),
        .g(g_0),
        .b(b_0)
    );
    
    wave_display_top wd_top_1 (
        .clk (clk_100),
        .reset (reset),
        .new_sample (flopped_new_sample_1),
        .sample (flopped_sample_1),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .color_code(`CODE_BLUE),
        .r(rw_1),
        .g(gw_1),
        .b(bw_1)
    );

    wave_display_top wd_top_2 (
        .clk (clk_100),
        .reset (reset),
        .new_sample (flopped_new_sample_2),
        .sample (flopped_sample_2),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .color_code(`CODE_RED),
        .r(rw_2),
        .g(gw_2),
        .b(bw_2)
    );

    wave_display_top wd_top_3 (
        .clk (clk_100),
        .reset (reset),
        .new_sample (flopped_new_sample_3),
        .sample (flopped_sample_3),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .color_code(`CODE_GREEN),
        .r(rw_3),
        .g(gw_3),
        .b(bw_3)
    );

    wave_display_top wd_top_4 (
        .clk (clk_100),
        .reset (reset),
        .new_sample (flopped_new_sample_4),
        .sample (flopped_sample_4),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .color_code(`CODE_PINK),
        .r(rw_4),
        .g(gw_4),
        .b(bw_4)
    );

    // ---> NEW: Include is_playing in the wave active checks! 
    // Determine which waves are actively drawing a pixel at this x,y coordinate AND are currently playing
    wire wave0_active = ((r_0 | g_0 | b_0) != 0) && is_playing_0; // The overall mix (White)
    wire wave1_active = ((rw_1 | gw_1 | bw_1) != 0) && is_playing_1;
    wire wave2_active = ((rw_2 | gw_2 | bw_2) != 0) && is_playing_2;
    wire wave3_active = ((rw_3 | gw_3 | bw_3) != 0) && is_playing_3;
    wire wave4_active = ((rw_4 | gw_4 | bw_4) != 0) && is_playing_4;

    // Priority mux: draw wave 0 on top, then wave 1, and so on
    // Because waveX_active goes to 0 when idle, the mux automatically hides silent waves!
    assign r_1 = wave0_active ? r_0 :
                 wave1_active ? rw_1 :
                 wave2_active ? rw_2 :
                 wave3_active ? rw_3 :
                 wave4_active ? rw_4 : 8'd0;

    assign g_1 = wave0_active ? g_0 :
                 wave1_active ? gw_1 :
                 wave2_active ? gw_2 :
                 wave3_active ? gw_3 :
                 wave4_active ? gw_4 : 8'd0;

    assign b_1 = wave0_active ? b_0 :
                 wave1_active ? bw_1 :
                 wave2_active ? bw_2 :
                 wave3_active ? bw_3 :
                 wave4_active ? bw_4 : 8'd0;
    
    assign r = r_1[7:4];
    assign g = g_1[7:4];
    assign b = b_1[7:4];
    assign pix_data = {
                        8'b0, 
                        r[3], r[3], r[2], r[2], r[1], r[1], r[0], r[0],
                        g[3], g[3], g[2], g[2], g[1], g[1], g[0], g[0],
                        b[3], b[3], b[2], b[2], b[1], b[1], b[0], b[0]
                       }; 
                  
    hdmi_tx_0 U3 (
        .pix_clk(display_clk),
        .pix_clkx5(serial_clk),
        .pix_clk_locked(LED0),
        .rst(reset),
        .pix_data(pix_data),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        .TMDS_CLK_P(TMDS_Clk_p),
        .TMDS_CLK_N(TMDS_Clk_n),
        .TMDS_DATA_P(TMDS_Data_p),
        .TMDS_DATA_N(TMDS_Data_n)
    );
   
   
endmodule