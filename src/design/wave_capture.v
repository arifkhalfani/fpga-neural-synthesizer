module wave_capture (
    input clk,
    input reset,
    input new_sample_ready,
    input [15:0] new_sample_in,
    input wave_display_idle,

    output wire [8:0] write_address,
    output wire write_enable,
    output wire [7:0] write_sample,
    output wire read_index
);
// Implement me!

// define states
localparam ARMED = 2'b00;
localparam ACTIVE = 2'b01;
localparam WAIT = 2'b10;

// tracks current and next states
wire [1:0] state;
reg [1:0] next_state;
dffr #(2) state_dff(
    .clk(clk),
    .r(reset),
    .d(next_state),
    .q(state)
);

// tracks previous, current and next states
wire [15:0] sample, prev_sample;
dffre #(16) prev_sample_dff(
    .clk(clk),
    .r(reset),
    .en(new_sample_ready),
    .d(sample),
    .q(prev_sample)
);
dffre #(16) sample_dff(
    .clk(clk),
    .r(reset),
    .en(new_sample_ready),
    .d(new_sample_in),
    .q(sample)
);

// tracks current and next sample count
wire [7:0] count;
reg [7:0] next_count;
dffre #(8) count_dff(
    .clk(clk),
    .r(reset),
    .en(new_sample_ready),
    .d(next_count),
    .q(count)
);

// stores read_index value
reg next_read_index;
dffr read_index_dff(
    .clk(clk),
    .r(reset),
    .d(next_read_index),
    .q(read_index)
);

// zero crossing logic
wire zero_crossing = (prev_sample[15] == 1'b1) & (sample[15] == 1'b0);

always @(*) begin
    case (state)
        ACTIVE : begin
            next_state = (count == 8'd255) ? WAIT : ACTIVE;
            next_count = count + 1;
            next_read_index = read_index;       
        end
        
        WAIT : begin
            next_read_index = wave_display_idle ^ read_index;    // flip the bit
            next_state = wave_display_idle ? ARMED : WAIT;
            next_count = 0;
        end
        
        default : begin  // ARMED
            next_state = zero_crossing ? ACTIVE : ARMED;
            next_count = zero_crossing ? count + 1 : 0;
            next_read_index = read_index;
        end
    endcase
end

// change format from -128, 127 signed to 0, 255 unsigned
assign write_sample = {~sample[15], sample[14:8]};

assign write_address = {~read_index, count};
assign write_enable = (state == ACTIVE);

endmodule