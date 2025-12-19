module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output IROM_rd;
output [5:0] IROM_A;
output IRAM_valid;
output [7:0] IRAM_D;
output [5:0] IRAM_A;
output busy;
output done;

localparam S_LOAD = 0;
localparam S_CMD = 1;
localparam S_WRITE = 2;

localparam WRITE = 4'd0;
localparam UP = 4'd1;
localparam DOWN = 4'd2;
localparam LEFT = 4'd3;
localparam RIGHT = 4'd4;
localparam MAX = 4'd5;
localparam MIN = 4'd6;
localparam AVG = 4'd7;
localparam CCW = 4'd8;
localparam CW = 4'd9;
localparam MX = 4'd10;
localparam MY = 4'd11;
integer i;

reg [1:0] state_r, state_w;
reg [5:0] pivot_r, pivot_w;
reg [7:0] data_r[0:63], data_w[0:63];
reg [5:0] cnt_r, cnt_w;
reg busy_r, busy_w, done_r, done_w, IROM_rd_r, IROM_rd_w, IRAM_valid_r, IRAM_valid_w;
wire [5:0] p1, p2, p3;
wire [7:0] max1, max2, max, min1, min2, min, avg;
wire [9:0] avg_temp;

assign busy = busy_r;
assign done = done_r;
assign IROM_rd = IROM_rd_r;
assign IRAM_valid = IRAM_valid_r;
assign IROM_A = cnt_r;
assign IRAM_A = cnt_r;
assign IRAM_D = data_r[cnt_r];
assign p1 = pivot_r + 6'd1;
assign p2 = pivot_r + 6'd8;
assign p3 = pivot_r + 6'd9;
assign avg_temp = data_r[pivot_r] + data_r[p1] + data_r[p2] + data_r[p3];
assign avg = avg_temp >> 2;
assign max1 = (data_r[pivot_r] > data_r[p1]) ? data_r[pivot_r] : data_r[p1];
assign max2 = (max1 > data_r[p2]) ? max1 : data_r[p2];
assign max = (max2 > data_r[p3]) ? max2 : data_r[p3];
assign min1 = (data_r[pivot_r] < data_r[p1]) ? data_r[pivot_r] : data_r[p1];
assign min2 = (min1 < data_r[p2]) ? min1 : data_r[p2];
assign min = (min2 < data_r[p3]) ? min2 : data_r[p3];



// data pivot cmd
always @(*) begin
    for (i = 0; i < 64; i = i + 1) data_w[i] = data_r[i];
    pivot_w = pivot_r;
    if (state_r == S_LOAD) begin
        data_w[cnt_r] = IROM_Q;
    end
    else if (cmd_valid) begin
        case (cmd)
            UP: begin
                pivot_w = (pivot_r[5:3] == 3'd0) ? pivot_r : pivot_r - 8;
            end
            DOWN: begin
                pivot_w = (pivot_r[5:3] == 3'd6) ? pivot_r : pivot_r + 8;
            end
            LEFT: begin
                pivot_w = (pivot_r[2:0] == 3'd0) ? pivot_r : pivot_r - 1;
            end
            RIGHT: begin
                pivot_w = (pivot_r[2:0] == 3'd6) ? pivot_r : pivot_r + 1;
            end
            MAX: begin
                data_w[pivot_r] = max;
                data_w[p1] = max;
                data_w[p2] = max;
                data_w[p3] = max;
            end
            MIN: begin
                data_w[pivot_r] = min;
                data_w[p1] = min;
                data_w[p2] = min;
                data_w[p3] = min;            
            end
            AVG: begin
                data_w[pivot_r] = avg;
                data_w[p1] = avg;
                data_w[p2] = avg;
                data_w[p3] = avg;            
            end
            CCW: begin
                data_w[pivot_r] = data_r[p1];
                data_w[p1] = data_r[p3];
                data_w[p2] = data_r[pivot_r];
                data_w[p3] = data_r[p2];            
            end
            CW: begin
                data_w[pivot_r] = data_r[p2];
                data_w[p1] = data_r[pivot_r];
                data_w[p2] = data_r[p3];
                data_w[p3] = data_r[p1];            
            end
            MX: begin
                data_w[pivot_r] = data_r[p2];
                data_w[p1] = data_r[p3];
                data_w[p2] = data_r[pivot_r];
                data_w[p3] = data_r[p1];            
            end
            MY: begin
                data_w[pivot_r] = data_r[p1];
                data_w[p1] = data_r[pivot_r];
                data_w[p2] = data_r[p3];
                data_w[p3] = data_r[p2];            
            end
        endcase
    end
end

// output
always @(*) begin
    busy_w = busy_r;
    done_w = done_r;
    IROM_rd_w = IROM_rd_r;
    IRAM_valid_w = IRAM_valid_r;
    case (state_r) 
        S_LOAD: begin
            busy_w = 1'd1;
            IROM_rd_w = 1'd1;
            if (cnt_r == 6'd63) begin
                busy_w = 1'd0;
                IROM_rd_w = 1'd0;
            end
        end
        S_CMD: begin
            if (cmd_valid && (cmd == 4'd0)) begin
                IRAM_valid_w = 1'd1;
            end
        end
        S_WRITE: begin
            if (cnt_r == 6'd63) begin
                IRAM_valid_w = 1'd0;
                busy_w = 1'd0;
                done_w = 1'd1;
            end
        end
    endcase
end

// cnt
always @(*) begin
    cnt_w = cnt_r;
    case (state_r)
        S_LOAD: cnt_w = (cnt_r == 6'd63) ? 6'd0 : cnt_r + 6'd1;
        S_WRITE: cnt_w = (cnt_r == 6'd63) ? 6'd0 : cnt_r + 6'd1;
    endcase
end

// FSM
always @(*) begin
    state_w = state_r;
    case (state_r) 
        S_LOAD: begin
            if (cnt_r == 6'd63) begin
                state_w = S_CMD;
            end
            else state_w = S_LOAD;
        end
        S_CMD: begin
            if (cmd_valid && (cmd == 4'd0)) state_w = S_WRITE;
        end
    endcase
end 

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state_r <= S_LOAD;
        cnt_r <= 0;
        pivot_r <= 6'h1b;
        busy_r <= 1'd1;
        done_r <= 1'd0;
        IROM_rd_r <= 1'd1;
        IRAM_valid_r <= 1'd0;
        for (i = 0; i < 64; i = i + 1) data_r[i] <= 8'd0;
    end
    else begin
        state_r <= state_w;
        cnt_r <= cnt_w;
        pivot_r <= pivot_w;
        busy_r <= busy_w;
        done_r <= done_w;
        IROM_rd_r <= IROM_rd_w;
        IRAM_valid_r <= IRAM_valid_w;
        for (i = 0; i < 64; i = i + 1) data_r[i] <= data_w[i];
    end
end

endmodule
