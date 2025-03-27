`include "verilog/sys_defs.svh"

module branchpredictor #(
) (
    input   logic                                clock, 
    input   logic                                reset,

    // ------------- TO/FROM FETCH or BTB -------------- //
    input  ADDR                         [`N-1:0] PCs_out,
    input logic [`N-1:0]                [`N-1:0] branch_gnt_bus,
    input logic                         [`N-1:0] final_gnt_bus_line,
    input logic                                  no_branches_fetched,
    input logic                         [`N-1:0] btb_hit,
    output BRANCH_PREDICTOR_PACKET      [`N-1:0] bp_packets,
    output logic                        [`N-1:0] branches_taken,
    //TODO: add new signals



    // ------------- TO/FROM BRANCH STACK -------------- //
    input BRANCH_PREDICTOR_PACKET                     bs_bp_packet,
    input logic                                       resolving_valid_branch,
    
    // ------------- TO/FROM EXECUTE -------------- //
    input logic                                       taken,
    input logic                                       mispred

`ifdef DEBUG
    , output BP_DEBUG                                 bp_debug //define BP_DEBUG later sys defs
`endif
); 

    TWO_BIT_PREDICTOR   [`PHT_SZ-1:0] gshare_pht, next_gshare_pht;
    TWO_BIT_PREDICTOR   [`PHT_SZ-1:0] simple_pht, next_simple_pht;
    CHOOSER             [`PHT_SZ-1:0] meta_pht, next_meta_pht;
    BHR                               bhr, next_bhr;
    BHR                      [`N-1:0] intermediate_bhrs;
    BHR                      [`N-1:0] assigned_bhrs; // BHRS assigned to each branch inst

    // Assign each branch inst a bhr based on their relative positions to each other
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

    // Figure out next_bhr based on which branch inst was fetched last
    // Do this by camming the branch gnt bus sent at the beginning of the cycle
    always_comb begin
        next_bhr = bhr;
        if (!no_branches_fetched) begin
            for(int j = 0; j < `N; ++j) begin
                if ((branch_gnt_bus[j] == final_branch_gnt_line)) begin
                    next_bhr = (assigned_bhrs[j] << 1) | branches_taken[j];
                end 
            end 
        end
    end

    // Update the PHTs, then assign branches a bp packet
    always_comb begin
        next_gshare_pht = gshare_pht;
        next_simple_pht = simple_pht;
        next_meta_pht = meta_pht;

        if (resolving_valid_branch) begin
            if ((^gshare_pht[bs_bp_packet.gshare_PHT_idx]) || (taken != gshare_pht[bs_bp_packet.gshare_PHT_idx][0])) begin
                next_gshare_pht[bs_bp_packet.gshare_PHT_idx] += (taken) ? 1 : -1;
            end

            if ((^simple_pht[bs_bp_packet.meta_PHT_idx]) || (taken != simple_pht[bs_bp_packet.meta_PHT_idx][0])) begin
                next_simple_pht[bs_bp_packet.meta_PHT_idx] += (taken) ? 1 : -1;
            end

            if ((^meta_pht[bs_bp_packet.meta_PHT_idx]) || (taken != meta_pht[bs_bp_packet.meta_PHT_idx][0])) begin
                next_meta_pht[bs_bp_packet.meta_PHT_idx] += (taken == bs_bp_packet.gshare_predict_taken) - (taken == bs_bp_packet.simple_predict_taken);
            end 
        end 

        bp_packets = '0;
        for (int i = 0; i < `N; ++i) begin  
            bp_packets[i].gshare_predict_taken = next_gshare_pht[assigned_bhrs[i] ^ PCs_out[i][`HISTORY_BITS-1:0]][1];
            bp_packets[i].simple_predict_taken = next_simple_pht[PCs_out[i][`HISTORY_BITS-1:0]][1];
            bp_packets[i].meta_PHT_idx = PCs_out[i][`HISTORY_BITS-1:0];
            bp_packets[i].gshare_PHT_idx = PCs_out[i][`HISTORY_BITS-1:0] ^ assigned_bhrs[i];
            bp_packets[i].BHR_state = assigned_bhrs[i];
            branches_taken[i] = btb_hit[i] && next_meta_pht[PCs_out[i][`HISTORY_BITS-1:0]][1] ? bp_packets[i].gshare_predict_taken : bp_packets[i].simple_predict_taken;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            bhr <= '0;
            meta_pht <= '0;
            gshare_pht <= '0;
            simple_pht <= '0;
        end else begin
            bhr <= (resolving_valid_branch && mispred) ? ((bs_bp_packet.BHR_state << 1) | taken) : next_bhr; 
            meta_pht <= next_meta_pht;
            gshare_pht <= next_gshare_pht;
            simple_pht <= next_simple_pht;
        end
    end


endmodule