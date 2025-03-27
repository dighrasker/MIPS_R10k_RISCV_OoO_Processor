`include "verilog/sys_defs.svh"

module Fetch #() (
    input  logic                        clock, 
    input  logic                        reset,

    // ------------ TO I-CACHE + BP + BTB ------------- //
    output ADDR                    [`N-1:0] PCs_out, // TODO THIS SHIT AINT THE CORRECT SIZE

    // ------------ TO/FROM I-CACHE ------------- //
    input  INST                    [`N-1:0] cache_data,
    input  logic                   [`N-1:0] cache_miss,
    
    // ------------- FROM BRANCH STACK -------------- //
    input  ADDR                             PC_restore,                      
    input  logic                            restore_valid,
  
    // ------------ TO/FROM INSTRUCTION BUFFER -------- //
    input  logic     [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,     //number of spots in instruction buffer
    output FETCH_PACKET            [`N-1:0] inst_buffer_inputs,   //instructions going to instruction buffer
    output logic     [`NUM_SCALAR_BITS-1:0] inst_valid    //number of valid instructions fetch sends to instruction buffer 

    // ------------ TO/FROM BRANCH PREDICTOR -------- //
    input  BRANCH_PREDICTOR_PACKET [`N-1:0] bp_packets,
    input  logic                   [`N-1:0] branches_taken,
    output logic [`N-1:0]          [`N-1:0] branch_gnt_bus,
    output logic                   [`N-1:0] final_branch_gnt_line,
    output logic                            no_branches_fetched,
   
   // ------------ FROM BTB -------- //
    input  ADDR                    [`N-1:0] target_PC,       //<-- just set this somewhere?
    input  logic                   [`N-1:0] btb_hit
);

    ADDR   [`N:0] PCs;
    ADDR Next_PC_reg, PC_reg;
    logic [`N-1:0] valid_jump;

    logic [`N-1:0] valid_branch, masked_valid_branch;
    logic [`N-1:0] branches_taken;

    logic [`NUM_SCALAR_BITS-1:0] final_valid_inst_idx;

    psel_gen #(
        .WIDTH(`N),
        .REQS(`N)
    ) branch_inst_psel (
        .req(valid_branch),
        .gnt_bus(branch_gnt_bus),
    );

    psel_gen #(
        .WIDTH(`N),
        .REQS(`1)
    ) right_most_inst_psel (
        .req(cache_miss | branches_taken << 1),
        .gnt(right_most_inst),
    );

    psel_gen #(
        .WIDTH(`N),
        .REQS(`1)
    ) final_branch_inst_psel (
        .req(masked_valid_branch),
        .gnt(final_branch_gnt_line),
        .empty(no_branches_fetched)
    );

    encoder #(`N, `NUM_SCALAR_BITS) final_inst_encoder (right_most_inst, right_most_inst_idx);

    assign inst_valid_temp = (no_branches_fetched) ? right_most_inst_idx : `N;
    assign inst_valid = (inst_valid_temp <= inst_buffer_spots) ? inst_valid_temp : inst_buffer_spots;
    assign PCs_out = PCs[`N-1:0];
    assign PCs[0] = PC_reg;

    always_comb begin
        masked_valid_branch = '0;
        for (int i = 0; i < `N; ++i) begin
            if (i < inst_valid && valid_branch[i]) begin
                masked_valid_branch[i] = 1'b1;
            end
        end
    end

    always_comb begin
        inst_valid = '0;
        inst_buffer_inputs = '0;
        valid_branch = '0;
        valid_jump = '0;
        Next_PC_reg = PC_reg;
        
        //creating array of N PCs that will be sent to ICache
        for (int i = 0; i <= `N; ++i) begin
            PCs[i] = PC_reg + (4 * i);
        end
        
        //fetching N instructions from I cache if they are a hit
        for (int i = 0; i < `N; ++i) begin
            valid_branch[i] = (cache_data[i].r.opcode == `RV32_BRANCH);

            valid_jump[i] = (cache_data[i].r.opcode == `RV32_JALR_OP) 
                            || (cache_data[i].r.opcode == `RV32_JAL_OP);
                            
            inst_buffer_inputs[i].inst = cache_data[i];
            inst_buffer_inputs[i].PC = PCs[i];
            inst_buffer_inputs[i].taken = btb_hit[i] && ((valid_branch[i] && predict_taken[i]) || valid_jump[i]); //should put branch predictor prediction here
            inst_buffer_inputs[i].bp_packet = bp_packets[i];
            inst_buffer_inputs[i].predicted_PC = btb_hit[i] ? target_PC[i] : PCs[i + 1];
            inst_buffer_inputs[i].is_jump = valid_jump[i];
        end

        if(inst_valid && branches_taken[inst_valid - 1]) begin
            Next_PC_reg = target_PC[inst_valid - 1];
        end else begin
            Next_PC_reg = PCs[inst_valid];
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
        // $display(
        //     "inst_buffer_inputs[%d].inst : %b\ninst_buffer_inputs[%d].PC : %b\ninst_buffer_inputs[%d].taken : %b\inst_valid: %b\n", 
        //     i, inst_buffer_inputs[i].inst, 
        //     i, inst_buffer_inputs[i].PC, 
        //     i, inst_buffer_inputs[i].taken,
        //     inst_valid
        // );
    end
endmodule
