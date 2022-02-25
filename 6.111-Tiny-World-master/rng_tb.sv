`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2020 07:23:01 PM
// Design Name: 
// Module Name: rng_tb
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


module rng_tb;
    //inputs
    logic clock;
    logic rst;
    
    //outputs
    logic [31:0] res;
    
    rng uut(.clk_in(clock), .shifted_res(res), .rst_in(rst));
    
    always #5 clock = !clock;
    
    initial begin
        clock = 0;
        rst = 1;
        #100;
        rst = 0;
    end
endmodule