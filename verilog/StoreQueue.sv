`include "verilog/sys_defs.svh"

module sq #(
) (
    // ------------ TO/FROM DISPATCH ------------- //
    input   SQ_PACKET            [`N-1:0] sq_inputs,
    input   logic  [`NUM_SCALAR_BITS-1:0] sq_inputs_valid,
    output  logic  [`NUM_SCALAR_BITS-1:0] sq_spots,
    output  logic       [`SQ_SZ_BITS-1:0] sq_tail, //how big is the store queue

    // ------------- FROM Store Unit -------------- // 
    input SQ_PACKET                       store_addr,

    
    // ------------- TO/FROM Load Unit -------------- //
    input ADDR                            ldAddr_from_lu,
    output DATA                           strVal_to_lu,
    output logic                          load_back_pressure,

    // ------------- TO/FROM D Cache-------------- //
    /*not sure how memory access is going to work yet*/

    // ------------- TO/FROM Retire -------------- //
    input logic    [`NUM_SCALAR_BITS-1:0] stores_retiring
    
); 

/*
    Stores:
    1. Allocate space for store instructions on dispatch. At this point we will know their phys_reg_idx and set valid bit to high
    2. Store unit will send a sq_entry_packet to SQ, we will cam from head to tail and update addr and value for any matching phys_regs

    Loads:
    1. load unit will send a load_addr to SQ
    2. We will use aging logic to find the youngest older store instruction that has a matching address
    3. if there is a match? forward value to Load unit : send back pressure signal to retrieve value from cache





*/

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