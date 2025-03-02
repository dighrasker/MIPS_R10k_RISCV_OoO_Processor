`include "sys_defs.svh"

module retire (
    
    // ------------- TO/FROM ROB -------------- //
    input  ROB_EXIT_PACKET      [`N-1:0] rob_outputs,                   // Coming from rob, to retrieve T_old from the packet, so that it can be retired
    input  logic  [`NUM_SCALAR_BITS-1:0] rob_outputs_valid,             // Coming from rob, to check which output is valid, only valid rob outputs can be retired
    output logic  [`NUM_SCALAR_BITS-1:0] num_retiring,                  // Send to rob, how many rob_outputs can be retired

    // ------------- TO/FROM FREDDYLIST -------------- //
    input        [`PHYS_REG_SZ_R10K-1:0] complete_list_exposed,         // Coming from freddylist, to find out which rob_output is actually completed and ready to retire
    output PHYS_REG_IDX         [`N-1:0] phys_regs_retiring             // Send to freddylist, which physical registers are being retired
);

endmodule