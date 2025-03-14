`include "sys_defs.svh"

    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING
    // TODO: UPDATE THE DRAWING

module Issue # (
) (
    // ------------- FROM FREDDY -------------- //
    input logic        [`PHYS_REG_SZ_R10K-1:0] complete_list,       // The entire complete list of each register

    // ------------- TO/FROM RS -------------- //
    input RS_ENTRY_PACKET         [`RS_SZ-1:0] RS_data,             // full RS data exposed to issue for psel and FU packets generating
    input logic                   [`RS_SZ-1:0] RS_valid_next,
    output  wor                   [`RS_SZ-1:0] rs_data_issuing,     // set index to 1 when a RS_data is selected to be issued

    // ------------- FROM CDB -------------- //
    input DATA                        [`N-1:0] CDB_data_forwarded,  // for ETB, data forwarded from CDB to replace data 
    input PHYS_REG_IDX                [`N-1:0] CDB_tags_forwarded,

    // ------------- TO/FROM EXECUTE -------------- //
    // TODO: include the backpressure signals from each FU. 
    input                         [`NUM_FU_MULT-1:0] mult_free, // backpressure signal from the mult FU
    input                         [`NUM_FU_LDST-1:0] ldst_free, // backpressure signal from the ldst FU

    input                         [`NUM_FU_MULT-1:0] mult_cdb_req, // High if there is a valid instruction in the second to last stage of mult
    input                         [`NUM_FU_LDST-1:0] ldst_cdb_req, // High if there is a valid instruction in the second to last stage of ldst

    output logic                  [`NUM_FU_MULT-1:0] mult_cdb_gnt,
    output logic                  [`NUM_FU_LDST-1:0] ldst_cdb_gnt,
    output ALU_ENTRY_PACKET        [`NUM_FU_ALU-1:0] alu_packets,
    output MULT_ENTRY_PACKET      [`NUM_FU_MULT-1:0] mult_packets,
    output BRANCH_ENTRY_PACKET  [`NUM_FU_BRANCH-1:0] branch_packets,
    output LDST_ENTRY_PACKET      [`NUM_FU_LDST-1:0] ldst_packets,

    output logic [`N-1:0]        [`NUM_FU_TOTAL-1:0] complete_gnt_bus
);

// TODO: Make the ldst and mult fu grant buses

// Functional Unit Request Lines
logic [`RS_SZ-1:0] branch_entries_valid; // Which entries in the rs are a branch instruction
logic [`RS_SZ-1:0] mult_entries_valid;
logic [`RS_SZ-1:0] alu_entries_valid;
logic [`RS_SZ-1:0] ldst_entries_valid;
logic [`RS_SZ-1:0] single_cycle_entries_valid;

assign single_cycle_entries_valid = branch_entries_valid | alu_entries_valid; // which entries in the rs are single cycle instructions

//Functional Unit Grant Buses
logic [`N-1:0]             [`NUM_FU_TOTAL-1:0] next_complete_gnt_bus;
logic                             [`RS_SZ-1:0] rs_cdb_gnt;
logic                        [`NUM_FU_ALU-1:0] alu_cdb_gnt;
logic                     [`NUM_FU_BRANCH-1:0] branch_cdb_gnt;

logic [`NUM_FU_BRANCH-1:0]        [`RS_SZ-1:0] branch_inst_gnt_bus;
logic [`NUM_FU_ALU-1:0]           [`RS_SZ-1:0] alu_inst_gnt_bus;
logic [`NUM_FU_MULT-1:0]          [`RS_SZ-1:0] mult_inst_gnt_bus;
logic [`NUM_FU_LDST-1:0]          [`RS_SZ-1:0] ldst_inst_gnt_bus;

logic [`NUM_FU_MULT-1:0]    [`NUM_FU_MULT-1:0] mult_fu_gnt_bus;
logic [`NUM_FU_LDST-1:0]    [`NUM_FU_LDST-1:0] ldst_fu_gnt_bus;

generate
genvar i;
    for (i = 0; i < `RS_SZ; ++i) begin
        assign branch_entries_valid[i] = RS_valid_next[i] && RS_data[i].Source1_ready && RS_data[i].Source2_ready && (RS_data[i].FU_type == BU);
        assign mult_entries_valid[i] = RS_valid_next[i] && RS_data[i].Source1_ready && RS_data[i].Source2_ready && (RS_data[i].FU_type == MULT); 
        assign alu_entries_valid[i] = RS_valid_next[i] && RS_data[i].Source1_ready && RS_data[i].Source2_ready && (RS_data[i].FU_type == ALU); 
        assign ldst_entries_valid[i] = RS_valid_next[i] && RS_data[i].Source1_ready && RS_data[i].Source2_ready && (RS_data[i].FU_type == LDST); 
    end
