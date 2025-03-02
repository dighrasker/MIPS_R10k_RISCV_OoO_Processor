`include "sys_defs.svh"

module Dispatch #(
    
) (
    input   logic                               clock,
    input   logic                               reset,

    // ------------ FROM INSTRUCTION BUFFER ------------- //
    input   logic                               instruction_packets,
    input   logic                               instructions_valid,

    // ------------ TO/FROM BRANCH STACK ------------- //
    input   PHYS_REG_IDX    [`ARCH_REG_SZ_R10K] map_table_restore,
    input   logic                               restore_valid,
    input   B_MASK                              b_mask_reg,
    output  BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack_entries,
    output  B_MASK                              branch_stack_entries_valid,

    // ------------ TO/FROM ROB ------------- //
    input   logic            [`ROB_SZ_BITS-1:0] rob_tail,
    input   logic        [`NUM_SCALAR_BITS-1:0] rob_spots,
    output  ROB_ENTRY_PACKET           [`N-1:0] rob_entries,

    // ------------ TO/FROM RS ------------- //
    output  RS_PACKET                  [`N-1:0] rs_entries,
    input   logic                [`RS_BITS-1:0] rs_entries_available,

    // ------------ TO/FROM FREE LIST ------------- //
    input   logic        [`NUM_SCALAR_BITS-1:0] num_regs_available,
    input   PHYS_REG_IDX               [`N-1:0] regs_to_use,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] free_list_copy,
    
    // ------------ FROM ISSUE? ------------- //
    output   logic       [`NUM_SCALAR_BITS-1:0] num_issuing,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output   logic       [`NUM_SCALAR_BITS-1:0] num_dispatched
);

    //Should have a decoder module inside here or maybe we decode in Fetch?

    PHYS_REG_IDX [`ARCH_REG_SZ_R10K] map_table_copy, next_map_table;

    always_comb begin
        next_map_table = map_table;
        generate

            for (genvar i; i < `N; ++i) begin
                if(i < inst_valid) begin
                    // Create rob/rs/branch-stack entries. probably will change this code
                    source1_phys_reg[i] = next_map_table[source1_arch_reg[i]];
                    source2_phys_reg[i] = next_map_table[source2_arch_reg[i]];
                    // create the branch checkpoint

                    next_map_table[dest_reg[i]] = free_regs[i];
                end
            end
        endgenerate
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