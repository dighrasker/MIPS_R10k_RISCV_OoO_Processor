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
    input B_MASK_MASK                                 bs_branch_resolving,
    input logic                                       mispredict //TODO: add this to BS
    //bs_branches_popping will INCLUDE bs_branch_resolving
    //need to modify branches_popping to strictly exclude branch_resolving
    //[NOT(resolving)] AND [popping]

`ifdef DEBUG
    , output BP_DEBUG                                 bp_debug //define BP_DEBUG later sys defs
`endif
); 

BRANCH_PREDICTOR_PACKET [`N-1:0] next_bp_packets; //might not need this

//instantiate pht data structures (TODO: i did this wrong, figure out right typedefs)
PHT_SZ [1:0] gshare_pht, next_gshare_pht;
PHT_SZ [1:0] simple_pht, next_simple_pht;
PHT_SZ [1:0] meta_pht, next_meta_pht; 
BHR                            bhr, next_bhr;



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
            
            //store predictor state
            bp_packets[i].predictor_state = meta_pht[PCs[i][`HISTORY_BITS-1:0][1]] ? 
                gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]] : 
                simple_pht[PCs[i][`HISTORY_BITS-1:0]];
        
            //store predict taken
            bp_packets[i].predict_taken = meta_pht[PCs[i][`HISTORY_BITS-1:0][1]] ?
                gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]][1] :
                simple_pht[PCs[i][`HISTORY_BITS-1:0]][1]; 

            //store predictor taken values
            bp_packets[i].gshare_predict_taken = gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]][1];
            bp_packets[i].simple_predict_taken = simple_pht[PCs[i][`HISTORY_BITS-1:0]][1];

            //speculatively update bhr
            next_bhr = meta_pht[PCs[i][`HISTORY_BITS-1:0][1]] ?
                ((bhr << 1) | gshare_pht[bhr ^ PCs[i][`HISTORY_BITS-1:0]][1]) :
                ((bhr << 1) | simple_pht[PCs[i][`HISTORY_BITS-1:0]][1]);
        
            // TODO: figure out how to break at first taken branch (Kevin idea: do all in parallel, then use only oldest taken branch)

        end

    end

    //TODO: figure out how to update PHTs in complete
        //TODO: this I think requires knowledge of branch correctness -- we need to pass in resolving branches
    //bs inputs, popping and resolving branches
    for (int i = 0; i < `BMASK_WIDTH; ++i) begin
        //repair state for all one hot bmask bits
        if (bs_branches_resolving[i]) begin //resolving branch - either correct pred or mispred
            //LOGIC to update state for PHTs
            if (mispredict) begin //need to restore state and update accordingly
                //update BHR with correct prediction, update gshare/simple predictor state
                //bs_branches_resolving[i].predict_taken = 1 means that it was predicted T, should actually be NT
                next_bhr = bs_bp_packets[i].predict_taken ? {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b0} : {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b1}; //TODO: TODO TODO is this correct? 
                if (bs_bp_packets[i].meta_predictor_state[1]) begin
                    next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predict_taken ? bs_bp_packets[i].predictor_state - 1 : bs_bp_packets[i].predictor_state + 1;  
                    //Logic here is that if meta predictor state is 1, then gshare mispredicted
                    if (simple_predict_taken && (bs_bp_packets[i].meta_predictor_state != 0)) begin
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state - 1;
                    end //leave unchanged if both are wrong, so no else statement
                end else begin
                    next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].predict_taken ? bs_bp_packets[i].predictor_state - 1 : bs_bp_packets[i].predictor_state + 1 ;
                    if (gshare_predict_taken && (bs_bp_packets[i].meta_predictor_state != 3)) begin
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state + 1;
                    end 
                end
            end else begin //predicted correctly
                //don't update BHR -- it was speculated correctly
                if (bs_bp_packets[i].meta_predictor_state[1]) begin //TODO: Think about this, it biases GSHARE because it is first
                    if (gshare_pht[bs_bp_packets[i].predictor_PHT_idx] != (0 || 3)) begin //predicted T, was T
                        next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predict_taken ? gshare_pht[bs_bp_packets[i].predictor_PHT_idx] + 1 : gshare_pht[bs_bp_packets[i].predictor_PHT_idx] - 1;
                    end else begin  //if strongly taken or strongly NT already, doesn't change
                        next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = gshare_pht[bs_bp_packets[i].predictor_PHT_idx]; //probably redundant
                    end 

                    //only increment towards gshare if simple is wrong
                    if (~simple_predict_taken && (bs_bp_packets[i].meta_predictor_state != 3)) begin 
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state + 1;
                    end 

                end else begin //meta predictor MSB 0, update simple
                    if (simple_pht[bs_bp_packets[i].meta_PHT_idx] != (0 || 3)) begin //predicted T, was T
                        next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].predict_taken ? simple_pht[bs_bp_packets[i].meta_PHT_idx] + 1 : simple_pht[bs_bp_packets[i].meta_PHT_idx] - 1;
                    end else begin
                        next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = simple_pht[bs_bp_packets[i].meta_PHT_idx];
                    end

                    if (~gshare_predict_taken && (bs_bp_packets[i].meta_predictor_state != 0)) begin 
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state - 1;
                    end 
                end
            end
                       
        end else if ( (bs_branches_popping[i] & (~bs_branches_resolving[i])) ) begin //all popping branches, excluding the resolving branch
            next_meta_pht[bs_bp_packets[i].meta_PHT_index] = bs_bp_packets[i].meta_predictor_state;
            next_bhr = bs_bp_packets[i].BHR_state; 

            if (bs_bp_packets[i].meta_predictor_state[1]) begin //meta predictor MSB 1 -> restore GSHARE 
                next_gshare_pht[bs_bp_packets[i].predictor_PHT_idx] = bs_bp_packets[i].predictor_state;
            end else begin //meta predictor MSB 0 -> restore simple
                next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].predictor_state;
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