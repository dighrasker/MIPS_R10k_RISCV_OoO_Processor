module ExecuteStage (
    input MULT_PACKET       [`N-1:0] MULT_packets_issuing,
    input ALU_PACKET        [`N-1:0] ALU_packets_issuing,
    input BRANCH_PACKET              BRANCH_packets_issuing,

    output DATA             [`N-1:0] cdb_completing_results,
    output PHYS_REG_IDX     [`N-1:0] cdb_completing_phys_regs,
    output                  [`N-1:0] cdb_completing_valid,
);

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

    // ALU opA mux
    always_comb begin
        case (id_ex_reg.opa_select)
            OPA_IS_RS1:  opa_mux_out = id_ex_reg.rs1_value;
            OPA_IS_NPC:  opa_mux_out = id_ex_reg.NPC;
            OPA_IS_PC:   opa_mux_out = id_ex_reg.PC;
            OPA_IS_ZERO: opa_mux_out = 0;
            default:     opa_mux_out = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (id_ex_reg.opb_select)
            OPB_IS_RS2:   opb_mux_out = id_ex_reg.rs2_value;
            OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(id_ex_reg.inst);
            OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(id_ex_reg.inst);
            OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(id_ex_reg.inst);
            OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(id_ex_reg.inst);
            OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(id_ex_reg.inst);
            default:      opb_mux_out = 32'hfacefeed; // face feed
        endcase
    end

    // Instantiate the ALU
    alu [`N-1:0] alus (
        // Inputs
        .opa(opa_mux_out),
        .opb(opb_mux_out),
        .alu_func(id_ex_reg.alu_func),

        // Output
        .result(alu_result)
    );

    // Instantiate the multiplier
    mult_no_pipeline [`N-1:0] mult_0 (
        // Inputs
        .rs1(id_ex_reg.rs1_value),
        .rs2(id_ex_reg.rs2_value),
        .func(id_ex_reg.inst.r.funct3), // which mult operation to perform

        // Output
        .result(mult_result)
    );

    // Instantiate the conditional branch module
    conditional_branch conditional_branch_0 (
        // Inputs
        .rs1(id_ex_reg.rs1_value),
        .rs2(id_ex_reg.rs2_value),
        .func(id_ex_reg.inst.b.funct3), // Which branch condition to check

        // Output
        .take(take_conditional)
    );

endmodule // stage_ex
