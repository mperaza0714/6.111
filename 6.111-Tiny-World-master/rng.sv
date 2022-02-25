`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2020 04:57:37 PM
// Design Name: 
// Module Name: rng
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module rng(input rst_in, input clk_in, input [2:0] num_sel, output logic [31:0] shifted_res);
    logic [31:0] LFSR_32; //hold random values
    logic [30:0] LFSR_31; //hold random values
    logic [31:0] lfsr_res;
    
    //initatial seed value for LFSR_32 is based on switch inputs
    lfsr32_sel lfsr1(.clk_in(clk_in), .num_sel(num_sel), .lfsr_shift(lfsr_res));
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            LFSR_32 <= lfsr_res;
            LFSR_31 <= 31'h23456789; //seed value
        end else begin
            //Create a 31-bit LFSR and 32-bit LFSR, then xor those with one another for increased randomness
            LFSR_32 <= {LFSR_32[30:0], LFSR_32[0] ^ LFSR_32[15]};
            LFSR_31 <= {LFSR_31[29:0], LFSR_31[0] ^ LFSR_31[8]};
            shifted_res <= (LFSR_32 ^ LFSR_31) & 16'hFFFF; 
        end
    end
endmodule

module lfsr32_sel(input clk_in, input [2:0] num_sel, output logic [31:0] lfsr_shift);
    always_comb begin 
        //seed values used for LFSR_32 
        case (num_sel)
            3'b000: lfsr_shift <= 32'hB4BCD35C;
            3'b001: lfsr_shift <= 32'h7A5BC2E3;
            3'b010: lfsr_shift <= 32'hB4BCD35C;
            3'b011: lfsr_shift <= 32'h29D1E9EB;
            3'b100: lfsr_shift <= 32'd798053920;
            3'b101: lfsr_shift <= 32'd478902383;
            3'b110: lfsr_shift <= 32'd890275340;
            3'b111: lfsr_shift <= 32'd374982713;
            default: lfsr_shift <= 32'hB4BCD35C;
        endcase
    end

endmodule