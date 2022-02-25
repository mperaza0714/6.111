`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module top_level(
   input clk_100mhz,
   input[15:0] sw,
   input btnc, btnu, btnd,
   output logic[3:0] vga_r,
   output logic[3:0] vga_b,
   output logic[3:0] vga_g,
   output logic vga_hs,
   output logic vga_vs
   );
    clk_wiz_0 clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz), .clk_out2(clock_100mhz), .reset(btnd));

    logic [10:0] hcount;    // pixel on current line
    logic [9:0] vcount;     // line number
    logic hsync, vsync;
    logic [11:0] pixel;

    xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank));
          
    logic clean_btnu, old_clean_btnu;
    debounce db1(.reset_in(btnd), .clock_in(clk_65mhz), .noisy_in(btnu), .clean_out(clean_btnu));
    always_ff @(posedge clk_65mhz) old_clean_btnu <= clean_btnu;
    
    logic clean_flood, old_clean_flood;
    debounce db2(.reset_in(btnd), .clock_in(clk_65mhz), .noisy_in(btnc), .clean_out(clean_flood));
    always_ff @(posedge clk_65mhz) old_clean_flood <= clean_flood;

    logic build, ppl_bram;
    //logic [2:0] ppl_bram_buff;
    logic [12:0] addrb;
    logic [29:0] data_out_draw1, data_out_draw2, data_to_draw;
    assign data_to_draw = (ppl_bram) ? data_out_draw1 : data_out_draw2; //might need to change this
    
    logic game_step;
    
    //always_ff @(posedge clk_65mhz) ppl_bram_buff <= {ppl_bram_buff[1:0], ppl_bram}; //to safely send ppl_bram across clock domains
    
    drawing display(.clk_in(clk_65mhz), .rst_in(btnd), .hsync(hsync),.vsync(vsync),.blank(blank),.hcount(hcount),
        .vcount(vcount), .vga_r(vga_r),.vga_b(vga_b),.vga_g(vga_g),.vga_hs(vga_hs),.vga_vs(vga_vs), 
        .flood(btnc), .bram_data(data_to_draw), .address(addrb), .game_step(game_step), .build(build));
        
    logic [9:0] food_switches;
    assign food_switches = sw[9:0];
    logic [2:0] rng_sel;
    assign rng_sel = sw[15:13];
    
    logic wea1, wea2;
    logic [12:0] addra_1, addra_2;
    logic [29:0] ppl_in_write, data_out1, data_out2;  
    movement_and_collision game_log(.rst_in(btnd), .clk_in(clk_65mhz), .food_sw(food_switches), .flood(clean_flood && ~old_clean_flood),
        .write_ppl_1(wea1), .write_ppl_2(wea2), .ppl_to_bram(ppl_in_write), .addr_ppl_1(addra_1), .rng_sel(rng_sel), .build(build),
        .addr_ppl_2(addra_2), .ppl_from_bram_1(data_out1), .ppl_from_bram_2(data_out2), .ppl_bram(ppl_bram), .game_step(game_step));
        
    people_BRAM people1(.clka(clk_65mhz), .ena(1), .wea(wea1), .addra(addra_1), .dina(ppl_in_write), .douta(data_out1), 
        .clkb(clk_65mhz), .enb(1), .web(0), .addrb(addrb), .dinb(19'b0), .doutb(data_out_draw1));
        
    people_BRAM people2(.clka(clk_65mhz), .ena(1), .wea(wea2), .addra(addra_2), .dina(ppl_in_write), .douta(data_out2),
        .clkb(clk_65mhz), .enb(1), .web(0), .addrb(addrb), .dinb(19'b0), .doutb(data_out_draw2));
        
    logic [27:0] counter;
    parameter CYCLES = 27'd10000000; 
    always_ff @(posedge clk_65mhz) begin
        if (btnd) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
            if (counter == CYCLES) begin
                counter <= 0;
                game_step <= 1;
            end else begin
                game_step <= 0;
            end
       end
   end

endmodule //top_level



//////////////////////////////////////////////////////////////////////////////////
// Update: 8/8/2019 GH 
// Create Date: 10/02/2015 02:05:19 AM
// Module Name: xvga
//
// xvga: Generate VGA display signals (1024 x 768 @ 60Hz)
//
//                              ---- HORIZONTAL -----     ------VERTICAL -----
//                              Active                    Active
//                    Freq      Video   FP  Sync   BP      Video   FP  Sync  BP
//   640x480, 60Hz    25.175    640     16    96   48       480    11   2    31
//   800x600, 60Hz    40.000    800     40   128   88       600     1   4    23
//   1024x768, 60Hz   65.000    1024    24   136  160       768     3   6    29
//   1280x1024, 60Hz  108.00    1280    48   112  248       768     1   3    38
//   1280x720p 60Hz   75.25     1280    72    80  216       720     3   5    30
//   1920x1080 60Hz   148.5     1920    88    44  148      1080     4   5    36
//
// change the clock frequency, front porches, sync's, and back porches to create 
// other screen resolutions
////////////////////////////////////////////////////////////////////////////////

module xvga(input vclock_in,
            output logic [10:0] hcount_out,    // pixel number on current line
            output logic [9:0] vcount_out,     // line number
            output logic vsync_out, hsync_out,
            output logic blank_out);

   parameter DISPLAY_WIDTH  = 1024;      // display width
   parameter DISPLAY_HEIGHT = 768;       // number of lines

   parameter  H_FP = 24;                 // horizontal front porch
   parameter  H_SYNC_PULSE = 136;        // horizontal sync
   parameter  H_BP = 160;                // horizontal back porch

   parameter  V_FP = 3;                  // vertical front porch
   parameter  V_SYNC_PULSE = 6;          // vertical sync 
   parameter  V_BP = 29;                 // vertical back porch

   // horizontal: 1344 pixels total
   // display 1024 pixels per line
   logic hblank,vblank;
   logic hsyncon,hsyncoff,hreset,hblankon;
   assign hblankon = (hcount_out == (DISPLAY_WIDTH -1));    
   assign hsyncon = (hcount_out == (DISPLAY_WIDTH + H_FP - 1));  //1047
   assign hsyncoff = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE - 1));  // 1183
   assign hreset = (hcount_out == (DISPLAY_WIDTH + H_FP + H_SYNC_PULSE + H_BP - 1));  //1343

   // vertical: 806 lines total
   // display 768 lines
   logic vsyncon,vsyncoff,vreset,vblankon;
   assign vblankon = hreset & (vcount_out == (DISPLAY_HEIGHT - 1));   // 767 
   assign vsyncon = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP - 1));  // 771
   assign vsyncoff = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE - 1));  // 777
   assign vreset = hreset & (vcount_out == (DISPLAY_HEIGHT + V_FP + V_SYNC_PULSE + V_BP - 1)); // 805

   // sync and blanking
   logic next_hblank,next_vblank;
   assign next_hblank = hreset ? 0 : hblankon ? 1 : hblank;
   assign next_vblank = vreset ? 0 : vblankon ? 1 : vblank;
   always_ff @(posedge vclock_in) begin
      hcount_out <= hreset ? 0 : hcount_out + 1;
      hblank <= next_hblank;
      hsync_out <= hsyncon ? 0 : hsyncoff ? 1 : hsync_out;  // active low

      vcount_out <= hreset ? (vreset ? 0 : vcount_out + 1) : vcount_out;
      vblank <= next_vblank;
      vsync_out <= vsyncon ? 0 : vsyncoff ? 1 : vsync_out;  // active low

      blank_out <= next_vblank | (next_hblank & ~hreset);
   end
endmodule //xvga