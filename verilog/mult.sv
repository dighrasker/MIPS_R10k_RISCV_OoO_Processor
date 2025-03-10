
`include "sys_defs.svh"

// This is a pipelined multiplier that multiplies two 64-bit integers and
// returns the low 64 bits of the result.
// This is not an ideal multiplier but is sufficient to allow a faster clock
// period than straight multiplication.

module mult # (
) (
    input logic         clock,
    input logic         reset, 
    input MULT_PACKET   mult_packet_in,

    // From the CDB, for the last stage to finish execute
    input logic         cdb_en,
    
    // TODO: make sure the outputs are correct
    output logic        en, // tells execute if it should apply backpressure on this FU
    output logic        valid_out, // tells cdb this FU has a valid inst
    output DATA         result
);

    typedef struct {
        logic            valid, 
        logic [63:0]     prev_sum,
        logic [63:0]     mplier,
        logic [63:0]     mcand,
        PHYS_REG_ID_BITS dest_reg_idx,
        B_MASK           bm,
        MULT_FUNC        func,
    } INTERNAL_MULT_PACKET;

    INTERNAL_MULT_PACKET [`MULT_STAGES-2:0] internal_mult_packets;
    INTERNAL_MULT_PACKET internal_mult_packet_in, internal_mult_packet_out;
    logic [`MULT_STAGES-2:0] internal_en;

    assign valid_out = internal_mult_packet_in[`MULT_STAGES-2].valid;

    assign internal_mult_packet_in.valid        = mult_packet_in.valid;
    assign internal_mult_packet_in.prev_sum     = 64'h0;
    assign internal_mult_packet_in.dest_reg_idx = mult_packet_in.dest_reg_idx;
    assign internal_mult_packet_in.bm           = mult_packet_in.bm;
    assign internal_mult_packet_in.func         = mult_packet_in.mult_func;

    always_comb begin
        case (mult_packet_in.mult_func)
            M_MUL, M_MULH, M_MULHSU: internal_mult_packet_in.mcand = {{(32){mult_packet_in.source_reg_1[31]}}, mult_packet_in.source_reg_1};
            default:                 internal_mult_packet_in.mcand = {32'b0, mult_packet_in.source_reg_1};
        endcase

        case (mult_packet_in.mult_func)
            M_MUL, M_MULH: internal_mult_packet_in.mplier = {{(32){mult_packet_in.source_reg_2[31]}}, mult_packet_in.source_reg_2};
            default:       internal_mult_packet_in.mplier = {32'b0, mult_packet_in.source_reg_2};
        endcase
    end

    // instantiate an array of mult_stage modules
    // this uses concatenation syntax for internal wiring, see lab 2 slides
    mult_stage mstage [`MULT_STAGES-1:0] (
        .clock (clock),
        .reset (reset),
        .en_in ({cdb_en, internal_en}),
        .internal_mult_packet_in ({internal_mult_packets, internal_mult_packet_in})
        .en_out ({internal_en, en})
        .internal_mult_packet_out ({internal_mult_packet_out, internal_mult_packets})
    );

    // Use the high or low bits of the product based on the output func
    assign result = (internal_mult_packet_out.func == M_MUL) ? internal_mult_packet_out.prev_sum[31:0] : internal_mult_packet_out.prev_sum[63:32];

endmodule // mult


module mult_stage (
    input logic clock,
    input logic reset, 
    input logic en_in,
    input INTERNAL_MULT_PACKET internal_mult_packet_in,

    output logic en_out,
    output INTERNAL_MULT_PACKET internal_mult_packet_out,
);

    parameter SHIFT = 64/`MULT_STAGES;
    INTERNAL_MULT_PACKET next_internal_mult_packet;

    assign next_internal_mult_packet.valid        = internal_mult_packet_in.valid;
    assign next_internal_mult_packet.prev_sum     = internal_mult_packet_in.mplier[SHIFT-1:0] * internal_mult_packet_in.mcand;
    assign next_internal_mult_packet.mplier       = {SHIFT'('b0), internal_mult_packet_in.mplier[63:SHIFT]};
    assign next_internal_mult_packet.mcand        = {internal_mult_packet_in.mcand[63-SHIFT:0], SHIFT'('b0)};
    assign next_internal_mult_packet.dest_reg_idx = internal_mult_packet_in.dest_reg_idx;
    assign next_internal_mult_packet.bm           = internal_mult_packet_in.bm;
    assign next_internal_mult_packet.func         = internal_mult_packet_in.func;

    assign en_out = en_in | ~internal_mult_packet_in.valid;                   // Either the next stage is enabled, or the current stage doesn't have anything

    always_ff @(posedge clock) begin
        // use en_in because we are deciding whether we should update the next mult stage
        if (en_in) begin
            internal_mult_packet_out <= next_internal_mult_packet;
        end
    end

endmodule // mult_stage