endgenerate

psel_gen #(
    .WIDTH(`RS_SZ),
    .REQS(`NUM_FU_BRANCH)
) branch_inst_psel (
    .req(branch_entries_valid),
    .gnt_bus(branch_inst_gnt_bus),
    .empty(empty)
);

psel_gen #(
    .WIDTH(`RS_SZ),
    .REQS(`NUM_FU_MULT)
) mult_inst_psel (
    .req(mult_entries_valid),
    .gnt_bus(mult_inst_gnt_bus),
    .empty(empty)
);

psel_gen #(
    .WIDTH(`RS_SZ),
    .REQS(`NUM_FU_ALU)
) alu_inst_psel (
    .req(alu_entries_valid),
    .gnt_bus(alu_inst_gnt_bus),
    .empty(empty)
);

psel_gen #(
    .WIDTH(`RS_SZ),
    .REQS(`NUM_FU_LDST)
) ldst_inst_psel (
    .req(ldst_entries_valid),
    .gnt_bus(ldst_inst_gnt_bus),
    .empty(empty)
);

// FU PSELS

psel_gen #(
    .WIDTH(`NUM_FU_MULT),
    .REQS(`NUM_FU_MULT)
) mult_fu_psel (
    .req(mult_free),
    .gnt_bus(mult_fu_gnt_bus),
    .empty(empty)
);

psel_gen #(
    .WIDTH(`NUM_FU_LDST),
    .REQS(`NUM_FU_LDST)
) ldst_fu_psel (
    .req(ldst_free),
    .gnt_bus(ldst_fu_gnt_bus),
    .empty(empty)
);

// CDB and Complete psel

psel_gen #(
    .WIDTH(`CDB_ARBITER_SZ),
    .REQS(`N)
) cdb_psel (
    .req({single_cycle_entries_valid, mult_cdb_req, ldst_cdb_req}),
    .gnt({rs_cdb_gnt, mult_cdb_gnt, ldst_cdb_gnt}),
    .empty(empty)
);

psel_gen #(
    .WIDTH(`NUM_FU_TOTAL),
    .REQS(`N),
) complete_psel (
    .req({branch_cdb_gnt, alu_cdb_gnt, mult_cdb_gnt, ldst_cdb_gnt}),
    .gnt_bus(next_complete_gnt_bus),
    .empty(empty)
);


// Create The Branch Packets Issuing
generate
genvar i;
genvar j;
    //loop through branch gnt bus
    for (i = 0; i < `NUM_FU_BRANCH ++i) begin : branch_loop
        logic [`RS_SZ_BITS-1:0] branch_index;
        encoder #(`RS_SZ, `RS_SZ_BITS) encoders_branch (branch_inst_gnt_bus[i], branch_index);
        if (branch_inst_gnt_bus[i] & rs_cdb_gnt) begin
            assign rs_data_issuing = branch_inst_gnt_bus[i];
            assign branch_packet[i] = // TODO: get the data from rs_entries[branch_index] to form this branch packet
            //assign regfile_read_indices Decide how to index regfile later
            if (complete_list[rs_entries[branch_index].Source1]) begin
                assign branch_packet[i].Source1_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if (rs_entries[branch_index].Source1 == CDB_tags_forwarded[j]) begin
                       assign branch_packet[i].Source1_value = CDB_data_forwarded[j];
                    end
                end
            end

            if (complete_list[rs_entries[branch_index].Source2]) begin
                assign branch_packet[i].Src2_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if(rs_entries[branch_index].Source2 == CDB_tags_forwarded[j]) begin
                        assign branch_packet[i].Source2_value = CDB_data_forwarded[j];
                    end
                end
            end
            
            assign branch_cdb_gnt[i] = 1'b1;
        end else begin
            assign branch_packet[i] = //NOP TODO: get the data from rs_entries[branch_index] to form this branch packet
            assign branch_cdb_gnt[i] = 1'b0;
        end
    end
endgenerate


