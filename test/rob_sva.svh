// SystemVerilog Assertions (SVA) for use with our FIFO module
// This file is included by the testbench to separate our main module checking code
// SVA are relatively new to 470, feel free to use them in the final project if you like

`include "verilog/sys_defs.svh"

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

    logic [$bits(ROB_ENTRY_PACKET)-1:0] index;

    always_ff @(posedge clock) begin
        if (reset) begin
            index <= 0;
        end else begin
            index <= index + num_retiring;
        end
    end

    task exit_on_error;
        begin
            $display("\n\033[31m@@@ Failed at time %4d\033[0m\n", $time);
            $finish;
        end
    endtask
    
    always @(posedge clock) begin

    // Check each valid output
        for (int i = 0; i < outputs_valid; i++) begin
            assert (reset || rob_outputs[i] == (i + index))
                else begin
                    $error("Mismatch on rob_outputs[%0d]: expected %0d, got %0d", 
                        i,    (i + index),      rob_outputs[i]);
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

