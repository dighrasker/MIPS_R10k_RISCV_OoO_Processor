`include "verilog/sys_defs.svh"

module BranchStack #(
) (
    input   logic                                clock, 
    input   logic                                reset,
    // ------------- FROM EXECUTE -------------- //
    input   B_MASK_MASK                          b_mm_resolve,
    input   logic                                b_mm_mispred,
    // ------------- TO ROB ------------------- //
    output  logic             [`ROB_SZ_BITS-1:0] rob_tail_restore,
    // ------------- TO FREDDY LIST ----------- //
    output  logic        [`PHYS_REG_SZ_R10K-1:0] freelist_restore,
    output  logic                                restore_valid,
    // ------------- TO/FROM DISPATCH -------------- //
    input   BS_ENTRY_PACKET  [`B_MASK_WIDTH-1:0] branch_stack_entries,
    output  PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table_restore,
    output  B_MASK                               b_mask_reg,
    output  logic                                branch_stack_spots,
    // ------------- TO LSQ ------------------ //
    output logic                                 lsq_tail_restore  //<--- STILL NEED TO UPDATE THIS
); 

    always_comb begin

    end

    always_ff @(posedge clock) begin
        if (reset) begin

        end else begin

        end
    end

endmodule