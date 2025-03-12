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
    input                   [`NUM_FU_MULT-1:0] mult_free,
    input                   [`NUM_FU_LDST-1:0] ldst_free,

    input                   [`NUM_FU_MULT-1:0] mult_cdb_req,
    input                   [`NUM_FU_LDST-1:0] ldst_cdb_req,
    

    output ALU_PACKET        [`NUM_FU_ALU-1:0] alu_packets,
    output MULT_PACKET      [`NUM_FU_MULT-1:0] mult_packets,
    output BRANCH_PACKET  [`NUM_FU_BRANCH-1:0] branch_packets,
    output LD_PACKET        [`NUM_FU_LOAD-1:0] ldst_packets
);

// TODO: Make the ldst and mult fu grant buses

logic [`NUM_FU_BRANCH-1:0] branch_cdb_req;
logic [`NUM_FU_BRANCH-1:0] alu_cdb_req;

// Functional Unit Request Lines
logic [`RS_SZ-1:0] branch_entries_valid;
logic [`RS_SZ-1:0] mult_entries_valid;
logic [`RS_SZ-1:0] alu_entries_valid;
logic [`RS_SZ-1:0] ldst_entries_valid;
logic [`RS_SZ-1:0] single_cycle_entries_valid;



//Functional Unit Grant Buses
logic [`CDB_ARBITER_SZ:0]   [`NUM_FU_TOTAL-1:0]  complete_gnt_bus, next_complete_gnt_bus;
logic [`NUM_FU_BRANCH-1:0]  [`RS_SZ-1:0] bu_gnt_bus;
logic [`NUM_FU_ALU-1:0]     [`RS_SZ-1:0] alu_gnt_bus;
logic [`NUM_FU_MULT-1:0]    [`RS_SZ-1:0] mult_gnt_bus;
logic [`NUM_FU_LDST-1:0]    [`RS_SZ-1:0] ldst_gnt_bus;

logic [`NUM_FU_BRANCH-1:0]  [`RS_SZ_BITS-1:0] bu_indices;
logic [`NUM_FU_ALU-1:0]     [`RS_SZ_BITS-1:0] alu_indices;
logic [`NUM_FU_MULT-1:0]    [`RS_SZ_BITS-1:0] mult_indices;
logic [`NUM_FU_LDST-1:0]    [`RS_SZ_BITS-1:0] ldst_indices;

//assign single_cycle_entries_valid = branch_entries_valid | alu_entries_valid;

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
    .req(({branch_cdb_req, alu_cdb_req, ldst_cdb_req, mult_cdb_req})),            // Input request bus
    .gnt(complete_gnt),                  // Output with all granted requests on a bus
    .gnt_bus(next_complete_gnt_bus),      // Output bus for each request
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
    .req(ldst_entries_valid),            // Input request bus
    .gnt_bus(ldst_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

// FU PSELS

psel_gen #(
    .WIDTH(`NUM_FU_MULT),  // The width of the request bus
    .REQS(`NUM_FU_MULT)                   // The number of requests that can be simultaenously granted
) mult_fu_psel (
    .req(mult_free),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request TODO: assign the the mult fu grant bus
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`NUM_FU_LDST),  // The width of the request bus
    .REQS(`NUM_FU_LDST)                   // The number of requests that can be simultaenously granted
) ldst_fu_psel (
    .req(ldst_free),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request TODO: assign the the LDST fu grant bus 
    .empty(empty)               // Output asserted when there are no requests
);

// Choose which branch inst to issue
always_comb begin
    for (int i = 0; i < `NUM_FU_BRANCH ++i) begin
        branch_cdb_req[i] = |bu_gnt_bus[i];
    end
end

encoder #(`RS_SZ, `RS_SZ_BITS) encoders_branch [`NUM_FU_BRANCH-1:0] (bu_gnt_bus, bu_indices);
wor [`NUM_FU_BRANCH-1:0] branch_fu_selected;
always_comb begin
    //loop through branch gnt bus
    for (int i = 0; i < `NUM_FU_BRANCH; ++i) begin
        for (j = 0; j < `N; ++j) begin
            branch_fu_selected[i] = next_complete_gnt_bus[j][i];
        end

        if (bu_gnt_bus[i] && branch_fu_selected[i]) begin
            branch_packet[i] = // TODO: get the data from rs_entries[branch_indices[i]] to form this branch packet
        end else begin
            branch_packet[i] = // NOP 
        end
    end
end


// Choose which alu inst to issue
always_comb begin
    for (int i = 0; i < `NUM_ALU_BRANCH ++i) begin
        alu_cdb_req[i] = |alu_gnt_bus[i];
    end
end

encoder #(`RS_SZ, `RS_SZ_BITS) encoders_alu [`NUM_ALU_BRANCH-1:0] (alu_gnt_bus, alu_indices);
wor [`NUM_FU_BRANCH-1:0] alu_fu_selected;
always_comb begin
    //loop through branch gnt bus
    for (int i = 0; i < `NUM_ALU_BRANCH; ++i) begin
        for (j = 0; j < `N; ++j) begin
            alu_fu_selected[i] = next_complete_gnt_bus[j][i];
        end

        if (alu_gnt_bus[i] && alu_fu_selected[i]) begin
            alu_packet[i] = // TODO: get the data from rs_entries[branch_indices[i]] to form this branch packet
        end else begin
            alu_packet[i] = // NOP 
        end
    end
end

always_ff @(posedge clock) begin
    if(reset) begin
        complete_gnt_bus <= '0;
    end else begin
        complete_gnt_bus <= next_complete_gnt_bus;
    end
end

endmodule