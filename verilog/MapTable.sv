module MapTable #(
    parameter LENGTH = `PHYS_REG_SZ_R10K,
    parameter LENGTH_BITS = `PHYS_REG_ID_BITS
) (
    input  logic                    clock,
    input  logic                    reset,

    // ------- TO/FROM DISPATCH -------- //
    input ARCH_REG_IDX            [`N-1:0] dest_reg,
    input logic     [`NUM_SCALAR_BITS-1:0] inst_valid,      //number of instruction valid
    input PHYS_REG_IDX            [`N-1:0] free_regs,
    input ARCH_REG_IDX            [`N-1:0] source1_arch_reg, // 
    input ARCH_REG_IDX            [`N-1:0] source2_arch_reg,
    input logic     [`NUM_SCALAR_BITS-1:0] dest_reg_valid,
    output PHYS_REG_IDX           [`N-1:0] source1_phys_reg, // 
    output PHYS_REG_IDX           [`N-1:0] source2_phys_reg
    // input: map_table_restore
    // output: map_table_checkpoint
);

    PHYS_REG_IDX [`ARCH_REG_SZ_R10K:0] map_table, next_map_table;

    always_comb begin
        next_map_table = map_table;
        generate
            for (genvar i; i < `N; ++i) begin
                if(i < inst_valid) begin
                    source1_phys_reg[i] = next_map_table[source1_arch_reg[i]];
                    source2_phys_reg[i] = next_map_table[source2_arch_reg[i]];
                    next_map_table[dest_reg[i]] = free_regs[i];
                end
            end
        endgenerate
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            map_table <= 0;
        end else begin
            map_table <= next_map_table;
        end
    end

endmodule