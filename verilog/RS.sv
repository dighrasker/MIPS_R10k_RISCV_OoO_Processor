module RS #(

) (
    input   logic                       clock, 
    input   logic                       reset,
    input   logic             [`N-1:0]  valid_entries
    input   RS_ENTRY_PACKET   [`N-1:0]  rs_entries, // Write data
);
    // Main RS Data Here
    RS_ENTRY_PACKET [`RS_SZ-1:0] rs;

    always_comb begin
    
    end

    always_ff @(posedge clock) begin
        if (reset) begin
        
        end else begin
            
        end
    end

endmodule