`include "sys_defs.svh"

module Dispatch #(
    
) (
    input   logic                               clock,
    input   logic                               reset,

    // ------------ FROM INSTRUCTION BUFFER ------------- //
    input   logic                               instruction_packets,
    input   logic        [`NUM_SCALAR_BITS-1:0] instructions_valid,

    // ------------ TO/FROM BRANCH STACK ------------- //
    input   PHYS_REG_IDX    [`ARCH_REG_SZ_R10K] map_table_restore,
    input   logic                               restore_valid,
    input   B_MASK                              b_mask_combinational,
    output  BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack_entries,
    output  B_MASK                              next_b_mask,
    // output  B_MASK                              branch_stack_entries_valid, might not need

    // ------------ TO/FROM ROB ------------- //
    input   logic            [`ROB_SZ_BITS-1:0] rob_tail,
    input   logic        [`NUM_SCALAR_BITS-1:0] rob_spots,
    output  ROB_ENTRY_PACKET           [`N-1:0] rob_entries,

    // ------------ TO/FROM RS ------------- //
    output  RS_PACKET                  [`N-1:0] rs_entries,
    input   logic                [`RS_BITS-1:0] rs_entries_available,

    // ------------ TO/FROM FREDDY LIST ------------- //
    input   logic        [`NUM_SCALAR_BITS-1:0] num_regs_available,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] next_complete_list,
    input   PHYS_REG_IDX               [`N-1:0] regs_to_use,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] free_list_copy,
    output  logic       [`PHYS_REG_SZ_R10K-1:0] updated_free_list,
    
    // ------------ FROM ISSUE? ------------- //
    input   logic       [`NUM_SCALAR_BITS-1:0] num_issuing,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output   logic       [`NUM_SCALAR_BITS-1:0] num_dispatched
);

    //Should have a decoder module inside here or maybe we decode in Fetch?

    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table, next_map_table;

    //insert decoder module here
    //N Inputs are raw instruction 32 bit data from front of fetch buffer
    //Outputs are fully decoded packets which should go straight into an RS packet
    // TODO: Replace every "decoder_out" when decoder is done
    
    // For BS entry ordering

    
    logic bs_empty;
    logic [`B_MASK_WIDTH-1:0] gnt;
    logic [`B_MASK_ID_BITS-1:0] empty_bs_index;
    logic [`B_MASK_WIDTH-1:0] psel_output; // might be useless

    decoder #(

    ) decoder_inst (
        
    )

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

    assign i_num_dispatched = restore_valid ? 0 : $min(); //if not restoring, num_dispatching = min (rs_entries, rob_entries, free_list)
    
    
    always_comb begin
        branch_stack_entries = '0;
        next_b_mask = b_mask_combinational;
        num_dispatched = 0;
        next_map_table = map_table;
        updated_free_list = free_list_copy;
        for (int i = 0; i < `N; ++i) begin
            if(i < i_num_dispatched) begin
                
                // Create rob/rs/branch-stack entries. probably will change this code
                
                //Create RS Packet
                rs_entries[i].PC = decoder_out[i].PC;
                rs_entries[i].T_new = regs_to_use[i];
                rs_entries[i].Source1 = next_map_table[decoder_out[i].source1_arch_reg];
                rs_entries[i].Source1_ready = next_complete_list[rs_entries[i].Source1];
                rs_entries[i].Source2 = next_map_table[decoder_out[i].source2_arch_reg];
                rs_entries[i].Source2_ready = next_complete_list[rs_entries[i].Source2];
                //Op code??
                rs_entries[i].b_mask = next_b_mask;
                rs_entries[i].b_mask_mask = '0;
                rs_entries[i].FU_type = decoder_out[i].FU_type;

                //Create ROB Packet
                /*
                    PHYS_REG_IDX    T_new; // Use as unique rob id
                    PHYS_REG_IDX    T_old;
                    ARCH_REG_IDX    Arch_reg;
                */
                rob_entries[i].T_new = regs_to_use[i];                          //this should be the output from freddy
                rob_entries[i].Arch_reg = decoder_out[i].dest_arch_reg;         //this should come from instruction dest_reg
                rob_entries[i].T_old = next_map_table[decoder_out[i].dest_arch_reg];      //this should be coming from map table


                // create the branch checkpoint
                if(inst == branch)begin // TODO: need to check 'branch' to an actual flag
                    if(~bs_empty) begin // checking that there is room in the BS
                    //allocate BS entry (snapshotting recovery PC, map table, rob_tail, free_list, b_m)
                    // empty_bs_index -> the index of the empty bs to put in smth
                        updated_free_list[regs_to_use[i]] = 0;
                        next_map_table[decoder_out[i].arch_dest_reg] = regs_to_use[i];

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
                next_map_table[decoder_out[i].arch_dest_reg] = regs_to_use[i];

                num_dispatched = i;

            end
        end
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            map_table <= 0;
        end else begin
            map_table <= next_map_table;
        end
    end

    //No sequential elements since this is a combinational stage

endmodule