`include "verilog/sys_defs.svh"

module Fetch #() (
    input   logic                        clock, 
    input   logic                        reset,

    // ------------ TO/FROM MEMORY ------------- //
    input   INST                 [`N-1:0] inst,    // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    output  ADDR                 [`N-1:0] PC_reg, 
    
    // ------------- FROM BRANCH STACK -------------- //
    input   ADDR                          PC_restore,  // Retire module tells the ROB how many entries can be cleared                        
    input   logic                         restore_valid,
       

    // ------------ TO/FROM FETCH BUFFER -------- //
    input   logic  [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,     //number of spots in instruction buffer
    output  FETCH_PACKET         [`N-1:0] inst_buffer_inputs,   //instructions going to instruction buffer
    output  logic  [`NUM_SCALAR_BITS-1:0] instructions_valid //number of valid instructions fetch sends to instruction buffer 

);

    ADDR Next_PC_reg;
    ADDR curr_PC_reg;

    assign instructions_valid = inst_buffer_spots;
    
    always_comb begin
        inst_buffer_inputs = '0;
        Next_PC_reg = curr_PC_reg;
        for (int i = 0; i < `N; ++i) begin
            PC_reg[i] = Next_PC_reg;
            if (i < inst_buffer_spots) begin
                inst_buffer_inputs[i].inst = inst[i];
                inst_buffer_inputs[i].PC = Next_PC_reg;
                inst_buffer_inputs[i].taken = 0;
                Next_PC_reg = curr_PC_reg + (4 * (i + 1)); 
                
                // $display(
                //     "inst_buffer_inputs[%d].inst : %b\ninst_buffer_inputs[%d].PC : %b\ninst_buffer_inputs[%d].taken : %b\ninstructions_valid: %b\n", 
                //     i, inst_buffer_inputs[i].inst, 
                //     i, inst_buffer_inputs[i].PC, 
                //     i, inst_buffer_inputs[i].taken,
                //     instructions_valid
                // );
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            curr_PC_reg <= 0;             // initial PC value is 0 (the memory address where our program starts)
        end else if (restore_valid) begin
            curr_PC_reg <= PC_restore;    // or transition to next PC if valid
        end else begin
            curr_PC_reg <= Next_PC_reg;
        end
        for (int i = 0; i < `N; ++i) begin
            $display("PC_reg[%d]: %h", i, PC_reg[i]);
        end
    end
endmodule
