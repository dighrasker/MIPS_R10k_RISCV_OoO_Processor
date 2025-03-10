module ExecuteStage (
    input   logic                               clock,
    input   logic                               reset,

    // --------------- TO/FROM ISSUE REGISTER --------------- //
    input MULT_PACKET       [`N-1:0] next_mult_packets_issuing, 
    input ALU_PACKET        [`N-1:0] next_alu_packets_issuing,
    input BRANCH_PACKET              next_branch_packets_issuing,
    output logic [`N-1:0] mult_en,
    output logic [`N-1:0] alu_en,
    output logic [`N-1:0] branch_en,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output DATA             [`N-1:0] cdb_completing_results,
    output PHYS_REG_IDX     [`N-1:0] cdb_completing_phys_regs,
    output                  [`N-1:0] cdb_completing_valid,
);

    MULT_PACKET   mult_packets_issuing;
    ALU_PACKET    alu_packets_issuing;
    BRANCH_PACKET branch_packets_issuing;

    always_ff @(posedge clock) begin
        for (int i = 0; i < `N; ++i) begin
            if (mult_en[i] == 1'b1) begin
                mult_packets_issuing[i] = next_mult_packets_issuing[i];
            end
        end

        for (int i = 0; i < `N; ++i) begin
            if (alu_en[i] == 1'b1) begin
                alu_packets_issuing[i] = next_alu_packets_issuing[i];
            end
        end

        for (int i = 0; i < `N; ++i) begin
            if (branch_en[i] == 1'b1) begin
                branch_packets_issuing[i] = next_branch_packets_issuing[i];
            end
        end
    end

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

    // Instantiate the ALU
    alu [`N-1:0] alus (
        // Inputs
        .alu_packet(alu_packets_issuing),

        // Output
        .result(alu_result)
    );

    // Instantiate the multiplier
    mult [`N-1:0] mult_0 (
        // Inputs
        .clock(clock),
        .reset(reset),

        .mult_packet(mult_packets_issuing),

        // Output
        .result(mult_result)
    );

    // Instantiate the conditional branch module
    conditional_branch conditional_branch_0 (
        // Inputs
        .branch_packet(branch_packets_issuing),

        // Output
        .take(take_conditional)
    );

endmodule // stage_ex
