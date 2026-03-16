module bias_hidden_rom (
    input  wire [4:0] addr,
    output reg  [15:0] data
);
    always @(*) begin
        case (addr)
            5'd0: data = 16'h0196;
            5'd1: data = 16'hfe45;
            5'd2: data = 16'h00e2;
            5'd3: data = 16'hff99;
            5'd4: data = 16'h0156;
            5'd5: data = 16'h00b9;
            5'd6: data = 16'hff3d;
            5'd7: data = 16'hffc8;
            5'd8: data = 16'hffdf;
            5'd9: data = 16'h01ec;
            5'd10: data = 16'hff07;
            5'd11: data = 16'h01a5;
            5'd12: data = 16'hff83;
            5'd13: data = 16'h003c;
            5'd14: data = 16'h0143;
            5'd15: data = 16'h0043;
            5'd16: data = 16'h0065;
            5'd17: data = 16'h008b;
            5'd18: data = 16'h0034;
            5'd19: data = 16'h0073;
            5'd20: data = 16'hff90;
            5'd21: data = 16'hff55;
            5'd22: data = 16'h0146;
            5'd23: data = 16'h0176;
            5'd24: data = 16'h008d;
            5'd25: data = 16'h0070;
            5'd26: data = 16'h02f3;
            5'd27: data = 16'hfe87;
            5'd28: data = 16'h007e;
            5'd29: data = 16'hff92;
            5'd30: data = 16'h007a;
            5'd31: data = 16'hffb2;
            default: data = 16'h0000;
        endcase
    end
endmodule
