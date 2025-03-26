`include "verilog/sys_defs.svh"

module branchpredictor #(
) (
    input   logic                                clock, 
    input   logic                                reset,

    // ------------- TO/FROM FETCH or BTB -------------- //
    input  ADDR                         [`N-1:0] PCs_out,
    input logic [`N-1:0]                [`N-1:0] branch_gnt_bus,
    input logic                         [`N-1:0] final_gnt_bus_line,
    input logic                                  no_branches,
    output BRANCH_PREDICTOR_PACKET      [`N-1:0] bp_packets,
    output logic                        [`N-1:0] predict_taken,
    //TODO: add new signals



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

//instantiate pht data structures (TODO: i did this wrong, figure out right typedefs)
TWO_BIT_PREDICTOR   [`PHT_SZ-1:0] gshare_pht, next_gshare_pht;
TWO_BIT_PREDICTOR   [`PHT_SZ-1:0] simple_pht, next_simple_pht;
CHOOSER             [`PHT_SZ-1:0] meta_pht, next_meta_pht;
BHR                               bhr, next_bhr;
//TODO: add new data structure that is N next_bhrs
BHR                      [`N-1:0] intermediate_bhrs;
BHR                      [`N-1:0] assigned_bhrs; // BHRS assigned to each branch inst

always_comb begin
    for (int i = 0; i < `N; ++i) begin
        intermediate_bhrs[i] = (bhr << i) | 1'b0;
    end

    assigned_bhrs = '0;
    for (int i = 0; i < `N; ++i) begin
        for(int j = 0; j < `N; ++j) begin
            if (branch_gnt_bus[j][i]) begin
                assigned_bhrs[i] = intermediate_bhrs[j];
            end
        end
    end
end

always_comb begin
    for(int j = 0; j < `N; ++j) begin
        if (branch_gnt_bus[j] == final_branch_gnt_line) begin
            next_bhr = (assigned_bhrs[j] << 1) | 1'b1;
            //need no branches check
        end
    end
end

always_comb begin   
    bp_packets = '0;
    next_gshare_pht = gshare_pht;
    next_simple_pht = simple_pht;
    next_meta_pht = meta_pht;
    next_bhr = bhr;

    //TODO: update intermediate BHRs on each cylce
        
    //update branch predictor outputs 
    for (int i = 0; i < `N; ++i) begin  

        //assign PHT index outputs
        bp_packets[i].gshare_PHT_idx = PCs_out[i][`HISTORY_BITS-1:0] ^ assigned_bhrs[i];  //is this correct?
        bp_packets[i].meta_PHT_idx = PCs_out[i][`HISTORY_BITS-1:0];
        bp_packets[i].meta_predictor_state = meta_pht[PCs_out[i][`HISTORY_BITS-1:0]];
        bp_packets[i].BHR_state = assigned_bhrs[i];  

        //choose output based on meta predictor state
        //we will use the convention that MSB = 1 corresponds to GSHARE, and MSB = 0 corresponds to simple 
        
        //store simple and gshare state 
        bp_packets[i].gshare_state = gshare_pht[assigned_bhrs[i] ^ PCs_out[i][`HISTORY_BITS-1:0]];
        bp_packets[i].simple_state = simple_pht[PCs_out[i][`HISTORY_BITS-1:0]];

        //store predict taken
        predict_taken[i] = meta_pht[PCs_out[i][`HISTORY_BITS-1:0]][1] ? bp_packets[i].gshare_state[1] : bp_packets[i].simple_state[1];
    
       

    end   

    for (int i = 0; i < `BMASK_WIDTH; ++i) begin
        if (bs_branches_resolving[i]) begin //resolving branch - either correct pred or mispred
            //LOGIC to update state for PHTs
            if (mispredict) begin //need to restore state and update accordingly
                //update BHR with correct prediction, update gshare/simple predictor state
                //bs_branches_resolving[i].predict_taken = 1 means that it was predicted T, should actually be NT

                //gshare mispredicted 
                if (bs_bp_packets[i].meta_predictor_state[1]) begin
                    next_bhr[bs_bp_packets[i].gshare_PHT_idx] = bs_bp_packets[i].gshare_state[1] ? 
                        {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b0} : 
                        {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b1} ;

                    next_gshare_pht[bs_bp_packets[i].gshare_PHT_idx] = bs_bp_packets[i].gshare_state[1] ?
                        bs_bp_packets[i].gshare_state - 1 : //TODO: is it stored state or current state? 
                        bs_bp_packets[i].gshare_state + 1 ;  

                    //update meta predictor towards simple if simple's prediction is different than gshare's (which means it is correct)
                    if ( (bs_bp_packets[i].gshare_state[1] != bs_bp_packets[i].simple_state[1]) && (meta_pht[bs_bp_packets[i].meta_PHT_idx] != 0) ) begin
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state - 1;
                    end                     
                end else begin //simple mispredicted 
                    next_bhr[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].simple_state[1] ? 
                        {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b0} : 
                        {bs_bp_packets[i].BHR_state[`HISTORY_BITS-1:1], 1'b1} ;

                    next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].simple_state[1] ? 
                        bs_bp_packets[i].simple_state + 1 :
                        bs_bp_packets[i].simple_state - 1 ;

                    if ( (bs_bp_packets[i].simple_state[1] != bs_bp_packets[i].gshare_state[1]) && (meta_pht[bs_bp_packets[i].meta_PHT_idx] != 3) ) begin
                        next_meta_pht[bs_bp_packets[i].gshare_PHT_idx] = bs_bp_packets[i].meta_predictor_state + 1;
                    end

                end         
                 
            end else begin //predicted correctly        

                //don't update BHR -- it was speculated correctly
                if (bs_bp_packets[i].meta_predictor_state[1]) begin //TODO: Think about this, it biases GSHARE because it is first
                    if (gshare_pht[bs_bp_packets[i].gshare_PHT_idx] != (0 || 3)) begin //predicted T, was T
                        next_gshare_pht[bs_bp_packets[i].gshare_PHT_idx] = bs_bp_packets[i].gshare_state[1] ? 
                            gshare_pht[bs_bp_packets[i].gshare_PHT_idx] + 1 : 
                            gshare_pht[bs_bp_packets[i].gshare_PHT_idx] - 1 ;
                    end else

                    //only increment towards gshare if simple is wrong
                    if (~bs_bp_packets[i].simple_state[1] && (meta_pht[bs_bp_packets[i].meta_PHT_idx] != 3)) begin 
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state + 1;
                    end 

                end else begin //meta predictor MSB 0, update simple
                    if (simple_pht[bs_bp_packets[i].meta_PHT_idx] != (0 || 3)) begin //predicted T, was T
                        next_simple_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].simple_state[1] ?
                        simple_pht[bs_bp_packets[i].meta_PHT_idx] + 1 : 
                        simple_pht[bs_bp_packets[i].meta_PHT_idx] - 1 ;
                    end else

                    if (~bs_bp_packets[i].gshare_state[1] && (meta_pht[bs_bp_packets[i].meta_PHT_idx] != 0)) begin 
                        next_meta_pht[bs_bp_packets[i].meta_PHT_idx] = bs_bp_packets[i].meta_predictor_state - 1;
                    end 
                end
            end
        end
    end
end



always_ff @(posedge clock) begin
    if (reset) begin
        bhr <= '0;
        meta_pht <= '0;
        gshare_pht <= '0;
        simple_pht <= '0;
    end else begin
        bhr <= next_bhr;
        meta_pht <= next_meta_pht;
        gshare_pht <= next_gshare_pht;
        simple_pht <= next_simple_pht;
    end
end


endmodule