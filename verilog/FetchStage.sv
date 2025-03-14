// Simple FIFO with parametrizable depth and width

module Fetch #() (
    
    /*
        input           if_valid,       // only go to next PC when true
        input           take_branch,    // taken-branch signal
        input ADDR      branch_target,  // target pc: use if take_branch is TRUE
        input MEM_BLOCK Imem_data,      // data coming back from Instruction memory

        // tags from memory
        input MEM_TAG   Imem2proc_transaction_tag, // Should be zero unless there is a response
        input MEM_TAG   Imem2proc_data_tag,

        output MEM_COMMAND  Imem_command, // Command sent to memory
        output IF_ID_PACKET if_packet,
        output ADDR         Imem_addr // address sent to Instruction memory
    */
    input   logic                        clock, 
    input   logic                        reset,

    // ------------ TO/FROM MEMORY ------------- //
    input   INST                 [`N-1:0] inst,    // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    output  ADDR                 [`N-1:0] PC_reg, 
    
    // ------------- FROM BRANCH STACK -------------- //
    input   ADDR                          recovery_PC,  // Retire module tells the ROB how many entries can be cleared
    
    // ------------ FROM EXECUTE ------------- //
    input   ADDR                          target_PC,
    input   logic                         mispredict,
    input   logic                         taken,            //original prediction was taken

    // ------------ TO/FROM FETCH BUFFER -------- //
    input   logic  [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,     //number of spots in instruction buffer
    output  FETCH_PACKET         [`N-1:0] inst_buffer_inputs,   //instructions going to instruction buffer
    output  logic  [`NUM_SCALAR_BITS-1:0] instructions_valid, //number of valid instructions fetch sends to instruction buffer 

);

    ADDR Next_PC_reg;
    
    always_comb begin
        inst_buffer_inputs = '0;
        Next_PC_reg = PC_reg;
        for (int i = 0; i < `N; ++i) begin
            if (i < inst_spots) begin
                inst_buffer_inputs[i].inst = inst[i]
                inst_buffer_inputs[i].PC = Next_PC_reg;
                Next_PC_reg = Next_PC_reg + 4; 
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            PC_reg <= 0;
            tail <= 0;
            head <= 0;             // initial PC value is 0 (the memory address where our program starts)
        end else begin
            PC_reg <= Next_PC_reg;
            tail <= next_tail;
            head <= next_head;
        end
    end

    /*
    always_comb begin
        Next_PC_reg = PC_reg;
        for (int i = 0; i < `N; ++i) begin
            if (take_branch) begin
                PC_reg <= branch_target; // update to a taken branch (does not depend on valid bit)
            end else begin
                Next_PC_reg = Next_PC_reg + 4; 
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            PC_reg <= 0;             // initial PC value is 0 (the memory address where our program starts)
        end else if (mispredict) begin
            PC_reg <= taken ? target_PC : recovery_PC;    // or transition to next PC if valid
        end else if (take_branch) begin
            PC_reg <= branch_target; // update to a taken branch (does not depend on valid bit)
        end else begin
            PC_reg <= Next_PC_reg;
        end
    end
    */
  


endmodule
