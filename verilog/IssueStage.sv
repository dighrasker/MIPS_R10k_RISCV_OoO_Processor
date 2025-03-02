`include "sys_defs.svh"

module Issue # (
) (
    // ------------- FROM FREDDY -------------- //
    input logic        [`PHYS_REG_SZ_R10K-1:0] complete_list,       // The entire complete list of each register

    // ------------- TO/FROM RS -------------- //
    input RS_ENTRY_PACKET         [`RS_SZ-1:0] RS_data,             // full RS data exposed to issue for psel and FU packets generating
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

// RS psel declared here

endmodule