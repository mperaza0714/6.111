`timescale 1ns / 1ps


module movement_and_collision_tb;
    //inputs
    logic clock;
    logic [6:0] food_sw; //food count determined by user input
    logic flood;  
    logic rst_in;
    logic done;
    //outputs
    logic [6911:0] new_ppl_grid;
    
    movement_and_collision game_log(.rst_in(rst_in), .clk_in(clock), .food_sw(food_sw), 
        .flood(flood),.done(done),.new_ppl_grid(new_grid_ppl));
    
    always #5 clock = !clock;
    
    initial begin
        clock = 0;
        rst_in = 0;
        flood = 0;
        food_sw = 7'b110010;
        done = 0;
        #100;
        rst_in = 1;
        #20;
        rst_in = 0;
        done = 1;
        #10;
        done = 0;
        #40;
        done = 1;
        #40;
        done = 0;
        #40;
        done = 1;
        #40;
        done = 0;
    end
    
endmodule
