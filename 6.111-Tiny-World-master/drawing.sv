`timescale 1ns / 1ps

module drawing(
   input clk_in, //65MHz clock
   input rst_in,
   input hsync, vsync, blank,
   input [10:0] hcount,
   input [9:0] vcount,
   input [29:0] bram_data, //extracted from the people BRAM
   input flood,
   input game_step,
   input build,
   output logic [12:0] address, //BRAM address to look up in people BRAM
   output logic [3:0] vga_r,
   output logic [3:0] vga_b,
   output logic [3:0] vga_g,
   output logic vga_hs,
   output logic vga_vs
    );
    
   localparam ISLAND_WIDTH = 96; //in grid spaces
   localparam ISLAND_HEIGHT = 72; //in grid spaces
   localparam LEFT_EDGE = 128;
   localparam RIGHT_EDGE = 896;
   localparam TOP_EDGE = 96;
   localparam BOTTOM_EDGE = 672;
    
    logic [11:0] rgb;
    logic [10:0] grid_x;
    logic [9:0] grid_y;
    assign grid_x = (hcount-LEFT_EDGE) >> 3;
    assign grid_y = (vcount-TOP_EDGE) >> 3;
    //assign address = ISLAND_WIDTH*grid_y + grid_x;
    
    logic [11:0] pixel;  // game's pixel  // r=11:8, g=7:4, b=3:0
    logic [11:0] ppl_pixel;
    
    //PEOPLE AND FOOD
    people_food (.hcount_in(hcount),.vcount_in(vcount),.data(bram_data),.pixel_out(ppl_pixel));
    
    //BUILDING
    logic [11:0] bldg_pixel;
    building (.hcount_in(hcount), .vcount_in(vcount), .clk_in(clk_in), .rst_in(rst_in), .game_step(build), .flood(flood), .pixel_out(bldg_pixel));
    
    //WATER
    logic [11:0] water_pixel;
    water (.hcount_in(hcount), .vcount_in(vcount), .flood(flood), .pixel_out(water_pixel));
    
    assign pixel = water_pixel | ppl_pixel | bldg_pixel;
    
    logic b,hs,vs;
    always_ff @(posedge clk_in) begin
         hs <= hsync;
         vs <= vsync;
         b <= blank;
         address <= ((hcount >= LEFT_EDGE && hcount < RIGHT_EDGE) && 
            (vcount >= TOP_EDGE && vcount <BOTTOM_EDGE)) ? ISLAND_WIDTH*grid_y + grid_x : 0;
         rgb <= (pixel == 12'b0) ? 12'hFF0 : pixel;
     end
    
    // the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;
    
endmodule //drawing

//////////////////////////////////////////////////////////////////////
//
// People: generate red rectangles for people
// Food Zones: generate green rectangles for people
//
//////////////////////////////////////////////////////////////////////
module people_food
   #(parameter WIDTH = 8,            // default width: 8 pixels, 1 grid space
               HEIGHT = 8,           // default height: 8 pixels, 1 grid space
               PEOPLE_COLOR = 12'hF00, // default color: red
               FOOD_COLOR = 12'h0F0)  //defaul color: green
   (input [10:0] hcount_in,
    input [9:0] vcount_in,
    input [29:0] data,
    output logic [11:0] pixel_out);

   //ISLAND PARAMS
   localparam ISLAND_WIDTH = 96; //in grid spaces
   localparam ISLAND_HEIGHT = 72; //in grid spaces
   localparam LEFT_EDGE = 128;
   localparam RIGHT_EDGE = 896;
   localparam TOP_EDGE = 96;
   localparam BOTTOM_EDGE = 672;
   
   //FOOD ZONE PARAMS
   localparam ZONE_WIDTH = 128;
   localparam ZONE1_LEFT = 256; //start of left food zone
   localparam ZONE1_RIGHT = ZONE1_LEFT + ZONE_WIDTH; //end of left food zone
   localparam ZONE2_RIGHT = 768; //end of right food zone
   localparam ZONE2_LEFT = ZONE2_RIGHT - ZONE_WIDTH; //start of right food zone
   localparam ZONE_TOP = 192; //top of both food zones
   localparam ZONE_BOTTOM = 576; //bottom of both food zones
   
   always_comb begin
      if (data>30'b0 && (hcount_in >= LEFT_EDGE && hcount_in < RIGHT_EDGE) && 
         (vcount_in >= TOP_EDGE && vcount_in <BOTTOM_EDGE))begin // if people information is not empty draw a person
         pixel_out = PEOPLE_COLOR;
      end else if (((hcount_in >= ZONE1_LEFT && hcount_in < ZONE1_RIGHT) || 
                  (hcount_in >= ZONE2_LEFT && hcount_in < ZONE2_RIGHT)) && 
                  (vcount_in >= ZONE_TOP && vcount_in < ZONE_BOTTOM)) begin  // if in food zone
         pixel_out = FOOD_COLOR;
      end else begin
         pixel_out = 0;
      end
   end
endmodule


//////////////////////////////////////////////////////////////////////
//
// buildings: generate building on screen
//
//////////////////////////////////////////////////////////////////////
module building
   #(parameter WIDTH = 64,            // default width: 64 pixels, 8 grid spaces
               HEIGHT = 96,           // default height: 64 pixels, 8 grid spaces
               COLOR_1 = 12'hA52,
               COLOR_2 = 12'h652)  // default color: brown
   (input [10:0] hcount_in,
    input [9:0] vcount_in,
    input clk_in,
    input rst_in,
    input game_step,
    input flood,
    output logic [11:0] pixel_out);

   //building bounds
   localparam LEFT_EDGE = 128;
   localparam UPPER_TOP_EDGE = 0;
   localparam UPPER_BOTTOM_EDGE = 96;
   localparam LOWER_TOP_EDGE = 672;
   localparam LOWER_BOTTOM_EDGE = 768;
   
   logic [23:0] grid;
   logic [4:0] grid_x;
   logic [4:0] ind;
   logic [4:0] n;
   
   //FSM states
   localparam WAITING = 2'b00;
   localparam GRID = 2'b01;
   localparam BUILD = 2'b11;
   logic [1:0] build_state;
   logic [4:0] bldg_counter;
   logic build;
   
   always_ff @(posedge clk_in) begin
        if (rst_in) begin
            grid <= 24'b0;
            bldg_counter <= 5'b0;
        end else if (flood) begin //sets flooded buildings to zero
            grid[1:0] = 2'b0;
            grid[13:10] = 2'b0;
            grid[23:22] = 2'b0;
        end else begin
            if (game_step) begin
                if (bldg_counter < 5'd31) begin
                    bldg_counter <= bldg_counter + 1; //only increment bldg_counter every game cycle
                end else begin
                    if (~grid[n]) begin
                        grid[n] <= 1;
                        n <= 0;
                        bldg_counter <= 0;
                    end else begin
                        n <= n+1;
                    end
                end
            end
        end
   end
   
   always_comb begin
        grid_x = (hcount_in-LEFT_EDGE) >> 6;
        ind = (vcount_in < UPPER_BOTTOM_EDGE) ? grid_x : grid_x + 12;
        if ((ind <= 11 && grid[ind]) && (vcount_in >= UPPER_TOP_EDGE && vcount_in < UPPER_BOTTOM_EDGE) && //checks to see if it is within upper bounds
           (hcount_in >= (grid_x*WIDTH + LEFT_EDGE) && hcount_in < (grid_x*WIDTH + LEFT_EDGE + WIDTH))) begin        //checks for horizontal location
            pixel_out = (grid_x%2==0) ? COLOR_1 : COLOR_2;
        end else if ((ind <= 23 && grid[ind]) && (vcount_in >= LOWER_TOP_EDGE && vcount_in < LOWER_BOTTOM_EDGE) && //checks to see if it is within lower bounds
           (hcount_in >= (grid_x*WIDTH + LEFT_EDGE) && hcount_in < (grid_x*WIDTH +LEFT_EDGE + WIDTH))) begin                //checks for horizontal location
            pixel_out = (grid_x%2==0) ? COLOR_2 : COLOR_1;
        end else pixel_out = 0;
    end
    
endmodule

//////////////////////////////////////////////////////////////////////
//
// water: generate water on screen
//
//////////////////////////////////////////////////////////////////////
module water
    #(parameter WIDTH = 128,        //default width: 128 pixels
                HEIGHT = 768,       //default height: 128 pixels
                COLOR = 12'h00F)    //default color: blue
    (input [10:0] hcount_in,
     input [9:0] vcount_in,
     input flood,                   //push btnc to flood
     output logic [11:0] pixel_out);
     
     localparam WATER_RISES = 128;  //pixels
     localparam LEFT_WATER = 0;    //x starting pixel
     localparam RIGHT_WATER = 896;   //x starting pixel
     
     always_comb begin
        if (flood)begin
            if ((hcount_in >= LEFT_WATER && hcount_in < (LEFT_WATER+WIDTH+WATER_RISES)) ||
                (hcount_in >= (RIGHT_WATER-WATER_RISES) && hcount_in < (RIGHT_WATER+WIDTH)))begin
                pixel_out = COLOR;
            end else begin
                pixel_out = 0;
            end
        end else begin
            if ((hcount_in >= LEFT_WATER && hcount_in < (LEFT_WATER+WIDTH)) ||
                (hcount_in >= RIGHT_WATER && hcount_in < (RIGHT_WATER+WIDTH)))begin
                pixel_out = COLOR;
            end else begin
                pixel_out = 0;
            end
        end
     end
endmodule