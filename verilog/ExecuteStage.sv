module ExecuteStage (
    input   logic                               clock,
    input   logic                               reset,

    // --------------- TO/FROM ISSUE REGISTER --------------- //
    input MULT_PACKET         [`NUM_FU_MULT-1:0] next_mult_packets_issuing, 
    input ALU_PACKET           [`NUM_FU_ALU-1:0] next_alu_packets_issuing,
    input BRANCH_PACKET     [`NUM_FU_BRANCH-1:0] next_branch_packets_issuing,

    output logic              [`NUM_FU_MULT-1:0] mult_free,
    output logic              [`NUM_FU_LDST-1:0] ldst_free,

    output logic [`N-1:0]    [`NUM_FU_TOTAL-1:0] complete_gnt_bus,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output CDB_ETB_PACKET                   [`N-1:0] cdb_completing,
    output CDB_REG_PACKET                   [`N-1:0] cdb_reg,

    // --------------- TO/FROM FETCH --------------- //
    output ADDR                                 target_pc,
    output logic                                mispredict,
    output logic                                taken //where are we keeping taken?
    // we need to have the original taken prediction somewhere, branch stack maybe?

);

    MULT_PACKET   mult_packets_issuing;
    ALU_PACKET    alu_packets_issuing;
    BRANCH_PACKET branch_packets_issuing;

    logic [`NUM_FU_MULT-1:0] mult_cdb_valid;
    logic [`NUM_FU_LDST-1:0] ldst_cdb_valid;

    logic [`NUM_FU_MULT-1:0] mult_cdb_en;
    logic [`NUM_FU_LDST-1:0] ldst_cdb_en;

    logic [`NUM_FU_MULT-1:0] mult_fu_free;
    logic [`NUM_FU_LDST-1:0] ldst_fu_free;

    always_ff @(posedge clock) begin
        for (int i = 0; i < `NUM_FU_MULT; ++i) begin
            if (mult_free[i] == 1'b1) begin
                mult_packets_issuing[i] = next_mult_packets_issuing[i];
            end
        end

        for (int i = 0; i < `NUM_FU_ALU; ++i) begin
            if (alu_free[i] == 1'b1) begin
                alu_packets_issuing[i] = next_alu_packets_issuing[i];
            end
        end

        for (int i = 0; i < `NUM_FU_BRANCH; ++i) begin
            if (branch_free[i] == 1'b1) begin
                branch_packets_issuing[i] = next_branch_packets_issuing[i];
            end
        end
    end

    always_ff begin
        for (int i = 0; i < `N; ++i) begin
            cdb_reg <= 
        end
    end

    always_comb begin
        for (int i = 0; i < `N; ++i) begin
            cdb_completing[i] <=
        end
    end

    // Instantiate the ALU
    alu [`NUM_FU_ALU-1:0] alu_fus (
        // Inputs
        .alu_packet(alu_packets_issuing),

        // Output
        .result(alu_result)
    );

    // Instantiate the multiplier
    mult [`NUM_FU_MULT-1:0] mult_fus (
        // Inputs
        .clock(clock),
        .reset(reset),
        .mult_packet(mult_packets_issuing),
        .cdb_en(mult_cdb_en),

        // Output
        .fu_free(mult_fu_free),
        .mult_cdb_valid(mult_cdb_valid),
        .result(mult_result)
    );

    // Instantiate the conditional branch module
    conditional_branch [`NUM_FU_BRANCH-1:0] conditional_branch_fus (
        // Inputs
        .branch_packet(branch_packets_issuing),

        // Output
        .take(take_conditional)
    );


    //add logic to set the mispredict signal

    // mispredict = prediction XOR actual 
    


endmodule // stage_ex











    DATA alu_result, mult_result, opa_mux_out, opb_mux_out;
    logic take_conditional;

    // Pass-throughs
    assign ex_packet.NPC          = id_ex_reg.NPC;
    assign ex_packet.rd_mem       = id_ex_reg.rd_mem;
    assign ex_packet.wr_mem       = id_ex_reg.wr_mem;
    assign ex_packet.dest_reg_idx = id_ex_reg.dest_reg_idx;
    assign ex_packet.halt         = id_ex_reg.halt;
    assign ex_packet.illegal      = id_ex_reg.illegal;
    assign ex_packet.csr_op       = id_ex_reg.csr_op;
    assign ex_packet.valid        = id_ex_reg.valid;

    // Send rs2_value to the mem stage as the data for a store
    assign ex_packet.rs2_value = id_ex_reg.rs2_value;

    // Break out the signed/unsigned bit and memory read/write size
    assign ex_packet.rd_unsigned = id_ex_reg.inst.r.funct3[2]; // 1 if unsigned, 0 if signed
    assign ex_packet.mem_size    = MEM_SIZE'(id_ex_reg.inst.r.funct3[1:0]);

    // Ultimate "take branch" signal:
    // unconditional, or conditional and the condition is true
    assign ex_packet.take_branch = id_ex_reg.uncond_branch || (id_ex_reg.cond_branch && take_conditional);

    // We split the alu and mult here since they will be split in the final project
    assign ex_packet.alu_result = (id_ex_reg.mult) ? mult_result : alu_result;