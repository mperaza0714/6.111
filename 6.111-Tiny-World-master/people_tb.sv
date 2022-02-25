`timescale 1ns / 1ps

module people_tb;
    //inputs
    logic clock;
    logic [10:0] hcount_in;
    logic [9:0] vcount_in;
    logic [6911:0] grid;
    //outputs
    logic [11:0] pixel_out;
    
    people peep(.hcount_in(hcount_in),.vcount_in(vcount_in),.grid(grid),.pixel_out(pixel_out));
    
    always #5 clock = !clock;
    
    always @(posedge clock) begin
        hcount_in <= hcount_in + 1;
        if (hcount_in == 11'd1024) begin
            hcount_in <= 0;
            vcount_in <= vcount_in + 1;
            if (vcount_in == 10'd896) begin
                vcount_in <= 0;
            end
        end 
    end
    
    initial begin
        clock = 0;
        hcount_in = 0;
        vcount_in = 0;
        grid = 0;
        #100;
        grid[6912'd20] = 1;
        grid[6912'd50] = 1;
        grid[6912'd75] = 1;
        grid[6912'd300] = 1;
        grid[6912'd2000] = 1;
        grid[6912'd5500] = 1;
    end
    
endmodule
