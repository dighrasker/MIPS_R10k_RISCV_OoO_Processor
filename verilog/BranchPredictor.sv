`include "verilog/sys_defs.svh"

module branchpredictor #(
) (
    input   logic                                clock, 
    input   logic                                reset,

    // ------------- TO/FROM FETCH or BTB -------------- //
    input  ADDR                         [`N-1:0] PCs,
    input  logic                        [`N-1:0] valid_branch,
    output BRANCH_PREDICTOR_PACKET      [`N-1:0] bp_packets,

    // ------------- TO/FROM BRANCH STACK -------------- //
    input BRANCH_PREDICTOR_PACKET [`B_MASK_WIDTH-1:0] bs_bp_packets,
    input B_MASK                                      bs_branches_popping, 
    input B_MASK_MASK                                 bs_branch_resolving
    //bs_branches_popping will INCLUDE bs_branch_resolving
    //need to modify branches_popping to strictly exclude branch_resolving
    //[NOT(resolving)] AND [popping]

`ifdef DEBUG
    , output BP_DEBUG                                 bp_debug //define BP_DEBUG later sys defs
`endif
); 

BRANCH_PREDICTOR_PACKET [`N-1:0] next_bp_packets; //might not need this

//instantiate pht data structures (TODO: i did this wrong, figure out right typedefs)
logic [`HISTORY_BITS-1:0][1:0] gshare_pht, next_gshare_pht;
logic [`HISTORY_BITS-1:0][1:0] simple_pht, next_simple_pht;
logic [`HISTORY_BITS-1:0][1:0] meta_pht, next_meta_pht; 
BHR                            bhr, next_bhr;

//TODO: add logic for branch stack modifications later (repairs)

always_comb begin   
    next_bp_packets = bp_packets;
    next_gshare_pht = gshare_pht;
    next_simple_pht = simple_pht;
    next_meta_pht = meta_pht;
    next_bhr = bhr;
    
    
    //TODO: figure out how to update the meta predictor?
    //TODO: figure out how to update the meta predictor?
    //TODO: figure out how to update the meta predictor?
    //TODO: figure out how to update the meta predictor?
    // initialized to strongly not taken, update the meta predictor at a specific address 

    //update branch predictor outputs 
    for (int i = 0; i < `N; ++i) begin  
        if (valid_branch[i]) begin 
            //assign PHT index outputs
            bp_packets[i].predictor_PHT_idx = PCs[i][`HISTORY_BITS-1:0] ^ bhr;  //is this correct?
            bp_packets[i].meta_PHT_idx = PCs[i][`HISTORY_BITS-1:0];
            bp_packets[i].meta_predictor_state = meta_pht[PCs[i][`HISTORY_BITS-1:0]];
            bp_packets[i].BHR_state = bhr;  

            //choose output based on meta predictor state
            //we will use the convention that MSB = 1 corresponds to GSHARE, and MSB = 0 corresponds to simple 
            if(meta_pht[PCs[i][`HISTORY_BITS-1:0]][1]) begin //GSHARE
                bp_packets.predictor_state[i] = gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]];
                bp_packets.predict_taken[i] = gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]][1];

                next_bhr = ((bhr << 1) | gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]][1]); //speculatively update BHR


            end else begin //simple
                bp_packets.predictor_state[i] = simple_pht[PCs[i][`HISTORY_BITS-1:0]];
                bp_packets.predict_taken[i] = simple_pht[PCs[i][`HISTORY_BITS-1:0]][1];

                next_bhr = ((bhr << 1) | simple_pht[PCs[i][`HISTORY_BITS-1:0]][1]); //speculatively update BHR
                
            end
        
        end

    end

    //bs inputs, popping and resolving branches
    for (int i = 0; i < `BMASK_WIDTH; ++i) begin
        if (bs_branches_popping[i]) begin //repair state for all one hot bmask bits
            if (bs_branches_resolving[i]) begin //resolving branch
                //the resolving branch
                //TODO: move towards GSHARE for resolving branch (bc it is mispredicted)
                if (bs_bp_packets[i].meta_predictor_state != STRONGLY_TAKEN) begin
                    next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state + 1; //TODO: can i do that with next_meta_pht?
                end else if (bs_bp_packets[i].meta_predictor_state == STRONGLY_TAKEN) begin
                    next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state;
                end
             

                if (bs_branches_resolving[i].predict_taken) begin //actually NT
                    //TODO: update BHR with correct prediction
                    next_bhr = {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b0}; //TODO: TODO TODO is this correct? 
                    //TODO: update gshare or simple predictor state 
                    if (bs_branches_resolving[i].meta_predictor_state[1]) begin
                        next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predictor_state - 1;  
                    end else if (~bs_branches_resolving[i].meta_predictor_state[1]) begin
                        next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].predictor_state - 1;
                    end
        
                end else if (~bs_branches_resolving[i].predict_taken) begin //actually T
                    //TODO: update BHR with correct prediction
                    next_bhr = {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b1};
                    //TODO: update gshare or simple predictor state 
                    if (bs_branches_resolving[i].meta_predictor_state[1]) begin
                        next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predictor_state + 1;  
                    end else if (~bs_branches_resolving[i].meta_predictor_state[1]) begin
                        next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].predictor_state + 1;
                    end

                end                         

            end else if ( (bs_branches_popping[i] & (~bs_branches_resolving[i])) ) begin //all popping branches, excluding the resolving branch
                next_meta_pht[bs_bp_packets[i].meta_PHT_index] = bs_bp_packets[i].meta_predictor_state;
                next_bhr = bs_bp_packets[i].BHR_state; 

                if (bs_bp_packets[i].meta_predictor_state[1]) begin //meta predictor MSB 1 -> restore GSHARE 
                    next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predictor_state;
                end else if (~bs_bp_packets[i].meta_predictor_state[1]) begin //meta predictor MSB 0 -> restore simple
                    next_simple_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predictor_state;
                end

            end


        end

    end

end


/* logic [`ADDR-1:0][`HISTORY_BITS-1:0] branch_hist_table, next_branch_hist_table; //PC index, history output
logic [`HISTORY_BITS-1:0][1:0] pattern_hist_table, next_pattern_hist_table; //history bits index, saturating ctr output

always_comb begin
    next_pattern_hist_table = pattern_hist_table;
    next_branch_hist_table = branch_hist_table; 

    if (branch_valid) begin

        //send prediction to fetch
        predict_taken = pattern_hist_table[branch_hist_table[branch_PC]][1]; //bit 1 is T/NT on the saturating counter

        //update BHT
        next_branch_hist_table[branch_PC] = ((branch_hist_table[branch_pc] << 1) | actual_taken);
        
        //update PHT
        if (actual_taken) begin
            next_pattern_hist_table[branch_hist_table[branch_PC]] = pattern_hist_table[branch_hist_table[branch_PC]] + 1'b1;
        end else if (~actual_taken) begin
            next_pattern_hist_table[branch_hist_table[branch_PC]] = pattern_hist_table[branch_hist_table[branch_PC]] - 1'b1;
        end

    end 
end */


always_ff @(posedge clock) begin
    if (reset) begin
        bp_packets <= '0;
        bhr <= '0;
        meta_pht <= '0;
        gshare_pht <= '0;
        simple_pht <= '0;

    end else begin
        bhr <= next_bhr;
        bp_packets <= next_bp_packets;
        meta_pht <= next_meta_pht;
        gshare_pht <= next_gshare_pht;
        simple_pht <= next_simple_pht;
        
    end
end


endmodule