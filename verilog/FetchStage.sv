`include "verilog/sys_defs.svh"

module Fetch #() (
    input  logic                        clock, 
    input  logic                        reset,

    // ------------ TO I-CACHE + BP + BTB ------------- //
    output ADDR                    [`N-1:0] PCs, 

    // ------------ TO/FROM I-CACHE ------------- //
    input  INST                    [`N-1:0] cache_data,
    input  logic                   [`N-1:0] cache_miss,
    
    // ------------- FROM BRANCH STACK -------------- //
    input  ADDR                             PC_restore,                      
    input  logic                            restore_valid,
  
    // ------------ TO/FROM INSTRUCTION BUFFER -------- //
    input  logic     [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,     //number of spots in instruction buffer
    output FETCH_PACKET            [`N-1:0] inst_buffer_inputs,   //instructions going to instruction buffer
    output logic     [`NUM_SCALAR_BITS-1:0] instructions_valid //number of valid instructions fetch sends to instruction buffer 

    // ------------ TO/FROM BRANCH PREDICTOR -------- //
    input  BRANCH_PREDICTOR_PACKET [`N-1:0] bp_packets,
    output logic                   [`N-1:0] valid_branch,   
   
   // ------------ FROM BTB -------- //
    input  ADDR                    [`N-1:0] target_PC,       //<-- just set this somewhere?
    input  logic                   [`N-1:0] btb_hit
);

    ADDR Next_PC_reg, PC_reg;

    logic   [`N-1:0] valid_jump;

    logic [`NUM_SCALAR_BITS-1:0] i_num_fetched;

    assign i_num_fetched = restore_valid ? '0: inst_buffer_spots;

    always_comb begin
        instructions_valid = '0;
        inst_buffer_inputs = '0;
        valid_branch = '0;
        valid_jump = '0;
        Next_PC_reg = PC_reg;
        
        //creating array of N PCs that will be sent to ICache
        for (int i = 0; i < `N; ++i) begin
            PCs[i] = PC_reg + (4 * i);
        end
        
        //fetching N instructions from I cache if they are a hit
        for (int i = 0; i < `N; ++i) begin
            //Next_PC_reg = PC_reg + (4 * (i + 1));
            if (i < i_num_fetched) begin 
                if(cache_miss[i]) begin
                    break;
                end
                valid_branch[i] = (cache_data[i].r.opcode == `RV32_BRANCH);

                valid_jump[i] = (cache_data[i].r.opcode == `RV32_JALR_OP) 
                             || (cache_data[i].r.opcode == `RV32_JAL_OP);
                               
                inst_buffer_inputs[i].inst = cache_data[i];
                inst_buffer_inputs[i].PC = PCs[i];
                inst_buffer_inputs[i].taken = btb_hit[i] && (predict_taken[i] || valid_jump[i]); //should put branch predictor prediction here
                
                instructions_valid = i + 1;

                if(btb_hit[i] && valid_branch[i] && predict_taken[i]) begin
                    Next_PC_reg = target_PC[i];
                    break;
                end else begin
                    Next_PC_reg = PCs[i] + 4;
                end
                
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
            PC_reg <= 0;             // initial PC value is 0 (the memory address where our program starts)
        end else if (restore_valid) begin
            PC_reg <= PC_restore;    // or transition to next PC if valid
        end else begin
            PC_reg <= Next_PC_reg;
        end
        for (int i = 0; i < `N; ++i) begin
            $display("PCs[%d]: %h", i, PCs[i]);
        end
    end
endmodule