// Create The ALU Packets Issuing
generate
genvar i;
genvar j;
    //loop through alu gnt bus
    for (i = 0; i < `NUM_FU_ALU ++i) begin : alu_loop
        logic [`RS_SZ_BITS-1:0] alu_index;
        encoder #(`RS_SZ, `RS_SZ_BITS) encoders_alu (alu_inst_gnt_bus[i], alu_index);
        if (alu_inst_gnt_bus[i] & rs_cdb_gnt) begin
            assign rs_data_issuing = alu_inst_gnt_bus[i];
            assign alu_packet[i] = // TODO: get the data from rs_entries[alu_index] to form this alu packet
            //assign regfile_read_indices Decide how to index regfile later
            if (complete_list[rs_entries[alu_index].Source1]) begin
                assign alu_packet[i].Source1_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if (rs_entries[alu_index].Source1 == CDB_tags_forwarded[j]) begin
                       assign alu_packet[i].Source1_value = CDB_data_forwarded[j];
                    end
                end
            end

            if (complete_list[rs_entries[alu_index].Source2]) begin
                assign alu_packet[i].Src2_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if(rs_entries[alu_index].Source2 == CDB_tags_forwarded[j]) begin
                        assign alu_packet[i].Source2_value = CDB_data_forwarded[j];
                    end
                end
            end
            
            assign alu_cdb_gnt[i] = 1'b1;
        end else begin
            assign alu_packet[i] = //NOP TODO: get the data from rs_entries[alu_index] to form this alu packet
            assign alu_cdb_gnt[i] = 1'b0;
        end
    end
endgenerate


// Create The Mult Packets Issuing
generate
genvar i;
genvar j;
    //loop through mult gnt bus
    for (i = 0; i < `NUM_FU_MULT ++i) begin : mult_loop
        logic [`RS_SZ_BITS-1:0] mult_rs_index;
        encoder #(`RS_SZ, `RS_SZ_BITS) inst_encoders_mult (mult_inst_gnt_bus[i], mult_rs_index);
        encoder #(`RS_SZ, `RS_SZ_BITS) fu_encoders_mult (mult_fu_gnt_bus[i], mult_fu_index);
        if (mult_inst_gnt_bus[i] && mult_fu_gnt_bus[i]) begin
            assign rs_data_issuing = mult_inst_gnt_bus[i];
            assign mult_packet[mult_fu_index] = // TODO: get the data from rs_entries[mult_rs_index] to form this mult packet
            if (complete_list[rs_entries[mult_rs_index].Source1]) begin
                assign mult_packet[mult_fu_index].Source1_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if (rs_entries[mult_rs_index].Source1 == CDB_tags_forwarded[j]) begin
                       assign mult_packet[mult_fu_index].Source1_value = CDB_data_forwarded[j];
                    end
                end
            end

            if (complete_list[rs_entries[mult_rs_index].Source2]) begin
                assign mult_packet[mult_fu_index].Src2_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if(rs_entries[mult_rs_index].Source2 == CDB_tags_forwarded[j]) begin
                        assign mult_packet[mult_fu_index].Source2_value = CDB_data_forwarded[j];
                    end
                end
            end
        end else begin
            assign mult_packet[mult_fu_index] = //NOP TODO: get the data from rs_entries[mult_index] to form this alu packet
        end
    end
endgenerate


// Create The LDST Packets Issuing
generate
genvar i;
genvar j;
    //loop through ldst gnt bus
    for (i = 0; i < `NUM_FU_MULT ++i) begin : ldst_loop
        logic [`RS_SZ_BITS-1:0] ldst_rs_index;
        encoder #(`RS_SZ, `RS_SZ_BITS) inst_encoders_ldst (ldst_inst_gnt_bus[i], ldst_rs_index);
        encoder #(`RS_SZ, `RS_SZ_BITS) fu_encoders_ldst (ldst_fu_gnt_bus[i], ldst_fu_index);
        if (ldst_inst_gnt_bus[i] && ldst_fu_gnt_bus[i]) begin
            assign rs_data_issuing = ldst_inst_gnt_bus[i];
            assign ldst_packet[ldst_fu_index] = // TODO: get the data from rs_entries[ldst_rs_index] to form this ldst packet
            if (complete_list[rs_entries[ldst_rs_index].Source1]) begin
                assign ldst_packet[ldst_fu_index].Source1_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if (rs_entries[ldst_rs_index].Source1 == CDB_tags_forwarded[j]) begin
                       assign ldst_packet[ldst_fu_index].Source1_value = CDB_data_forwarded[j];
                    end
                end
            end

            if (complete_list[rs_entries[ldst_rs_index].Source2]) begin
                assign ldst_packet[ldst_fu_index].Src2_value = regfile_outputs;
            end else begin
                for(j = 0; j < `N; ++j) begin
                    if(rs_entries[ldst_rs_index].Source2 == CDB_tags_forwarded[j]) begin
                        assign ldst_packet[ldst_fu_index].Source2_value = CDB_data_forwarded[j];
                    end
                end
            end
        end else begin
            assign ldst_packet[ldst_fu_index] = //NOP TODO: get the data from rs_entries[mult_index] to form this alu packet
        end
    end
endgenerate

always_ff @(posedge clock) begin
    if(reset) begin
        complete_gnt_bus <= '0;
    end else begin
        complete_gnt_bus <= next_complete_gnt_bus;
    end
end

endmodule