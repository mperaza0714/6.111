`timescale 1ns / 1ps

module test_grid(
    input clk_in,
    input rst_in,
    input done,
    output logic [6911:0] old_ppl_grid
    );
    
    logic [4:0] count;
    logic [6911:0] new_ppl_grid;
    
    //fsm states for direction:
    localparam UP = 3'b000;
    localparam UP_RIGHT = 3'b001;
    localparam RIGHT = 3'b010;
    localparam DOWN_RIGHT = 3'b011;
    localparam DOWN = 3'b100;
    localparam DOWN_LEFT = 3'b101;
    localparam LEFT = 3'b110;
    localparam UP_LEFT = 3'b111;
    logic [2:0] direct; //used for case statements
    logic [12:0] ind; //used for indexing into grid
    logic [12:0] new_ind; //for new grid

    always_ff @(posedge clk_in) begin //take old grid and move it, check to see if we can move person, if so map to new grid
        old_ppl_grid[1234] <= 1'b1;
        old_ppl_grid[4321] <= 1'b1;
        old_ppl_grid[0] <= 1'b1;
            if (old_ppl_grid[ind]) begin
                case (direct)
                    UP : begin
                             if (ind>=0 && ind<96) begin //top edge
                               direct <= RIGHT;
                             end else begin
                                new_ind <= ind - 96;
                                if (new_ppl_grid[new_ind]) begin
                                    direct <= UP_RIGHT;
                                end else begin
                                    new_ppl_grid[new_ind] <= 1'b1;
                                    ind <= ind + 1;
                                    direct <= UP_RIGHT;
                                end
                             end
                         end
                    UP_RIGHT: begin
                                 if (ind>=0 & ind<96) begin
                                    direct <= RIGHT;
                                 end else if (ind%96==0) begin //right edge
                                    direct <= DOWN;
                                 end else begin
                                    new_ind <= ind - 95;
                                    if (new_ppl_grid[new_ind]) begin
                                        new_ppl_grid[new_ind] <= 1'b1;
                                        ind <= ind + 1;
                                        direct <= RIGHT;
                                    end
                                 end
                             end
                    RIGHT:   begin
                                 if (ind%96==95) begin
                                    direct <= DOWN;
                                 end else begin
                                    new_ind <= ind + 1;
                                    if (new_ppl_grid[new_ind]) begin
                                        direct <= DOWN_RIGHT;
                                    end else begin
                                        new_ppl_grid[new_ind] <= 1'b1;
                                        ind <= ind + 1;
                                        direct <= DOWN_RIGHT;
                                    end
                                 end
                             end
                    DOWN_RIGHT: begin
                                    if (ind%96==95) begin
                                        direct <= DOWN;
                                    end else if (ind>=6816 && ind<6912) begin //bottom edge
                                        direct <= LEFT;
                                    end else begin
                                        new_ind <= ind + 97;
                                        if (new_ppl_grid[new_ind]) begin
                                            direct <= DOWN;
                                        end else begin
                                            new_ppl_grid[new_ind] <= 1'b1;
                                            ind <= ind + 1;
                                            direct <= DOWN;
                                        end
                                    end
                                end
                    DOWN:       begin
                                    if (ind>=6816 && ind<6912) begin //bottom edge
                                        direct <= LEFT;
                                    end else begin
                                        new_ind <= ind + 96;
                                        if (new_ppl_grid[new_ind]) begin
                                            direct <= DOWN_LEFT;
                                        end else begin
                                            new_ppl_grid[new_ind] <= 1'b1;
                                            ind <= ind + 1;
                                            direct <= DOWN_LEFT;
                                        end
                                    end
                                end
                    DOWN_LEFT:  begin
                                    if (ind>=6816 && ind<6912) begin //bottom edge
                                        direct <= LEFT;
                                    end else if (ind%96==0) begin //left edge
                                        direct <= UP;
                                    end else begin
                                        new_ind <= ind + 95;
                                        if (new_ppl_grid[new_ind]) begin
                                            direct <= LEFT;
                                        end else begin
                                            new_ppl_grid[new_ind] <= 1'b1;
                                            ind <= ind + 1;
                                            direct <= LEFT;
                                        end
                                    end
                                end
                    LEFT:       begin
                                    if (ind%96==0) begin
                                        direct <= UP;
                                    end else begin
                                        new_ind <= ind - 1;
                                        if (new_ppl_grid[new_ind]) begin
                                            direct <= UP_LEFT;
                                        end else begin
                                            new_ppl_grid[new_ind] <= 1'b1;
                                            ind <= ind + 1;
                                            direct <= UP_LEFT;
                                        end
                                    end
                                end
                    UP_LEFT:    begin
                                    if (ind%96==0) begin
                                        direct <= UP;
                                    end else if (ind>=0 && ind<96) begin //top edge
                                        direct <= RIGHT;
                                    end else begin
                                        new_ind <= ind - 97;
                                        if (new_ppl_grid[new_ind]) begin
                                            direct <= UP;
                                        end else begin
                                            new_ppl_grid[new_ind] <= 1'b1;
                                            ind <= ind + 1;
                                            direct <= UP;
                                        end
                                    end
                                end
                    default : direct <= UP; 
                endcase
            end else begin
                ind <= ind + 1;
            end
            if (ind >= 13'd6911) begin
                old_ppl_grid <= new_ppl_grid;
                ind <= 13'd0;
            end
    end
endmodule
