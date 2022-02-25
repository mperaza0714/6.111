`timescale 1ns / 1ps

module movement_and_collision(
    input clk_in, //100mhz clock
    input [2:0] rng_sel, //switches to determine rng initial seed
    input [6:0] food_sw, //food count determined by user input
    input flood,  
    input rst_in,
    input game_step,
    output logic write_ppl_1, //wea signal for people BRAM
    output logic write_ppl_2,
    output logic [12:0] addr_ppl_1, //address of the people we insert into people BRAM, will be used for lookups (13 bits)
    output logic [12:0] addr_ppl_2,
    output logic [29:0] ppl_to_bram, //data sent to people BRAM {food_indicator, food_storage (7 bits), food_count (7bits), age (7 bits), counter (5 bits), dir (3bits)} (30 bits)
    input [29:0] ppl_from_bram_1,
    input [29:0] ppl_from_bram_2,
    output logic ppl_bram, //tells us which BRAM we are reading from/writing to
    output logic build //signals when to generate building
    );
    localparam MAX = 13'd8190;
    localparam GRID_WIDTH = 13'd96;
    localparam GRID_HEIGHT = 13'd72;
    localparam PPL_BRAM_SIZE = GRID_WIDTH*GRID_HEIGHT - 1;
    
    //game parameters
    localparam MAX_AGE = 7'd127;
    localparam init_age = 7'b1;
    logic [26:0] initial_ppl_state;
    logic [29:0] initial_food_state;
    logic [12:0] ind; //used for indexing into grid
    
    logic [12:0] food_addr;
    logic [4:0] bldg_counter;
    
    //storing parameters
    logic food_indicator;
    logic [6:0] food_storage;
    logic [6:0] food_count;
    logic [6:0] age;
    //logic [4:0] counter; //will implement later
    logic [1:0] dir;
    
    //for collisions and randomly spawning ppl  
    logic [2:0] old_num_colls;
    logic [2:0] num_collisions;
    logic [1:0] time_since_last;
    logic [12:0] stored_addr;
    logic init;
    
    //food zone info
    logic [7:0] food_1;
    logic [7:0] food_2;
    
    assign initial_food_state = {1'b1, 7'd127, 22'b0}; //food starts off with max food
    assign initial_ppl_state = {8'b0, food_sw, init_age, 5'b0}; //initialization of ppl is dependent on food sw values, leave dir empty for initialization
    
    //game states
    logic [4:0] game_state;
    logic [5:0] init_counter; //used to initialize ppl & food into bram
    logic [12:0] lookup_addr [7:0]; //eight surrounding locations
    logic [29:0] surroundings [7:0];//data from surrounding cells
    
    //game states
    localparam INITIALIZE = 5'b0000;
    localparam LOOKUP_CURR = 5'b0001;
    localparam LOOKUP_UPLEFT = 5'b0010;
    localparam LOOKUP_UP = 5'b0011;
    localparam LOOKUP_UPRIGHT = 5'b0100;
    localparam LOOKUP_LEFT = 5'b0101;
    localparam LOOKUP_RIGHT = 5'b0110;
    localparam LOOKUP_DOWNLEFT = 5'b0111;
    localparam LOOKUP_DOWN = 5'b1000;
    localparam LOOKUP_DOWNRIGHT = 5'b1001;
    localparam STORE_DOWN = 5'b1010;
    localparam STORE_DOWNRIGHT = 5'b1011;
    localparam MOVE_PPL = 5'b1100;
    localparam SPAWN_PPL = 5'b1101;
    localparam STORE_FOOD = 5'b1110;
    localparam FINAL_STATE = 5'b1111;
    localparam CLEAR_BRAM = 5'b10000;
    //add replenish food state

    //fsm states for direction:
    //localparam UP = 3'b000;
    //localparam UP_RIGHT = 3'b001;
    localparam RIGHT = 2'b10;
    //localparam DOWN_RIGHT = 3'b011;
    localparam DOWN = 2'b00;
    //localparam DOWN_LEFT = 3'b101;
    localparam LEFT = 2'b01;
    //localparam UP_LEFT = 3'b111;
    
    logic [31:0] random_num;
    rng random_num_gen(.rst_in(rst_in), .clk_in(clk_in), .num_sel(rng_sel), .shifted_res(random_num));
   
    logic [1:0] mod;
    modulus mod_res(.ind(ind), .mod(mod)); //if mod=0:ind%GRID_WIDTH=0, mod = 1:ind%GRID_WIDTH=95, 2=neither
    
    
    logic [29:0] data_from_bram_1;
    logic [12:0] addr_1, addr_2;
    logic which_bram;
    assign addr_1 = addr_ppl_1;
    assign addr_2 = addr_ppl_2;
    assign which_bram = ppl_bram;
    assign data_from_bram_1 = ppl_from_bram_1;
    
    
    logic food_zone1;    
    assign food_zone1 = (ind>=1168&&ind<1184)||(ind>=1264&&ind<1280)||(ind>=1360&&ind<1376)||(ind>=1456&&ind<1472)||(ind>=1552&&ind<1568)||
                         (ind>=1648&&ind<1664)||(ind>=1744&&ind<1760)||(ind>=1840&&ind<1856)||(ind>=1936&&ind<1952)||(ind>=2032&&ind<2048)||
                         (ind>=2128&&ind<2144)||(ind>=2224&&ind<2240)||(ind>=2320&&ind<2336)||(ind>=2416&&ind<2432)||(ind>=2512&&ind<2528)||
                         (ind>=2608&&ind<2624)||(ind>=2704&&ind<2720)||(ind>=2800&&ind<2816)||(ind>=2896&&ind<2912)||(ind>=2992&&ind<3008)||
                         (ind>=3088&&ind<3104)||(ind>=3184&&ind<3200)||(ind>=3280&&ind<3296)||(ind>=3376&&ind<3392)||(ind>=3472&&ind<3488)||
                         (ind>=3568&&ind<3584)||(ind>=3664&&ind<3680)||(ind>=3760&&ind<3776)||(ind>=3856&&ind<3872)||(ind>=3952&&ind<3968)||
                         (ind>=4048&&ind<4064)||(ind>=4144&&ind<4160)||(ind>=4240&&ind<4256)||(ind>=4336&&ind<4352)||(ind>=4432&&ind<4448)||
                         (ind>=4528&&ind<4544)||(ind>=4624&&ind<4640)||(ind>=4720&&ind<4736)||(ind>=4816&&ind<4832)||(ind>=4912&&ind<4928)||
                         (ind>=5008&&ind<5024)||(ind>=5104&&ind<5120)||(ind>=5200&&ind<5216)||(ind>=5296&&ind<5312)||(ind>=5392&&ind<5408)||
                         (ind>=5488&&ind<5504)||(ind>=5584&&ind<5600)||(ind>=5680&&ind<5696)||(ind>=5776&&ind<5792) ? 1 : 0;
                         
    logic food_zone2; 
    assign food_zone2 = (ind>=80&&ind<96)||(ind>=176&&ind<192)||(ind>=272&&ind<288)||(ind>=368&&ind<384)||(ind>=464&&ind<480)||
                        (ind>=560&&ind<576)||(ind>=656&&ind<672)||(ind>=752&&ind<768)||(ind>=848&&ind<864)||(ind>=944&&ind<960)||
                        (ind>=1040&&ind<1056)||(ind>=1136&&ind<1152)||(ind>=1232&&ind<1248)||(ind>=1328&&ind<1344)||(ind>=1424&&ind<1440)||
                        (ind>=1520&&ind<1536)||(ind>=1616&&ind<1632)||(ind>=1712&&ind<1728)||(ind>=1808&&ind<1824)||(ind>=1904&&ind<1920)||
                        (ind>=2000&&ind<2016)||(ind>=2096&&ind<2112)||(ind>=2192&&ind<2208)||(ind>=2288&&ind<2304)||(ind>=2384&&ind<2400)||
                        (ind>=2480&&ind<2496)||(ind>=2576&&ind<2592)||(ind>=2672&&ind<2688)||(ind>=2768&&ind<2784)||(ind>=2864&&ind<2880)||
                        (ind>=2960&&ind<2976)||(ind>=3056&&ind<3072)||(ind>=3152&&ind<3168)||(ind>=3248&&ind<3264)||(ind>=3344&&ind<3360)||
                        (ind>=3440&&ind<3456)||(ind>=3536&&ind<3552)||(ind>=3632&&ind<3648)||(ind>=3728&&ind<3744)||(ind>=3824&&ind<3840)||
                        (ind>=3920&&ind<3936)||(ind>=4016&&ind<4032)||(ind>=4112&&ind<4128)||(ind>=4208&&ind<4224)||(ind>=4304&&ind<4320)||
                        (ind>=4400&&ind<4416)||(ind>=4496&&ind<4512)||(ind>=4592&&ind<4608) ? 1 : 0;
    
    logic flood_zone;
    assign flood_zone = (ind>=0&&ind<16)||(ind>=80&&ind<112)||(ind>=176&&ind<208)||(ind>=272&&ind<304)||(ind>=368&&ind<400)||
                        (ind>=464&&ind<496) ||(ind>=560&&ind<592)||(ind>=656&&ind<688)||(ind>=752&&ind<784)||(ind>=848&&ind<880)||
                        (ind>=944&&ind<976)||(ind>=1040&&ind<1072)||(ind>=1136&&ind<1168)||(ind>=1232&&ind<1264)||(ind>=1328&&ind<1360)||
                        (ind>=1424&&ind<1456)||(ind>=1552&&ind<1584)||(ind>=1616&&ind<1648)||(ind>=1712&&ind<1744)||(ind>=1808&&ind<1840)||
                        (ind>=1904&&ind<1936)||(ind>=2000&&ind<2032)||(ind>=2096&&ind<2128)||(ind<=2192&&ind<2224)||(ind>=2288&&ind<2320)||
                        (ind>=2384&&ind<2416)||(ind>=2480&&ind<2512)||(ind>=2576&&ind<2608)||(ind>=2672&&ind<2704)||(ind>=2768&&ind<2800)||
                        (ind>=2864&&ind<2896)||(ind>=2960&&ind<2992)||(ind>=3056&&ind<3088)||(ind>=3152&&ind<3184)||(ind>=3248&&ind<3280)||
                        (ind>=3344&&ind<2276)||(ind>=3440&&ind<3472)||(ind>=3536&&ind<3568)||(ind>=3632&&ind<3664)||(ind>=3728&&ind<3760)||
                        (ind>=3824&&ind<3856)||(ind>=3920&&ind<3952)||(ind>=4016&&ind<4048)||(ind>=4112&&ind<4144)||(ind>=4208&&ind<4240)||
                        (ind>=4304&&ind<4336)||(ind>=4400&&ind<4432)||(ind>=4496&&ind<4528)||(ind>=4592&&ind<4624)||(ind>=4688&&ind<4720)||
                        (ind>=4784&&ind<4816)||(ind>=4880&&ind<4912)||(ind>=4976&&ind<5008)||(ind>=5072&&ind<5104)||(ind>=5168&&ind<5200)||
                        (ind>=5264&&ind<5296)||(ind>=5360&&ind<5392)||(ind>=5456&&ind<5488)||(ind>=5552&&ind<5584)||(ind>=5648&&ind<5680)||
                        (ind>=5744&&ind<5776)||(ind>-5840&&ind<5872)||(ind>=5936&&ind<5968)||(ind>=6032&&ind<6064)||(ind>=6128&&ind<6160)||
                        (ind>=6224&&ind<6256)||(ind>=6320&&ind<6352)||(ind>=6416&&ind<6448)||(ind>=6512&&ind<6544)||(ind>=6608&&ind<6640)||
                        (ind>=6704&&ind<6736)||(ind>=6800&&ind<6832)||(ind>=6896) ? 1 : 0;
    
    always_comb begin
      lookup_addr[0] = (ind<GRID_WIDTH) || (mod==0) ? MAX: ind - GRID_WIDTH - 1; //upper left
      lookup_addr[1] = (ind<GRID_WIDTH) ? MAX: ind - GRID_WIDTH; //direct above
      lookup_addr[2] = (ind<GRID_WIDTH) || (mod==1) ? MAX: ind - GRID_WIDTH + 1; //upper right
      lookup_addr[3] = (mod==0)? MAX: ind + GRID_WIDTH - 2; //direct left
      lookup_addr[4] = (mod==1) ? MAX: ind + GRID_WIDTH; //direct right
      lookup_addr[5] = (ind>=6816) || (mod==0) ? MAX: ind + GRID_WIDTH - 1; //lower left
      lookup_addr[6] = (ind>=6816) ? MAX: ind - 1; //direct below
      lookup_addr[7] = (ind>=6816) || (mod==1) ? MAX: ind + GRID_WIDTH + 1; //lower right
    end

     always_ff @(posedge clk_in) begin
        case (game_state)
          INITIALIZE: begin
                    init_counter <= init_counter - 1;
                    if (init_counter == 0) begin
                        //set everything to 0 and start game
                        food_1 <= 8'd127;
                        food_2 <= 8'd127;
                        write_ppl_1 <= 0;
                        write_ppl_2 <= 0;
                        addr_ppl_1 <= 0;
                        ppl_to_bram <= 0;
                        init <= 0;
                        ppl_bram <= ~ppl_bram;
                        game_state <= LOOKUP_CURR;
                    end else if (init_counter == 6'd50) begin
                        //initializing max boundary
                        write_ppl_1 <= 1;
                        write_ppl_2 <= 1;
                        addr_ppl_1 <= MAX;
                        addr_ppl_2 <= MAX;
                        ppl_to_bram <= {8'b0, 22'h3FFFFF};
                    end else if (init_counter <= 6'd48 && init_counter > 6'd16) begin
                        //spawning food zones
                        write_ppl_2 <= 0;
                        write_ppl_1 <= 1;
                        if (init_counter%4 == 0) begin 
                            food_addr <= random_num[11:0];
                            addr_ppl_1 <= random_num[11:0]; 
                        end else if (init_counter%4 == 1) addr_ppl_1 <= food_addr + 1;
                        else if (init_counter%4 == 2) addr_ppl_1 <= food_addr + GRID_WIDTH;
                        else if (init_counter%4 == 3) addr_ppl_1 <= food_addr + GRID_WIDTH + 1;
                        ppl_to_bram <= initial_food_state;
                    end else if (init_counter <= 6'd16 && init_counter > 0) begin
                        //spawning ppl
                        write_ppl_1 <= 1;
                        addr_ppl_1 <= random_num[11:0];
                        ppl_to_bram <= {initial_ppl_state, 1'b0, random_num[1:0]};
                    end
                  end
          LOOKUP_CURR: begin //lookup using count
                     write_ppl_1 <= 0;
                     write_ppl_2 <= 0;
                     if (ppl_bram) addr_ppl_1 <= ind;
                     else addr_ppl_2 <= ind;
                     game_state <= game_state + 1;
                   end
          LOOKUP_UPLEFT:begin //feed in addr to get upper left cell
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[0];//if A is ative get from A
                    else addr_ppl_2 <= lookup_addr[0]; //else get from B
                    game_state <= game_state + 1;
                  end
          LOOKUP_UP:begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[1]; //ask for upper one from A
                    else addr_ppl_2 <= lookup_addr[1]; //or ask for upper one from B
                    //by this point we have center point cell data
                    
                    if (ppl_bram) begin //if empty jump to final state
                        if (ppl_from_bram_1[14:8] == 0 && ~ppl_from_bram_1[29]) game_state <= FINAL_STATE;
                        else if (~|ppl_from_bram_1[21:0] && |ppl_from_bram_1[28:22]) begin
                            game_state <= STORE_FOOD; //if food zone and no person skip
                            food_indicator <= ppl_from_bram_1[29];
                            food_storage <= ppl_from_bram_1[28:22];
                            
                            food_count <= ppl_from_bram_1[21:15]; //7
                            age <= ppl_from_bram_1[14:8]; //7
                            //counter <= (ppl_bram) ? ppl_from_bram_1[7:3] : ppl_from_bram_2[7:3]; //5
                            dir <= ppl_from_bram_1[1:0]; //3
                         end else begin //store the current cell's information
                            food_indicator <= ppl_from_bram_1[29];
                            food_storage <= ppl_from_bram_1[28:22];
                            food_count <= ppl_from_bram_1[21:15]; //7
                            age <= ppl_from_bram_1[14:8]; //7
                            //counter <= (ppl_bram) ? ppl_from_bram_1[7:3] : ppl_from_bram_2[7:3]; //5
                            dir <= ppl_from_bram_1[1:0]; //3
                            game_state <= game_state + 1;
                        end 
                    end else if (~ppl_bram) begin
                        if (ppl_from_bram_2[14:8] == 0 && ~ppl_from_bram_2[29]) game_state <= FINAL_STATE;
                        else if (~|ppl_from_bram_2[21:0] && |ppl_from_bram_2[28:22]) begin
                            game_state <= STORE_FOOD;
                            food_storage <= ppl_from_bram_2[28:22];
                            food_indicator <= ppl_from_bram_2[29];
                            
                            food_count <= ppl_from_bram_2[21:15]; //7
                            age <= ppl_from_bram_2[14:8]; //7
                            //counter <= (ppl_bram) ? ppl_from_bram_1[7:3] : ppl_from_bram_2[7:3]; //5
                            dir <= ppl_from_bram_2[1:0]; //3
                        end else begin //store the current cell's information
                            food_indicator <= ppl_from_bram_2[29];
                            food_storage <= ppl_from_bram_2[28:22];
                            food_count <= ppl_from_bram_2[21:15]; //7
                            age <= ppl_from_bram_2[14:8]; //7
                            //counter <= (ppl_bram) ? ppl_from_bram_1[7:3] : ppl_from_bram_2[7:3]; //5
                            dir <= ppl_from_bram_2[1:0]; //3
                            game_state <= game_state + 1;
                        end
                    end 
                  end  
          LOOKUP_UPRIGHT:begin //beginning here we need to feed in new address and read out the output
                    if (flood) begin //check if flood
                        if (flood_zone) begin
                            game_state <= FINAL_STATE;
                            if (~ppl_bram) begin
                                addr_ppl_1 <= ind;
                                write_ppl_1 <= 1;
                                ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                            end else begin
                                addr_ppl_2 <= ind;
                                write_ppl_2 <= 1;
                                ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                            end
                        end else begin
                            write_ppl_1 <= 0;
                            write_ppl_2 <= 0;

                            if (ppl_bram) addr_ppl_1 <= lookup_addr[2]; //ask for upper right from A
                            else addr_ppl_2 <= lookup_addr[2];  //ask for upper right from B


                            if (ppl_bram) surroundings[0] <= ppl_from_bram_1; //data present from upper left lookup. store it
                            else surroundings[0] <= ppl_from_bram_2;//or if b is active, store that from b

                            game_state <= game_state+1;
                        end
                    end else begin
                        write_ppl_1 <= 0;
                        write_ppl_2 <= 0;

                        if (ppl_bram) addr_ppl_1 <= lookup_addr[2]; //ask for upper right from A
                        else addr_ppl_2 <= lookup_addr[2];  //ask for upper right from B


                        if (ppl_bram) surroundings[0] <= ppl_from_bram_1; //data present from upper left lookup. store it
                        else surroundings[0] <= ppl_from_bram_2;//or if b is active, store that from b

                        game_state <= game_state+1;
                     end
                  end  
          LOOKUP_LEFT: begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[3]; //ask for direct left from A
                    else addr_ppl_2 <= lookup_addr[3];  //ask for direct left from B
                    
                    if (ppl_bram) surroundings[1] <= ppl_from_bram_1; //data present from direct above lookup. store it
                    else surroundings[1] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          LOOKUP_RIGHT: begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[4]; //ask for direct right from A
                    else addr_ppl_2 <= lookup_addr[4];  //ask for direct right from B
                    
                    if (ppl_bram) surroundings[2] <= ppl_from_bram_1; //data present from upper right lookup. store it
                    else surroundings[2] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          LOOKUP_DOWNLEFT: begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[5]; //ask for lower left from A
                    else addr_ppl_2 <= lookup_addr[5];  //ask for lower left from B
                    
                    if (ppl_bram) surroundings[3] <= ppl_from_bram_1; //data present from direct left lookup. store it
                    else surroundings[3] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          LOOKUP_DOWN: begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[6]; //ask for direct below from A
                    else addr_ppl_2 <= lookup_addr[6];  //ask for direct below from B
                    
                    if (ppl_bram) surroundings[4] <= ppl_from_bram_1; //data present from direct right lookup. store it
                    else surroundings[4] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          LOOKUP_DOWNRIGHT: begin
                    if (ppl_bram) addr_ppl_1 <= lookup_addr[7]; //ask for lower right from A
                    else addr_ppl_2 <= lookup_addr[7];  //ask for lower right from B
                    
                    if (ppl_bram) surroundings[5] <= ppl_from_bram_1; //data present from lower left lookup. store it
                    else surroundings[5] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          STORE_DOWN: begin
                    if (ppl_bram) surroundings[6] <= ppl_from_bram_1; //data present from direct below lookup. store it
                    else surroundings[6] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          STORE_DOWNRIGHT: begin
                    if (ppl_bram) surroundings[6] <= ppl_from_bram_1; //data present from direct below lookup. store it
                    else surroundings[6] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    if (ppl_bram) surroundings[7] <= ppl_from_bram_1; //data present from lower right lookup. store it
                    else surroundings[7] <= ppl_from_bram_2;//or if b is active, store that from b
                    
                    game_state <= game_state+1;
                   end
          MOVE_PPL:begin //done retrieving all information
                    
                    //how do we check if a bldg exists at edge of screen?
                    //in this step we can check whether to generate a bldg
                    //check for collisions?
                    
                    case (dir)
//                        UP: begin //check if person is at surroundings[1]
//                              if (surroundings[1][14:8] > 0) begin
//                                if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
//                                else addr_ppl_2 <= ind - GRID_WIDTH - 1;
//                                ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, DOWN};
//                              end else begin
//                                if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - GRID_WIDTH - 1;
//                                else addr_ppl_2 <= ind - GRID_WIDTH - GRID_WIDTH - 1;
//                                //ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, UP};
//                                ppl_to_bram <= {surroundings[1][29:22], food_count, age, 5'b0, UP};
//                              end
//                            end
//                        UP_RIGHT: begin //check if person is at surroundings[2]
//                                      if (surroundings[2][14:8] > 0) begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
//                                        else addr_ppl_2 <= ind - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, RIGHT};
//                                      end else begin
//                                        if (~ppl_bram) addr_ppl_1 <=  ind - GRID_WIDTH + 1 - GRID_WIDTH - 1; //we store new addr
//                                        else addr_ppl_2 <= ind - GRID_WIDTH + 1 - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {surroundings[2][29:22], food_count, age, 5'b0, UP_RIGHT};
//                                      end   
//                                   end
                        RIGHT: begin //check if person is at surroundings[4]
                                      if (surroundings[4][14:8] > 0) begin
                                        if (~ppl_bram) addr_ppl_1 <= random_num[11:0];
                                        else addr_ppl_2 <= random_num[11:0];
                                        
                                        if (age + 1 >= MAX_AGE) ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                                        else begin
                                            ppl_to_bram <= {food_indicator, food_storage, food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                            num_collisions <= num_collisions + 1;
                                            stored_addr <= ind - GRID_WIDTH - 1;
                                        end
                                      end else begin
                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH;//we store new addr
                                        else addr_ppl_2 <= ind - GRID_WIDTH;
                                        
                                        if (age + 1 >= MAX_AGE) ppl_to_bram <= {surroundings[4][29:22], 22'b0};
                                        else ppl_to_bram <= {surroundings[4][29:22], food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                      end 
                               end
//                        DOWN_RIGHT: begin //check if person is at surroundings[7]
//                                      if (surroundings[7][14:8] > 0) begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
//                                        else addr_ppl_2 <= ind - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, LEFT};
//                                      end else begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind;//we store new addr
//                                        else addr_ppl_2 <= ind;
//                                        ppl_to_bram <= {surroundings[7][29:22], food_count, age, 5'b0, DOWN_RIGHT};
//                                      end
//                                    end
                        DOWN: begin //check if person is at surroundings[6]
                                  if (surroundings[6][14:8] > 0) begin
                                    if (~ppl_bram) addr_ppl_1 <= random_num[11:0];
                                    else addr_ppl_2 <= random_num[11:0];
                                    
                                    if (age + 1 >= MAX_AGE) ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                                    else begin
                                        num_collisions <= num_collisions + 1;
                                        stored_addr <= ind - GRID_WIDTH - 1;
                                        ppl_to_bram <= {food_indicator, food_storage, food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                    end
                                  end else begin
                                    if (~ppl_bram) addr_ppl_1 <= ind -1;//we store new addr
                                    else addr_ppl_2 <= ind-1;
                                    
                                    if (age + 1 >= MAX_AGE) ppl_to_bram <= {surroundings[6][29:22], 22'b0};
                                    else ppl_to_bram <= {surroundings[6][29:22], food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                  end
                              end
//                        DOWN_LEFT: begin //check if person is at surroundings[5]
//                                      if (surroundings[5][14:8] > 0) begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
//                                        else addr_ppl_2 <= ind - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, DOWN_LEFT};
//                                      end else begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - 2; //we store new addr
//                                        else addr_ppl_2 <= ind - 2;
//                                        ppl_to_bram <= {surroundings[5][29:22], food_count, age, 5'b0, DOWN_LEFT};
//                                      end
//                                   end
                        LEFT: begin //check if person is at surroundings[3]
                                  if (surroundings[3][14:8] > 0) begin
                                    if (~ppl_bram) addr_ppl_1 <= random_num[11:0];
                                    else addr_ppl_2 <= random_num[11:0];
                                    
                                    if (age + 1 >= MAX_AGE) ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                                    else begin
                                        num_collisions <= num_collisions + 1;
                                        stored_addr <= ind - GRID_WIDTH - 1;
                                        ppl_to_bram <= {food_indicator, food_storage - 1, food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                     end
                                  end else begin
                                    if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 2;//we store new addr
                                    else addr_ppl_2 <= ind - GRID_WIDTH - 2;
                                    
                                    if (age + 1 >= MAX_AGE) ppl_to_bram <= {surroundings[3][29:22], 22'b0};
                                    else ppl_to_bram <= {surroundings[3][29:22], food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                  end
                              end
//                        UP_LEFT: begin //check if person is at surroundings[0]
//                                      if (surroundings[0][14:8] > 0) begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
//                                        else addr_ppl_2 <= ind - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {food_indicator, food_storage, food_count, age, 5'b0, UP};
//                                      end else begin
//                                        if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1 - GRID_WIDTH - 1;//we store new addr
//                                        else addr_ppl_2 <= ind - GRID_WIDTH - 1 - GRID_WIDTH - 1;
//                                        ppl_to_bram <= {surroundings[0][29:22], food_count, age, 5'b0, UP_LEFT};
//                                      end
//                                  end
                         default : begin
                                      if (~ppl_bram) addr_ppl_1 <= ind - GRID_WIDTH - 1;
                                      else addr_ppl_2 <= ind - GRID_WIDTH - 1;
                                      
                                      if (age + 1 >= MAX_AGE) ppl_to_bram <= {food_indicator, food_storage, 22'b0};
                                      else ppl_to_bram <= {food_indicator, food_storage - 1, food_count, age + 1, 5'b0, 1'b0, random_num[1:0]};
                                   end
                    endcase
                    
                    if (~ppl_bram) write_ppl_1 <= 1;
                    else write_ppl_2 <= 1;
                    game_state <= SPAWN_PPL;
                  end  
          SPAWN_PPL:begin
                    if (num_collisions == 0) time_since_last <= time_since_last + 1;
                    else if (num_collisions > 0) begin
                        num_collisions <= num_collisions - 1;
                        if (~ppl_bram) begin write_ppl_1 <= 1; addr_ppl_1 <= stored_addr; end
                        else begin write_ppl_2 <= 1; addr_ppl_2 <= stored_addr; end
                        ppl_to_bram <= {initial_ppl_state, 1'b0, random_num[1:0]};
                    end else if (time_since_last >= 3) begin
                        if (~ppl_bram) begin write_ppl_1 <= 1; addr_ppl_1 <= random_num[11:0]; end
                        else begin write_ppl_2 <= 1; addr_ppl_2 <= random_num[11:0]; end
                        ppl_to_bram <= {initial_ppl_state, 1'b0, random_num[1:0]};
                        time_since_last <= time_since_last - 1;
                        game_state <= (time_since_last == 0) ? FINAL_STATE : SPAWN_PPL;
                    end
                    
                    game_state <= FINAL_STATE;
                  end  
          STORE_FOOD:begin 
                    //maybe use this step to program new position?
                    if (~ppl_bram) begin
                        write_ppl_1 <= 1;
                        addr_ppl_1 <= ind - GRID_WIDTH - 1;
                    end else begin
                        write_ppl_2 <= 1;
                        addr_ppl_2 <= ind - GRID_WIDTH - 1;
                    end
                    ppl_to_bram <= {food_indicator, food_storage, food_count, age, 6'b0, dir};
                    game_state <= game_state+1;
                  end  
          FINAL_STATE:begin //final state (if you want...or you have 1110 and 1111 if you need them
                    write_ppl_1 <= 0;
                    write_ppl_2 <= 0;
                    
                    if (ind >= PPL_BRAM_SIZE) begin
                        if (game_step) begin
//                            bldg_counter <= bldg_counter + 1; //only increment bldg_counter every game cycle
//                            build <= (bldg_counter == 5'd31);
//                            if (bldg_counter == 5'd31) bldg_counter <= 0; //reset counter
                            
                            game_state <= CLEAR_BRAM;
                            ppl_bram <= ~ppl_bram;
                            ind <= 0; //increment count (cell for transer)
                        end 
                    end else begin
                        game_state <= LOOKUP_CURR;
                        ind <= ind + 1;
                    end
                  end 
          CLEAR_BRAM: begin
                       if (ind <= PPL_BRAM_SIZE) begin
                            ind <= ind + 1;
                            if (ppl_bram) begin //writing to 2
                                addr_ppl_2 <= ind;
                                write_ppl_2 <= 1;
                                write_ppl_1 <= 0;
                                ppl_to_bram <= 30'b0;
                            end else begin //writing to 1
                                addr_ppl_1 <= ind;
                                write_ppl_1 <= 1;
                                write_ppl_2 <= 0;
                                ppl_to_bram <= 30'b0;
                            end
                       end else begin
                            game_state <= (init) ? INITIALIZE : LOOKUP_CURR;
                            ind <= 0;
                            write_ppl_1 <= 0;
                            write_ppl_2 <= 0;
                       end
                   end
          default : begin //always wear seatbelts
                    write_ppl_1 <= 0;
                    write_ppl_2 <= 0;
                    game_state <= 0;
                  end 
        endcase 
    
      
    if (rst_in) begin //put at the end to override any assignment above 
        write_ppl_1  <= 0;
        write_ppl_2  <= 0;
        ppl_bram   <= 0;
        ind   <= 0;
        init <= 1;
        game_state   <= CLEAR_BRAM;
        init_counter <= 6'd50;
        time_since_last <= 0;
        num_collisions <= 0;
        bldg_counter <= 0;
      end
    end

endmodule


module modulus(input [12:0] ind, output logic [1:0] mod);
    always_comb begin
        case (ind)
            //ind % GRID_WIDTH (96) == 0
            13'd0: mod = 0;
            13'd96: mod = 0;
            13'd192: mod = 0;
            13'd288: mod = 0;
            13'd384: mod = 0;
            13'd480: mod = 0;
            13'd576: mod = 0;
            13'd672: mod = 0;
            13'd768: mod = 0;
            13'd864: mod = 0;
            13'd960: mod = 0;
            13'd1056: mod = 0;
            13'd1152: mod = 0;
            13'd1248: mod = 0;
            13'd1344: mod = 0;
            13'd1440: mod = 0;
            13'd1536: mod = 0;
            13'd1632: mod = 0;
            13'd1728: mod = 0;
            13'd1824: mod = 0;
            13'd1920: mod = 0;
            13'd2016: mod = 0;
            13'd2112: mod = 0;
            13'd2208: mod = 0;
            13'd2304: mod = 0;
            13'd2400: mod = 0;
            13'd2496: mod = 0;
            13'd2592: mod = 0;
            13'd2688: mod = 0;
            13'd2784: mod = 0;
            13'd2880: mod = 0;
            13'd2976: mod = 0;
            13'd3072: mod = 0;
            13'd3168: mod = 0;
            13'd3264: mod = 0;
            13'd3360: mod = 0;
            13'd3456: mod = 0;
            13'd3552: mod = 0;
            13'd3648: mod = 0;
            13'd3744: mod = 0;
            13'd3840: mod = 0;
            13'd3936: mod = 0;
            13'd4032: mod = 0;
            13'd4128: mod = 0;
            13'd4224: mod = 0;
            13'd4320: mod = 0;
            13'd4416: mod = 0;
            13'd4512: mod = 0;
            13'd4608: mod = 0;
            13'd4704: mod = 0;
            13'd4800: mod = 0;
            13'd4896: mod = 0;
            13'd4992: mod = 0;
            13'd5088: mod = 0;
            13'd5184: mod = 0;
            13'd5280: mod = 0;
            13'd5376: mod = 0;
            13'd5472: mod = 0;
            13'd5568: mod = 0;
            13'd5664: mod = 0;
            13'd5760: mod = 0;
            13'd5856: mod = 0;
            13'd5952: mod = 0;
            13'd6048: mod = 0;
            13'd6144: mod = 0;
            13'd6240: mod = 0;
            13'd6336: mod = 0;
            13'd6432: mod = 0;
            13'd6528: mod = 0;
            13'd6624: mod = 0;
            13'd6720: mod = 0;
            13'd6816: mod = 0;
            //ind % GRID_WIDTH (96) == 95
            13'd95: mod = 1;
            13'd191: mod = 1;
            13'd287: mod = 1;
            13'd383: mod = 1;
            13'd479: mod = 1;
            13'd575: mod = 1;
            13'd671: mod = 1;
            13'd767: mod = 1;
            13'd863: mod = 1;
            13'd959: mod = 1;
            13'd1055: mod = 1;
            13'd1151: mod = 1;
            13'd1247: mod = 1;
            13'd1343: mod = 1;
            13'd1439: mod = 1;
            13'd1535: mod = 1;
            13'd1631: mod = 1;
            13'd1727: mod = 1;
            13'd1823: mod = 1;
            13'd1919: mod = 1;
            13'd2015: mod = 1;
            13'd2111: mod = 1;
            13'd2207: mod = 1;
            13'd2303: mod = 1;
            13'd2399: mod = 1;
            13'd2495: mod = 1;
            13'd2591: mod = 1;
            13'd2687: mod = 1;
            13'd2783: mod = 1;
            13'd2879: mod = 1;
            13'd2975: mod = 1;
            13'd3071: mod = 1;
            13'd3167: mod = 1;
            13'd3263: mod = 1;
            13'd3359: mod = 1;
            13'd3455: mod = 1;
            13'd3551: mod = 1;
            13'd3647: mod = 1;
            13'd3743: mod = 1;
            13'd3839: mod = 1;
            13'd3935: mod = 1;
            13'd4031: mod = 1;
            13'd4127: mod = 1;
            13'd4223: mod = 1;
            13'd4319: mod = 1;
            13'd4415: mod = 1;
            13'd4511: mod = 1;
            13'd4607: mod = 1;
            13'd4703: mod = 1;
            13'd4799: mod = 1;
            13'd4895: mod = 1;
            13'd4991: mod = 1;
            13'd5087: mod = 1;
            13'd5183: mod = 1;
            13'd5279: mod = 1;
            13'd5375: mod = 1;
            13'd5471: mod = 1;
            13'd5567: mod = 1;
            13'd5663: mod = 1;
            13'd5759: mod = 1;
            13'd5855: mod = 1;
            13'd5951: mod = 1;
            13'd6047: mod = 1;
            13'd6143: mod = 1;
            13'd6239: mod = 1;
            13'd6335: mod = 1;
            13'd6431: mod = 1;
            13'd6527: mod = 1;
            13'd6623: mod = 1;
            13'd6719: mod = 1;
            13'd6815: mod = 1;
            13'd6911: mod = 1;
            default: mod = 2;
        endcase
    end
endmodule