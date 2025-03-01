module Dispatch #(
    
) (
    input   logic                        clock,
    input   logic                        reset,

    // ------------ FROM INSTRUCTION BUFFER ------------- //
    input   logic                            instruction_packets,
    input   logic                            instructions_valid,

    // ------------ TO/FROM BRANCH STACK ------------- //
    input   PHYS_REG_IDX [`ARCH_REG_SZ_R10K] map_table_restore,
    input   logic                            restore_valid,

    // ------------ TO/FROM ROB ------------- //
    input   logic       [DEPTH_BITS-1:0] rob_tail,

    input   logic     [$clog2(`N+1)-1:0] regs_available,
    input   logic        [`ROB_BITS-1:0] rob_entries_available,
    input   logic         [`RS_BITS-1:0] rs_entries_available,
    input   PHYS_REG_IDX        [`N-1:0] regs_to_use,
    output  ROB_ENTRY_PACKET    [`N-1:0] rob_entries,
    output  RS_ENTRY_PACKET     [`N-1:0] rs_entries
    //Need some output to send to Map table to cam for new mappings
    //based on dest regs of dispatched instructions.
);
    //Dispatch should probably handle the majority of the logic for checking structural hazards and selecting a well
    //ordered set of instructions to send to the ROB/RS
    //^^maybe not??
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