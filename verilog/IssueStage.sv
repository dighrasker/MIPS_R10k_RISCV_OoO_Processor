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
    output                        [`RS_SZ-1:0] rs_data_issuing,     // set index to 1 when a RS_data is selected to be issued

    // ------------- FROM CDB -------------- //
    input DATA                        [`N-1:0] CDB_data_forwarded,  // for ETB, data forwarded from CDB to replace data 

    // ------------- TO/FROM EXECUTE -------------- //
    // TODO: include the backpressure signals from each FU. 
    input                   [`NUM_FU_MULT-1:0] mult_empty,
    input                   [`NUM_FU_LDST-1:0] ldst_empty,
    output ALU_PACKET        [`NUM_FU_ALU-1:0] alu_packets,
    output MULT_PACKET      [`NUM_FU_MULT-1:0] mult_packets,
    output BRANCH_PACKET  [`NUM_FU_BRANCH-1:0] branch_packets,
    output LD_PACKET        [`NUM_FU_LOAD-1:0] ldst_packets
);

// TODO: Make the ldst and mult fu grant busses
// Functional Unit Request Lines
logic [`RS_SZ-1:0] branch_entries_valid;
logic [`RS_SZ-1:0] mult_entries_valid;
logic [`RS_SZ-1:0] alu_entries_valid;
logic [`RS_SZ-1:0] ldst_entries_valid;
logic [`RS_SZ-1:0] single_cycle_entries_valid;

//Functional Unit Grant Busses
logic [`CDB_ARBITER_SZ:0]                complete_gnt;
logic [`NUM_FU_BRANCH-1:0]  [`RS_SZ-1:0] bu_gnt_bus;
logic [`NUM_FU_ALU-1:0]     [`RS_SZ-1:0] alu_gnt_bus;
logic [`NUM_FU_MULT-1:0]    [`RS_SZ-1:0] mult_gnt_bus;
logic [`NUM_FU_LDST-1:0]    [`RS_SZ-1:0] ldst_gnt_bus;


assign single_cycle_entries_valid = branch_entries_valid | alu_entries_valid;

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
    .WIDTH(`CDB_ARBITER_SZ),  // The width of the request bus
    .REQS(`N)                   // The number of requests that can be simultaenously granted
) complete_psel (
    .req(single_cycle_entries_valid),            // Input request bus
    .gnt(complete_gnt),                  // Output with all granted requests on a bus
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_BRANCH)                   // The number of requests that can be simultaenously granted
) branch_inst_psel (
    .req(branch_entries_valid),            // Input request bus
    .gnt_bus(bu_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_MULT)                   // The number of requests that can be simultaenously granted
) mult_inst_psel (
    .req(mult_entries_valid),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_ALU)                   // The number of requests that can be simultaenously granted
) alu_inst_psel (
    .req(alu_entries_valid),            // Input request bus
    .gnt_bus(alu_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_LDST)                   // The number of requests that can be simultaenously granted
) ldst_inst_psel (
    .req(alu_entries_valid),            // Input request bus
    .gnt_bus(ldst_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

// FU PSELS

psel_gen #(
    .WIDTH(`NUM_FU_MULT),  // The width of the request bus
    .REQS(`NUM_FU_MULT)                   // The number of requests that can be simultaenously granted
) mult_fu_psel (
    .req(mult_empty),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request TODO: assign the the mult fu grant bus
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`NUM_FU_LDST),  // The width of the request bus
    .REQS(`NUM_FU_LDST)                   // The number of requests that can be simultaenously granted
) ldst_fu_psel (
    .req(ldst_empty),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request TODO: assign the the LDST fu grant bus 
    .empty(empty)               // Output asserted when there are no requests
);

logic [`NUM_FU_ALU-1:0] [`RS_SZ_BITS-1:0] alu_indices;
generate
genvar i;
genvar j;
    //loop through alu gnt bus
    for (i = 0; i < `NUM_FU_ALU; ++i) begin : alu_loop
        encoder #(`RS_SZ, `RS_SZ_BITS) encoders_alu (alu_gnt_bus[i], alu_indices[i]);
        if (alu_gnt_bus[i] & complete_gnt[`RS_SZ-1:0] > 0) begin
            assign alu_packet[i].inst = RS_data.decoded_signals.inst; // TODO: get the data from rs_entries[alu_indices[i]] to form this alu packet
            assign alu_packet[i].source_reg_1 = RS_data[i].Source1;
            assign alu_packet[i].source_reg_2 = RS_data[i].Source2;
            assign alu_packet[i].dest_reg_idx =  RS_data[i].T_new;
        end
    end
endgenerate



// logic [`NUM_FU_MULT-1:0] [`RS_SZ_BITS-1:0] mult_indices;
// generate
// genvar i;
// genvar j;
//     //loop through mult gnt bus
//     for (i = 0; i < `NUM_FU_MULT; ++i) begin : mult_loop
//         encoder #(`RS_SZ, `RS_SZ_BITS) encoders_mult (mult_gnt_bus[i], mult_indices[i]);
//         if (mult_gnt_bus[i] & complete_gnt[`RS_SZ-1:0] > 0) begin
//             assign mult_packet[i] = // TODO: get the data from rs_entries[mult_indices[i]] to form this mult packet
//         end
//     end
// endgenerate

logic [`NUM_FU_BRANCH-1:0] [`RS_SZ_BITS-1:0] branch_indices;
generate
genvar i;
genvar j;
    //loop through branch gnt bus
    for (i = 0; i < `NUM_FU_BRANCH ++i) begin : branch_loop
        encoder #(`RS_SZ, `RS_SZ_BITS) encoders_branch (branch_gnt_bus[i], branch_indices[i]);
        if (branch_gnt_bus[i] & complete_gnt[`RS_SZ-1:0] > 0) begin
            assign branch_packet[i] = // TODO: get the data from rs_entries[branch_indices[i]] to form this branch packet
        end
    end
endgenerate

// logic [`NUM_FU_LDST-1:0] [`RS_SZ_BITS-1:0] ldst_indices;
// generate
// genvar i;
// genvar j;
//     //loop through ldst gnt bus
//     for (i = 0; i < `NUM_FU_LDST; ++i) begin : ldst_loop
//         encoder #(`RS_SZ, `RS_SZ_BITS) encoders_ldst (ldst_gnt_bus[i], ldst_indices[i]);
//         if (ldst_gnt_bus[i] & complete_gnt[`RS_SZ-1:0] > 0) begin
//             assign ldst_packet[i] = // TODO: get the data from rs_entries[branch_indices[i]] to form this branch packet
//         end
//     end
// endgenerate


endmodule