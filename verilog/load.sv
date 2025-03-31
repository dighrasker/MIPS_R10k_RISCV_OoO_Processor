`include "verilog/sys_defs.svh"

// This is a pipelined multiplier that multiplies two 64-bit integers and
// returns the low 64 bits of the result.
// This is not an ideal multiplier but is sufficient to allow a faster clock
// period than straight multiplication.

module load # (
) (
    input logic             clock,
    input logic             reset, 
    
    // ------------ TO/FROM EXECUTE ------------- //
    input LOAD_ADDR_PACKET            load_addr_packet,

    // ------------ TO/FROM ISSUE ------------- //
    input logic                     [`LOAD_BUFFER_SZ-1:0] load_cdb_en,
    output logic                    [`LOAD_BUFFER_SZ-1:0] load_cdb_req,

    // ------------ TO CDB ------------- //
    output CDB_REG_PACKET           [`LOAD_BUFFER_SZ-1:0] load_result,

    // ------------ FROM BRANCH STACK --------------//
    input B_MASK                    b_mm_resolve,
    input logic                     b_mm_mispred,
);

    
    INTERNAL_MULT_PACKET [`MULT_STAGES-2:0] internal_mult_packets;
    INTERNAL_MULT_PACKET internal_mult_packet_in, internal_mult_packet_out;

    logic [`MULT_STAGES-2:0] internal_free;

    // always_ff @(posedge clock) begin //TODO: Decide between letting issue know vs not letting issue know
    //     if (reset) begin
    //         cdb_valid <= 0;
    //     end else begin
    //         cdb_valid <= internal_mult_packets[`MULT_STAGES-3].valid;
    //     end
    // end

    assign cdb_valid = internal_mult_packets[`MULT_STAGES-2].valid;

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
    load_addr_stage  [`MULT_STAGES-1:0] (
        .clock (clock),
        .reset (reset),
        .is_last_stage ({1'b1, {(`MULT_STAGES-1){1'b0}}}),
        .next_stage_free ({cdb_en, internal_free}),
        .internal_mult_packet_in ({internal_mult_packets, internal_mult_packet_in}),
        .b_mm_mispred (b_mm_mispred),
        .b_mm_resolve (b_mm_resolve),
        .current_stage_free ({internal_free, fu_free}),
        .internal_mult_packet_out ({internal_mult_packet_out, internal_mult_packets})
    );

    // assign mult_result.result = (internal_mult_packet_out.func == M_MUL) ? internal_mult_packet_out.prev_sum[31:0]
    assign mult_result.result = internal_mult_packet_out.prev_sum[31:0];
    assign mult_result.completing_reg = internal_mult_packet_out.dest_reg_idx;
    assign mult_result.valid = internal_mult_packet_out.valid;
endmodule // mult