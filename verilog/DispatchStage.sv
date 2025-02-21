module DispatchLogic #(
    
) (
    input   logic     [$clog2(`N+1)-1:0] regs_available;
    input   logic        [`ROB_BITS-1:0] rob_entries_available;
    input   logic         [`RS_BITS-1:0] rs_entries_available;
    input   PHYS_REG_IDX        [`N-1:0] regs_to_use;
    output  logic     [$clog2(`N+1)-1:0] num_dispatched;
    output  ROB_ENTRY_PACKET    [`N-1:0] rob_entries,
    output  RS_ENTRY_PACKET     [`N-1:0] rs_entries
    //Need some output to send to Map table to cam for new mappings
    //based on dest regs of dispatched instructions.
);
    //Dispatch should probably handle the majority of the logic for checking structural hazards and selecting a well
    //ordered set of instructions to send to the ROB/RS
    //^^maybe not??
    //Should have a decoder module inside here or maybe we decode in Fetch?

    always_comb begin

    end

    //No sequential elements since this is a combinational stage

endmodule