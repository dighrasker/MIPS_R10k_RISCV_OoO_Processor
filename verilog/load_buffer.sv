`include "verilog/sys_defs.svh"

module load_buffer(
    input   logic                                 clock, 
    input   logic                                 reset,

    // ------------ TO/FROM LOAD_FU ------------- //
    input   LOAD_BUFFER_PACKET                    load_buffer_packet_in, // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    output  logic                                 load_buffer_free,

    // ------------- TO/FROM CACHE -------------- //
    input   logic                                 mshr_valid,
    input   MSHR_IDX                              mshr_idx,
    input   DATA                            [1:0] mshr_data,    // Cachelines are doubles

    // ------------- TO/FROM ISSUE -------------- //
    input  logic            [`LOAD_BUFFER_SZ-1:0] load_cdb_en,
    output logic            [`LOAD_BUFFER_SZ-1:0] load_cdb_req,

    // ------------ TO CDB ------------- //
    output CDB_REG_PACKET   [`LOAD_BUFFER_SZ-1:0] load_result
); 

    logic [`LOAD_BUFFER_SZ-1:0] load_buffer_status, next_load_buffer_status, chosen_spot, new_load;
    LOAD_BUFFER_PACKET [`LOAD_BUFFER_SZ-1:0] load_buffer, next_load_buffer;

    psel_gen #(
         .WIDTH(`LOAD_BUFFER_SZ),  // The width of the request bus
         .REQS(1) // The number of requests that can be simultaenously granted
    ) psel_inst (
         .req(~(load_buffer_status)), // Input request bus
         .gnt(chosen_spot)  // Output bus for each reLOAD_BUFFER_SZ
    );

    assign next_load_buffer_status = load_buffer_status ^ load_cdb_en ^ new_load;
    assign load_buffer_free = ~(&next_load_buffer_status);
    assign new_load = chosen_spot & 'load_buffer_packet_in.valid;

    always_comb begin
        next_load_buffer = load_buffer;

        for (int i = 0; i < `LOAD_BUFFER_SZ; ++i) begin
            if (new_load[i]) begin
                next_load_buffer[i] = load_buffer_packet_in;
            end
        end

        for (int i = 0; i < `LOAD_BUFFER_SZ; ++i) begin
            if (mshr_valid && load_buffer[i].mshr_idx == mshr_idx) begin
                for (int j = 0; j < 4; j++) begin
                    if (load_buffer[i].byte_mask[j]) begin
                        next_load_buffer[i].result.bytes[j] = mshr_data[load_buffer[i].dw.w_idx].bytes[j];
                        next_load_buffer[i].byte_mask[j] = 1'b0;
                    end
                end
            end
        end
    end

    always_comb begin
        for (int i = 0; i < `LOAD_BUFFER_SZ; ++i) begin
            load_cdb_req[i] = load_buffer_status[i] && !load_buffer[i].byte_mask;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            load_buffer_status <= '0;
            load_buffer <= '0;
        end else begin
            load_buffer_status <= next_load_buffer_status;
            load_buffer <= next_load_buffer;       
        end
        for(int i = 0, i < `LOAD_BUFFER_SZ; ++i) begin
            $display("load_cdb_req[%d]: %b", i, load_cdb_req[i]); //in case its some dont care
        end
    end

endmodule