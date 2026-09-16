module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tx_start,
    input  wire [7:0]  data_in,
    input  wire        parity_en,     // 1 = enable parity
    input  wire        even_parity,   // 1 = even, 0 = odd
    output reg         tx,
    output reg         tx_busy
);

    // State machine states
    localparam IDLE   = 3'd0,
               START  = 3'd1,
               DATA   = 3'd2,
               PARITY = 3'd3,
               STOP   = 3'd4;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg       parity_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx        <= 1'b1;  // idle is high
            tx_busy   <= 1'b0;
            shift_reg <= 8'd0;
            bit_cnt   <= 4'd0;
            parity_bit <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= data_in;
                        bit_cnt <= 4'd0;
                        parity_bit <= (even_parity) ? (^data_in) : ~(^data_in);
                        tx_busy <= 1'b1;
                        state <= START;
                    end
                end

                START: begin
                    tx <= 1'b0; // start bit
                    state <= DATA;
                end

                DATA: begin
                    tx <= shift_reg[7];             //FIX_ME::convert to 0 to fix
                    shift_reg <= shift_reg << 1;    //FIX_ME::convert to >> to fix  
                    bit_cnt <= bit_cnt + 1;  
                    if (bit_cnt == 4'd7) begin
                        if (parity_en)
                            state <= PARITY;
                        else
                            state <= STOP;
                    end
                end

                PARITY: begin
                    tx <= parity_bit;
                    state <= STOP;
                end

                STOP: begin
                    tx <= 1'b1; // stop bit (always 1)
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule