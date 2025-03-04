`include "verilog/sys_defs.svh"

module BranchStack_sva #(
) (
    input   logic                                clock, 
    input   logic                                reset,
    // ------------- TO FETCH -------------- //
    output  ADDR                                 PC_restore,
    output  logic                                PC_restore_valid,
    // ------------- FROM COMPLETE -------------- //
    input   B_MASK_MASK                          b_mm_resolve,
    input   logic                                b_mm_mispred,
    // ------------- TO ROB ------------------- //
    output  logic             [`ROB_SZ_BITS-1:0] rob_tail_restore,
    output  logic                                rob_tail_restore_valid,
    // ------------- TO FREDDY LIST ----------- //
    output  logic        [`PHYS_REG_SZ_R10K-1:0] freelist_restore,
    output  logic                                freelist_restore_valid,
    // ------------- TO/FROM DISPATCH -------------- //
    input   BS_ENTRY_PACKET  [`B_MASK_WIDTH-1:0] branch_stack_entries,
    input   logic            [`B_MASK_WIDTH-1:0] next_b_mask,
    output  PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table_restore,     // exit packet: recovery_PC, rob_tail, map_table, freelist
    output  logic                                map_table_restore_valid,
    output  B_MASK                               b_mask_combinational,
    output  logic         [`NUM_B_MASK_BITS-1:0] branch_stack_spots//,
    // ------------- TO LSQ ------------------ //
    // output logic                                 lsq_tail_restore  //<--- STILL NEED TO UPDATE THIS
    // branch prediction repair?
); 

    logic [`B_MASK_WIDTH-1:0] prev_b_mm_resolve;

    task exit_on_error;
        begin
            $display("\n\033[31m@@@ Failed at time %4d\033[0m\n", $time);
            $finish;
        end
    endtask

    always_ff @(posedge clock) begin
        prev_b_mm_resolve <= b_mm_resolve;
    end

    clocking prop @(posedge clock);
        // property that checks if b_mm_resolve bit is set low (resolved) at the b_mask_combinational 
        property resolved_must_be_zero;
            (~reset) |=> ((prev_b_mm_resolve & b_mask_combinational) == 0); // need to consider previous or not previous
        endproperty

        property squashed_must_be_empty;
            (~reset) |=> ((prev_b_mm_resolve ))
        endproperty

        // property that checks if b_mm_resolve squashes dependent branch entries in the branch stack


    endclocking

endmodule