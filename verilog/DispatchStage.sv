`include "sys_defs.svh"

module Dispatch (
    input   logic                               clock,
    input   logic                               reset,

    // ------------ FROM INST BUFFER ------------- //
    input   logic        [`NUM_SCALAR_BITS-1:0] inst_buffer_instructions_valid,

    // ------------ FROM DECODER ------------- //
    input   DECODE_PACKET              [`N-1:0] decoder_out,
    input   logic                      [`N-1:0] is_rs1_used,
    input   logic                      [`N-1:0] is_rs2_used,
    input   ARCH_REG_IDX               [`N-1:0] source1_arch_reg,
    input   ARCH_REG_IDX               [`N-1:0] source2_arch_reg,
    input   ARCH_REG_IDX               [`N-1:0] dest_arch_reg,

    // ------------ TO/FROM BRANCH STACK ------------- //
    input   PHYS_REG_IDX    [`ARCH_REG_SZ_R10K] map_table_restore,
    input   logic                               restore_valid,
    input   B_MASK                              b_mask_combinational,
    output  BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack_entries,
    output  B_MASK                              next_b_mask,

    // ------------ TO/FROM ROB ------------- //
    input   logic            [`ROB_SZ_BITS-1:0] rob_tail,
    input   logic        [`NUM_SCALAR_BITS-1:0] rob_spots,
    output  ROB_PACKET                 [`N-1:0] rob_entries,

    // ------------ TO/FROM RS ------------- // 
    input   logic        [`NUM_SCALAR_BITS-1:0] rs_spots,
    output  RS_PACKET                  [`N-1:0] rs_entries,

    // ------------ TO/FROM FREDDY LIST ------------- //
    //input   logic        [`NUM_SCALAR_BITS-1:0] num_regs_available,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] next_complete_list,
    input   PHYS_REG_IDX               [`N-1:0] regs_to_use,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] free_list_copy,
    output  logic       [`PHYS_REG_SZ_R10K-1:0] updated_free_list,
    
    // ------------ FROM ISSUE? ------------- //
    //input   logic        [`NUM_SCALAR_BITS-1:0] num_issuing,

    // ------------ FROM EXECUTE ------------- //
    input   PHYS_REG_IDX               [`N-1:0] ETB_tags,
    input   logic                      [`N-1:0] ETB_tags_valid,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output   logic       [`NUM_SCALAR_BITS-1:0] num_dispatched
    `ifdef DEBUG
        , output DISPATCH_DEBUG                 dispatch_debug
    `endif
);

    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table, next_map_table;

    // For BS entry ordering
    logic bs_empty;
    logic [`B_MASK_WIDTH-1:0] gnt;
    logic [`B_MASK_ID_BITS-1:0] empty_bs_index;
    logic [`B_MASK_WIDTH-1:0] psel_output; // might be useless

    psel_gen #(
         .WIDTH(`B_MASK_WIDTH),  // The width of the request bus
         .REQS(1) // The number of requests that can be simultaenously granted
    ) psel_inst (
         .req(~next_b_mask), // Input request bus
         .gnt(gnt),          // Output with all granted requests on a bus
         .gnt_bus(psel_output),  // Output bus for each request
         .empty(bs_empty)       // Output asserted when there are no requests
    );

    encoder #(
        .INPUT_LENGTH(`B_MASK_WIDTH),
        .OUTPUT_LENGTH(`B_MASK_ID_BITS)
    ) encoder_inst (
        .in(gnt),
        .out(empty_bs_index)
    );

    logic [`NUM_SCALAR_BITS-1:0] i_num_dispatched;

    logic [`NUM_SCALAR_BITS-1:0] min;           // min (rs_spots +num_issuing, rob_spots, instruction valid)

    assign min = (((rs_spots) <= rob_spots) && ((rs_spots) <= inst_buffer_instructions_valid)) ? (rs_spots) :
                                ((rob_spots <= (rs_spots)) && (rob_spots <= inst_buffer_instructions_valid)) ? rob_spots : inst_buffer_instructions_valid;


    assign i_num_dispatched = restore_valid ? 0 : min; //if not restoring, num_dispatching = min (rs_entries, rob_entries, free_list)

    always_comb begin
        branch_stack_entries = '0;
        next_b_mask = b_mask_combinational;
        num_dispatched = 0;
        next_map_table = map_table;
        updated_free_list = free_list_copy;
        for (int i = 0; i < `N; ++i) begin
            if(i < i_num_dispatched) begin
                // Create rob/rs/branch-stack entries
                
                
                //Create RS Packet
                rs_entries[i].decoder_out = decoder_out[i];
                rs_entries[i].T_new = regs_to_use[i];
                rs_entries[i].Source1 = next_map_table[source1_arch_reg[i]];
                if (!is_rs1_used[i]) begin
                    rs_entries[i].Source1_ready = 1'b1; 
                end else if (next_complete_list[rs_entries[i].Source1]) begin
                    rs_entries[i].Source1_ready = 1'b1; 
                end else begin
                    rs_entries[i].Source1_ready = 1'b0;
                    for(int j = 0; j < `N; j++) begin
                        if(rs_entries[i].Source1 == ETB_tags[j] && ETB_tags_valid[j])begin
                            rs_entries[i].Source1_ready = 1'b1;
                        end
                    end
                end
                rs_entries[i].Source2 = next_map_table[source2_arch_reg[i]];
                if (!is_rs2_used[i]) begin
                    rs_entries[i].Source2_ready = 1'b1; 
                end else if (next_complete_list[rs_entries[i].Source2]) begin
                    rs_entries[i].Source2_ready = 1'b1; 
                end else begin
                    rs_entries[i].Source2_ready = 1'b0;
                    for(int j = 0; j < `N; j++) begin
                        if(rs_entries[i].Source2 == ETB_tags[j] && ETB_tags_valid[j])begin
                            rs_entries[i].Source2_ready = 1'b1;
                        end
                    end
                end
                rs_entries[i].b_mask = next_b_mask;
                rs_entries[i].b_mask_mask = '0;

                //Create ROB Packet
                /*
                    PHYS_REG_IDX    T_new; // Use as unique rob id
                    PHYS_REG_IDX    T_old;
                    ARCH_REG_IDX    Arch_reg;
                */
                rob_entries[i].T_new = regs_to_use[i];                          //this should be the output from freddy
                rob_entries[i].halt = decoder_out[i].halt;
                rob_entries[i].Arch_reg = dest_arch_reg[i];         //this should come from instruction dest_reg
                rob_entries[i].T_old = decoder_out[i].has_dest ? next_map_table[dest_arch_reg[i]] : rob_entries[i].T_new;      //this should be coming from map table
                rob_entries[i].illegal = decoder_out[i].illegal;
                rob_entries[i].NPC = decoder_out[i].NPC;

                // create the branch checkpoint
                if(decoder_out[i].cond_branch || decoder_out[i].uncond_branch) begin // TODO: need to check 'branch' to an actual flag
                    if(~bs_empty) begin // checking that there is room in the BS
                    //allocate BS entry (snapshotting recovery PC, map table, rob_tail, free_list, b_m)
                    // empty_bs_index -> the index of the empty bs to put in smth
                        updated_free_list[regs_to_use[i]] = 0;
                        next_map_table[dest_arch_reg[i]] = decoder_out[i].has_dest ? regs_to_use[i] : next_map_table[dest_arch_reg[i]];

                        branch_stack_entries[empty_bs_index].recovery_PC = decoder_out[i].PC; // TODO: change to instruction PC
                        branch_stack_entries[empty_bs_index].rob_tail = (rob_tail + i) % `ROB_SZ;
                        branch_stack_entries[empty_bs_index].free_list = updated_free_list;
                        branch_stack_entries[empty_bs_index].map_table = next_map_table;
                        branch_stack_entries[empty_bs_index].b_m = next_b_mask;

                        rs_entries[i].b_mask_mask = psel_output;
                        
                        next_b_mask[empty_bs_index] = 1'b1;
                    end else begin
                        break;
                    end
                end
                
                updated_free_list[regs_to_use[i]] = 0;
                next_map_table[dest_arch_reg[i]] = decoder_out[i].has_dest ? regs_to_use[i] : next_map_table[dest_arch_reg[i]];

                num_dispatched = i + 1;
            end
        end
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i = 0; i < `ARCH_REG_SZ_R10K; ++i) begin
                map_table[i] <= i[`ARCH_REG_ID_BITS-1:0];
            end
        end else begin
            map_table <= next_map_table;
        end
    end

    `ifdef DEBUG
        assign dispatch_debug = {
            map_table:      map_table,
            next_map_table: next_map_table,
            fu_type:        fu_type
        };
    `endif

endmodule