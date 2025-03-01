`include "verilog/sys_defs.svh"

module rob #(
    parameter DEPTH = `ROB_SZ,
    localparam DEPTH_BITS = $clog2(DEPTH),
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1)
) (
    input   logic                        clock, 
    input   logic                        reset,
    // ------------- FROM EXECUTE -------------- //
    input logic [`B_MASK_WIDTH-1:0] b_mm_resolve,
    input logic b_mm_mispred,
    // ------------- TO ROB ------------------- //
    output logic [DEPTH_BITS-1:0] rob_tail_restore,
    // ------------- TO FREDDY LIST ----------- //
    output logic [LENGTH-1:0]freelist_restore,
    output logic restore_valid,
    // ------------- TO/FROM DISPATCH -------------- //
    input logic branch_stack_entries,
    output PHYS_REG_IDX [`ARCH_REG_SZ_R10K] map_table_restore,
    output logic [`B_MASK_WIDTH-1:0] b_mask_reg,
    output logic branch_stack_spots,
    // ------------- TO LSQ ------------------ //
    output lsq_tail_restore
); 

    always_comb begin

    end

    always_ff @(posedge clock) begin
        if (reset) begin

        end else begin

        end
    end

endmodule