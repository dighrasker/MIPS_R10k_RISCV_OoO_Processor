`include "verilog/sys_defs.svh"

module sq #(
) (
    /*input   logic                        clock, 
    input   logic                        reset,

    // ------------ TO/FROM DISPATCH ------------- //
    input   SQ_PACKET           [`N-1:0] sq_inputs,        
    input   logic  [`NUM_SCALAR_BITS-1:0] sq_inputs_valid,  
    output  logic  [`NUM_SCALAR_BITS-1:0] sq_spots,        
    output  logic      [`ROB_SZ_BITS-1:0] sq_tail, //how many spots will be in the store queue

    // ------------- TO/FROM Load Unit -------------- //
    input   logic  [`NUM_SCALAR_BITS-1:0] load_inst_addr,   //what the hell is an address?   
    output  ROB_PACKET           [`N-1:0] sq_value,         //what the hell is a value?
    output  logic                         sq_back_pressure,               //

    // ------------- FROM ISSUE -------------- //
    output logic */

    // ------------ TO/FROM DISPATCH ------------- //
    input   SQ_PACKET           [`N-1:0] sq_inputs,
    input   logic  [`NUM_SCALAR_BITS-1:0] sq_inputs_valid,
    output  logic  [`NUM_SCALAR_BITS-1:0] sq_spots,
    output  logic      [`ROB_SZ_BITS-1:0] sq_tail, //how big is the store queue

    // ------------- FROM RS -------------- //


    // ------------- FROM Store Unit -------------- // 

    // ------------- TO/FROM Reg File -------------- //
        //Question: How many ports does our reg file have
    input DATA              strVal_from_regfile,
    output PHYS_REG_IDX     strVal_reg,

    // ------------- TO/FROM Load Unit -------------- //
    input ADDR              ldAddr_from_lu,
    output DATA             strVal_to_lu,
); 

    // Main ROB Data Here
    ROB_PACKET    [`ROB_SZ-1:0] rob_entries;

    logic          [`ROB_SZ_BITS-1:0] head, next_head;
    logic          [`ROB_SZ_BITS-1:0] next_tail;
    logic [`ROB_NUM_ENTRIES_BITS-1:0] entries, next_entries;

    always_comb begin
        next_head = (head + num_retiring) % `ROB_SZ;
        next_tail = tail_restore_valid ? tail_restore : (rob_tail + rob_inputs_valid) % `ROB_SZ;
        next_entries = entries + rob_inputs_valid - num_retiring;
        rob_spots = (`ROB_SZ - entries < `N) ? `ROB_SZ - entries : `N;
        rob_outputs_valid = (entries < `N) ? entries : `N;
        rob_outputs = '0;
        for (int i = 0; i < `N; ++i) begin
            if (i < rob_outputs_valid) begin
                rob_outputs[i] = rob_entries[(head + i) % `ROB_SZ];
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_entries <= '0;
            head <= 0;
            rob_tail <= 0;
            entries <= 0;
        end else if(tail_restore_valid) begin
            head <= next_head;
            rob_tail <= tail_restore;
            entries <= (tail_restore == next_head) ? `ROB_SZ : (tail_restore - next_head + `ROB_SZ) % `ROB_SZ;
        end else begin
            for (int i = 0; i < `N; ++i) begin
                if (i < rob_inputs_valid) begin
                    rob_entries[(rob_tail + i) % `ROB_SZ] <= rob_inputs[i]; 
                end
            end
            head <= next_head;
            rob_tail <= next_tail;
            entries <= next_entries;
        end
        $display("rob_entries: %d\nrob_head: %d\nrob_tail: %d", entries, head, rob_tail);
    end

// Debug signals
`ifdef DEBUG
    assign rob_debug = {
        rob_inputs:         rob_entries,
        head:               head,
        rob_tail:           rob_tail,
        rob_spots:          rob_spots,
        rob_outputs_valid:  rob_outputs_valid,
        rob_outputs:        rob_outputs,
        rob_num_entries:    entries
    };
`endif

endmodule