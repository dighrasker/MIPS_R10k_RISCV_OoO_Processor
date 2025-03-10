`include "sys_defs.svh"

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

    // ------------- TO EXECUTE -------------- //

    output ALU_PACKET        [`NUM_FU_ALU-1:0] alu_packets,
    output MULT_PACKET      [`NUM_FU_MULT-1:0] mult_packets,
    output BRANCH_PACKET  [`NUM_FU_BRANCH-1:0] branch_packets,
    output LD_PACKET        [`NUM_FU_LOAD-1:0] ld_packets,
    output ST_PACKET       [`NUM_FU_STORE-1:0] st_packets
);

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

genvar i;
generate
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
) branch_psel (
    .req(branch_entries_valid),            // Input request bus
    .gnt_bus(bu_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_MULT)                   // The number of requests that can be simultaenously granted
) mult_psel (
    .req(mult_entries_valid),            // Input request bus
    .gnt_bus(mult_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_ALU)                   // The number of requests that can be simultaenously granted
) alu_psel (
    .req(alu_entries_valid),            // Input request bus
    .gnt_bus(alu_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);

psel_gen #(
    .WIDTH(`RS_SZ),  // The width of the request bus
    .REQS(`NUM_FU_LDST)                   // The number of requests that can be simultaenously granted
) ldst_psel (
    .req(alu_entries_valid),            // Input request bus
    .gnt_bus(ldst_gnt_bus),      // Output bus for each request
    .empty(empty)               // Output asserted when there are no requests
);



endmodule