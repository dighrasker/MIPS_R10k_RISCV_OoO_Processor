module FreddyList #(
) (
    input   clock,
    input   reset,
    // ------------- FROM CDB -------------- //
    input  PHYS_REG_IDX           [`N-1:0] phys_reg_completing,    // phys reg indexes that are being completed (T_new)
    input  logic                  [`N-1:0] completing_valid,       // bit vector of N showing which phys_reg_completing is valid
    // ------------- FROM RETIRE -------------- //
    input  PHYS_REG_IDX           [`N-1:0] phys_reg_retiring,      // phy reg indexes that are being retired (T_old)
    input  logic    [`NUM_SCALAR_BITS-1:0] num_retiring_valid,     // number of retiring phys reg (T_old)
    // ------------- FROM BRANCH STACK -------------- //
    input  logic   [`PHYS_REG_SZ_R10K-1:0] free_list_restore,      // snapshot of freelist at mispredicted branch
    input  logic                           restore_flag,           // branch mispredict flag
    // ------------- FROM DISPATCH -------------- //
    input  logic   [`PHYS_REG_SZ_R10K-1:0] updated_free_list,      // freelist from dispatch
    // input  logic    [`NUM_SCALAR_BITS-1:0] num_dispatched,
    // ------------- TO DISPATCH -------------- //
    output PHYS_REG_IDX           [`N-1:0] phys_regs_to_use,       // physical register indices for dispatch to use
    // output logic    [`NUM_SCALAR_BITS-1:0] free_list_spots,        // how many physical registers are free
    output logic   [`PHYS_REG_SZ_R10K-1:0] free_list,              // bitvector of the phys reg that are complete
    // ------------- TO ISSUE -------------- //
    output logic   [`PHYS_REG_SZ_R10K-1:0] complete_list           // bitvector of the phys reg that are complete
);

    logic [`PHYS_REG_SZ_R10K-1:0] next_complete_list;
    logic [`PHYS_REG_SZ_R10K-1:0] next_free_list;

    // psel shit
    logic [`N-1:0] [`PHYS_REG_SZ_R10K-1:0] psel_output;
    logic [`PHYS_REG_SZ_R10K-1:0] gnt;
    logic empty;

    logic [`PHYS_REG_SZ_R10K-1:0] dispatched_reg;
    // logic [`PHYS_REG_NUM_ENTRIES_BITS-1:0] entries, next_entries;       // entries for free list

    assign dispatched_reg = free_list ^ updated_free_list;               // to find out which phys reg are being dispatched
    // assign next_entries = entries - num_dispatched + num_retiring_valid;
    // assign free_list_spots = (`PHYS_REG_SZ_R10K - entries) < `N ? (`PHYS_REG_SZ_R10K - entries) : `N;


    psel_gen #(
         .WIDTH(`PHYS_REG_SZ_R10K),  // The width of the request bus
         .REQS(`N)            // The number of requests that can be simultaenously granted
    ) psel_inst (
         .req(free_list),          // Input request bus
         .gnt(gnt),          // Output with all granted requests on a bus
         .gnt_bus(psel_output),  // Output bus for each request
         .empty(empty)       // Output asserted when there are no requests
    );

    genvar i;
    generate
        for(i = 0; i < `N; ++i) begin: encoderblock
            encoder u_encoder (psel_output[i], phys_regs_to_use[i]);
        end
    endgenerate

    always_comb begin // TODO: consider genvar
        next_complete_list = complete_list;
        for (int i = 0; i < `N; ++i) begin
            next_complete_list[phys_reg_completing[i]] = completing_valid[i];
        end

        next_complete_list = ~(dispatched_reg) & next_complete_list;
    end

    always_comb begin
        next_free_list = updated_free_list;
        for (int i = 0; i < `N; ++i) begin
            if (i < num_retiring_valid) begin
                next_free_list[phys_reg_retiring[i]] = 1'b0;
            end
        end
    end

    
    always_ff @(posedge clock) begin
        if (reset) begin
            complete_list[`PHYS_REG_SZ_R10K-1:`ARCH_REG_SZ_R10K] <= `0;
            complete_list[`ARCH_REG_SZ_R10K-1:0] <= ~0;                 // Assumption: at reset, all mappings are restored to original, ex. reg1 -> pr1
            free_list[`PHYS_REG_SZ_R10K-1:`ARCH_REG_SZ_R10K] <= ~0;
            free_list[`ARCH_REG_SZ_R10K-1:0] <= `0;
            // entries <= `0;
        end else begin
            complete_list <= next_complete_list;
            free_list <= restore_flag ? next_free_list | free_list_restore : next_free_list;
            // entries <= next_entries;
        end
    end
endmodule

module encoder #(
)(
    input  wire [`PHYS_REG_SZ_R10K-1:0] in,                    // N-bit input
    output reg  [`PHYS_REG_ID_BITS-1:0] out,                   // Encoded output
);

    integer i;
    
    always @(*) begin
        out   = 0;
        for (i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            if (in[i]) begin
                out   = i[`PHYS_REG_ID_BITS-1:0];  // Assign the index as output
            end
        end
    end
endmodule

// module CompleteList #(
//     parameter LENGTH = `PHYS_REG_SZ_R10K,
//     parameter LENGTH_BITS = `PHYS_REG_ID_BITS
// ) (
//     input   clock,
//     input   reset,
//     input  PHYS_REG_IDX           [`N-1:0] inputs_completing,    // phys reg indexes that are being completed (T_new)
//     input  logic                  [`N-1:0] completing_valid, // number of retiring phys reg (T_New)
//     input  PHYS_REG_IDX           [`N-1:0] inputs_retiring,      // phy reg indexes that are being retired (T_old)
//     input  logic    [`NUM_SCALAR_BITS-1:0] num_retiring_valid,   // number of retiring phys reg (T_old)
//     output logic   [`PHYS_REG_SZ_R10K-1:0] complete_list         // bitvector of the phys reg that are complete
// );

//     logic [LENGTH-1:0] next_complete_list;

//     generate 
//         next_complete = complete;
//         for (genvar i = 0; i < `N; ++i) begin
//             if (i < num_completing_valid) begin // TODO: build decoder if necessary
//                 next_complete_list[inputs_completing[i]] = 1'b1;
//             end
//         end

//         for (genvar i = 0; i < `N; ++i) begin
//             if (i < num_retiring_valid) begin // TODO: build decoder if necessary
//                 next_complete_list[inputs_retiring[i]] = 1'b0;
//             end
//         end
//     endgenerate
    
//     always_ff @(posedge clock) begin
//         if (reset) begin
//             complete <= '0;
//         end else begin
//             complete <= next_complete
//         end
//     end

//     // if (inputs_completing[i] != `PHYS_REG_SZ_R10K) begin
//     //     next_complete[inputs_completing[i]] = 1'b1; // this is not synthesizable
//     // end
// endmodule