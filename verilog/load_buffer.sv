`include "verilog/sys_defs.svh"

module load_buffer(
    input   logic                                 clock, 
    input   logic                                 reset,

    // ------------ TO/FROM LOAD_FU ------------- //
    input   LOAD_BUFFER_PACKET                    load_buffer_packet,        // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    output  logic                                 load_buffer_backpressure,

    // ------------- TO/FROM CACHE -------------- //
    input   logic                                 mshr_valid,
    input   MSHR_IDX                              mshr_idx,
    input   DATA                            [1:0] mshr_data,    // Cachelines are doubles

    // ------------- TO/FROM ISSUE -------------- //
    input  logic            [`LOAD_BUFFER_SZ-1:0] load_cdb_en,
    output logic            [`LOAD_BUFFER_SZ-1:0] load_cdb_req,

    // ------------ TO CDB ------------- //
    output CDB_REG_PACKET   [`LOAD_BUFFER_SZ-1:0] load_result
); 


    assign load_buffer_backpressure = &final_;
    // Main ROB Data Here

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

        load <= final;
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