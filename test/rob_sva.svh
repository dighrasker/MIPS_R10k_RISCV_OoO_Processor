// SystemVerilog Assertions (SVA) for use with our FIFO module
// This file is included by the testbench to separate our main module checking code
// SVA are relatively new to 470, feel free to use them in the final project if you like

`ifndef ROB_SVA_SVH
`define ROB_SVA_SVH

module ROB_sva #(
    parameter DEPTH = `ROB_SZ,
    localparam DEPTH_BITS = $clog2(DEPTH),
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1),
    localparam NUM_SCALAR_BITS = $clog2(`N+1)
) (
    input  logic                        clock, 
    input  logic                        reset,
    input  ROB_ENTRY_PACKET    [`N-1:0] rob_inputs, // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    input  logic  [NUM_SCALAR_BITS-1:0] inputs_valid, // To distinguish invalid instructions being passed in from Dispatch
    input  ROB_EXIT_PACKET     [`N-1:0] rob_outputs, // For retire to check eligibility
    input  logic  [NUM_SCALAR_BITS-1:0] outputs_valid, // If not all N rob entries are valid entries they should not be considered
    input  logic  [NUM_SCALAR_BITS-1:0] num_retiring, // Retire module tells the ROB how many entries can be cleared
    input  logic  [NUM_SCALAR_BITS-1:0] spots,
    input  ROB_DEBUG                    rob_debug
);

    int spots_manual;
    assign spots_manual = rob_debug.Head == rob_debug.Tail && rob_debug.Spots == 0 && rob_debug.num_entries != 0
                            ? 0
                            : DEPTH - ((rob_debug.Tail - rob_debug.Head + DEPTH) % DEPTH) > `N 
                                ? `N
                                : DEPTH - ((rob_debug.Tail - rob_debug.Head + DEPTH) % DEPTH);

    int index;

    always_ff @(posedge clock) begin
        if (reset) begin
            index <= 0;
        end else begin
            index <= (index + num_retiring)%DEPTH;
        end
    end

    task exit_on_error;
        begin
            $display("\n\033[31m@@@ Failed at time %4d\033[0m\n", $time);
            $finish;
        end
    endtask

    // clocking cb @(posedge clock);
    //     // rd_valid asserted if and only if rd_en=1 and there is valid data
    //     property rd_valid_correct;
    //         rd_valid_c iff rd_valid;
    //     endproperty

    //     // wr_valid asserted if and only if wr_en=1 and buffer not full
    //     property wr_valid_correct;
    //         wr_valid_c iff wr_valid;
    //     endproperty

    //     // full asserted if and only if buffer is full
    //     property full_correct;
    //         full iff entries == DEPTH;
    //     endproperty

    //     // almost full signal asserted when there are ALERT_DEPTH entries left
    //     property spots_correct;
    //         disable iff (reset)
    //         spots == (entries < (DEPTH-MAX_CNT) ? MAX_CNT : DEPTH - entries);
    //     endproperty

    //     // Check that data written in comes out after proper number of reads
    //     // NOTE: this property isn't used in verification as it runs slowly
    //     //      However, feel free to reference as an example of a more
    //     //      complex assertion
    //     property write_read_correctly;
    //         logic [WIDTH-1:0] data_in;
    //         int               idx;
    //         (wr_valid, data_in=wr_data, idx=(rd_count+entries)) // value is written
    //         ##[1:$] (rd_valid && rd_count == idx) // wait for previous entries to be read
    //         |-> rd_data === data_in;              // ensure correct value out
    //     endproperty

    //     property rd_valid_live;
    //         rd_en |-> s_eventually rd_valid;
    //     endproperty

    //     property wr_valid_live;
    //         wr_en |-> s_eventually wr_valid;
    //     endproperty

    // endclocking

    // Assert properties
    // ValidRd:    assert property(cb.rd_valid_correct)     else exit_on_error;
    // ValidWr:    assert property(cb.wr_valid_correct)     else exit_on_error;
    // ValidFull:  assert property(cb.full_correct)         else exit_on_error;
    // ValidSpots: assert property(cb.spots_correct)        else exit_on_error;

    // // Liveness checks
    // RdValidLiveness: assert property(cb.rd_valid_live)   else exit_on_error;
    // WrValidLiveness: assert property(cb.wr_valid_live)   else exit_on_error;

    // // This assertion is large and slow for formal verification, 
    // // but it works for a testbench
    // DataOutErr: assert property(cb.write_read_correctly) else exit_on_error;

    // genvar i;
    // generate 
    //     for (i = 0; i < WIDTH; i++) begin
    //         cov_bit_i:  cover property(@(posedge clock) wr_data[i]);
    //     end
    // endgenerate

    // genvar i;
    // generate
    //     for (i = 0; i < outputs_valid; ++i) begin
    //         assert (rob_outputs[i].T_new == (i + index)%DEPTH) else exit_on_error;
    //     end
    // endgenerate

    // assert (rob_debug.Spots == spots_manual) else exit_on_error;
    // assert (num_valid <= (spots + num_retiring)) else exit_on_error;
    // assert (num_retiring <= num_entries) else exit_on_error;
    
    always @(negedge clock) begin
    // Check each valid output
        for (int i = 0; i < outputs_valid; i++) begin
            assert (reset || rob_outputs[i].T_new == (i + index) % DEPTH)
                else begin
                    $error("Mismatch on rob_outputs[%0d]: expected %0d, got %0d", 
                            i, (i + index) % DEPTH, rob_outputs[i].T_new);
                    $finish;
                end
        end

        // Check overall conditions
        assert (reset || rob_debug.Spots == spots_manual)
            else begin
                $error("rob_debug.Spots (%0d) does not equal spots_manual (%0d)", 
                        rob_debug.Spots, spots_manual);
                $finish;
            end
        
        assert (reset || {1'b0, inputs_valid} <= ({1'b0, spots} + {1'b0, num_retiring}))
            else begin
                $error("inputs_valid (%0d) exceeds spots + num_retiring (%0d)", 
                        inputs_valid, spots + num_retiring);
                $finish;
            end

        assert (reset || num_retiring <= rob_debug.num_entries)
            else begin
                $error("num_retiring (%0d) exceeds num_entries (%0d)", 
                        num_retiring, rob_debug.num_entries);
                $finish;
            end
    end

endmodule

`endif // FIFO_SVA_SVH
