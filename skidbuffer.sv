// Building a skidbuffer for AXI Processing - ZIPCPU Blog : https://zipcpu.com/blog/2019/05/22/skidbuffer.html

// Signal Names:
// i_valid - From previous pipeline stage indicating if the data is valid or not
// i_ready - From next pipeline stage indicating if the next stage is ready to receive data
// i_data - Data from the prev pipeline stage
// r_valid - Indicating if the data stored in the buffer of current stage valid or dont care
// r_data - The internal buffer containing buffered data
// o_valid - Output valid signal indicating next stage that o_data is valid
// o_ready - Output ready signal to the previous stage indicating that ready to receive data
// o_data - Data passed to next stage

module skidbuffer #(
		parameter	[0:0]	OPT_LOWPOWER = 0,      // Parameter option to enable low power mode which sets all data buses = 0 when valid = 0
		parameter	[0:0]	OPT_OUTREG = 1,        // Parameter option to decide whether to drive output through combination logic or registering them first
        parameter	DW = 8,
	) 
    (
		input	logic			i_clk, i_reset,
		input	logic			i_valid,
		output	logic			o_ready,
		input	logic [DW-1:0]	i_data,
		output	logic			o_valid,
		input	logic			i_ready,
		output	logic [DW-1:0]	o_data
	);
    
    // Starting with skidbuffer signal - r_valid and r_data
    logic          r_valid;
    logic [DW-1:0] r_data;
    
    initial r_valid = 0;
    always_ff @(i_clk) begin
       // Reset Condition 
       if (i_reset) r_valid <= 0;
    
       // When previous stage is sending data and next stage is stalled i.e. the i_ready just became 0 and i_valid,o_ready, o_valid = 1 - In this case the data is stored in the current stage skid buffer
       else if ((i_valid && o_ready) && (o_valid && !i_ready)) r_valid <= 1;
    
       // The data from internal buffer is passed to next stage once i_ready = 1
       else if (i_ready) r_valid <= 0;
    end
    
    
    // r_data logic needs to consider the state of r_valid for the OPT_LOWPOWER property
    initial r_data = 0;
    always_ff @(i_clk) begin
        // Reset Condition
        if (OPT_LOWPOWER && i_reset) r_data <= 0;
    
        // When the outgoing is not stalled(i.e. i_ready = 1) the r_data again would be set to 0 - 
        // Using o_valid here since assuming the case where i_ready = 0 then we need to store the input data in r_data only if the current data in the stage was valid if it was not valid we dont need to hold anything
        else if (OPT_LOWPOWER && (!o_valid || i_ready)) r_data <= 0;
    
        // Condition for transferring i_data to r_data - If skipping above condition that means o_valid && !i_ready = 1 so we need to check for the previous stage conditions
        else if ((!OPT_LOWPOWER || !OPT_OUTREG || i_valid) && o_ready) r_data <= i_data;
    
    end
    
    
    // o_ready signal is directly not of the r_valid signal - Anytime data stored in skid buffer the current stage tells prev stage that pipeline is stalled
    always_comb begin
        o_ready = !r_valid;
    end
    
    
    // Logic for output valid and data ports
    if (OPT_OUTREG)
    begin : REG_OUTPUT
    
        // o_valid
        logic ro_valid;
    
        initial ro_valid = 0;
        always_ff @(i_clk) begin
            if (i_reset) ro_valid <= 0;
            else if (!o_valid || i_ready) ro_valid <= (i_valid || r_valid);
        end
    
        assign o_valid = ro_valid;
    
        // o_data
    	initial o_data = 0;
    	always_ff @(i_clk) begin
    	    if (OPT_LOWPOWER && i_reset) o_data <= 0;
            else if (!o_valid || i_ready) begin
        		if (r_valid)
        			o_data <= r_data;
        		else if (!OPT_LOWPOWER || i_valid)
        			o_data <= i_data;
        		else
        			o_data <= 0;
    	    end
        end
    
    end else 
    begin : COMB_OUTPUT
    
        // o_valid - Unregistered case we would want o_valid to be high if reset not issued and if either i_valid or r_valid is high
        always_comb begin
            o_valid = !i_reset && (i_valid || r_valid);
        end
    
        // o_data
        always_comb begin
            // If value stored in skid buffer
            if (r_valid) o_data = r_data;
            // Pass input data to output data if input valid high and r_valid would be low
            else if (!OPT_LOWPOWER || i_valid) o_data = i_data;
            // In another condition the output data is zero to save power
            else o_data = 0;
        end
    
    end

endmodule