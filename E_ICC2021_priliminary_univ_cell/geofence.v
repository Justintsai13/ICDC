module geofence ( clk,reset,X,Y,valid,is_inside);
    input clk;
    input reset;
    input [9:0] X;
    input [9:0] Y;
    output reg valid;
    output reg is_inside;

    localparam S_RECEIVER = 3'd0;
    localparam S_OBJECT = 3'd1;
    localparam S_SORT = 3'd2;
    localparam S_CONVEX = 3'd3;
    localparam S_OUT = 3'd4;

    reg [2:0] state, next_state;
    reg [2:0] cnt_r, cnt_w;
    reg [1:0] sort_cnt_r, sort_cnt_w;
    reg [9:0] fx[0:5], fy[0:5], fx_w[0:5], fy_w[0:5], x, y;

    integer i;
    
    reg signed [10:0] Ax, Ay, Bx, By;
    wire signed[21:0] AxBy, BxAy;
    wire yes'
    reg sign[0:5];
    
    assign AxBy = Ax * By;
    assign BxAy = Bx * Ay;
    assign yes = (AxBy > BxAy);

    // Ax Ay Bx By
    always @(*) begin
        case (state)
            S_SORT: begin
                Ax = {1'b0, fx[cnt_r]} - {1'b0, fx[0]};
                Ay = {1'b0, fy[cnt_r]} - {1'b0, fy[0]};
                Bx = {1'b0, fx[cnt_r + 3'd1]} - {1'b0, fx[0]};
                By = {1'b0, fy[cnt_r + 3'd1]} - {1'b0, fy[0]};
            end
            S_CONVEX: begin
                Ax = {1'b0, fx[cnt_r]} - {1'b0, x};
                Ay = {1'b0, fy[cnt_r]} - {1'b0, y};
                Bx = {1'b0, fx[(cnt_r == 3'd5)? 3'd0 : cnt_r + 3'd1]} - {1'b0, fx[cnt_r]};
                By = {1'b0, fy[(cnt_r == 3'd5)? 3'd0 : cnt_r + 3'd1]} - {1'b0, fy[cnt_r]};
            end
        endcase
    end

    // receiver
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 0;
            y <= 0;
        end else if (state == S_RECEIVER) begin
            x <= X;
            y <= Y;
        end
    end

    // fence
    always @(*) begin
        fx_w = fx;
        fy_w = fy;
        if (state == S_OBJECT) begin
            fx_w[cnt_r] = X;
            fy_w[cnt_r] = Y;
        end else if (state == S_SORT) begin
            if (yes) begin
                fx_w[cnt_r] = fx_r[cnt_r + 3'd1];
                fy_w[cnt_r] = fy_r[cnt_r + 3'd1];
                fx_w[cnt_r + 3'd1] = fx_r[cnt_r];
                fy_w[cnt_r + 3'd1] = fy_r[cnt_r];
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 6; i = i + 1) begin
                fx[i] <= 0;
                fy[i] <= 0;
            end
        end else begin
            for (i = 0; i < 6; i = i + 1) begin
                fx[i] <= fx_w[i];
                fy[i] <= fy_w[i];
            end
        end
    end

    // inside
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for(i = 0; i < 6; i = i + 1) begin
                sign[i] <= 1'd0;
            end
        end
        else if (state == S_CONVEX) begin
            if (yes) sign[cnt_r] <= 1'd1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) is_inside <= 1'd0;
        else if (state == S_OUT) begin
            is_inside <= (((sign[0] == 1'd0) && (sign[1] == 1'd0) && (sign[2] == 1'd0) && (sign[3] == 1'd0) && (sign[4] == 1'd0) && (sign[5] == 1'd0)) || ((sign[0] == 1'd1) && (sign[1] == 1'd1) && (sign[2] == 1'd1) && (sign[3] == 1'd1) && (sign[4] == 1'd1) && (sign[5] == 1'd1))) ? 1'd1 : 1'd0;
        end else is_inside <= 1'd0;
    end

    // counter
    always @(*) begin
        cnt_w = cnt_r;
        case (state) 
            S_OBJECT: begin
                cnt_w = (cnt_r == 3'd5) ? 3'd1 : cnt_r + 3'd1;
            end
            S_SORT: begin
                if (sort_cnt_r == 2'd3) cnt_w = (cnt_r == 3'd4) ? 3'd1 : cnt_r + 3'd1;
                else cnt_w = (cnt_r == 3'd4) ? 3'd1 : cnt_r + 3'd1;
            end
            S_CONVEX: begin
                cnt_w = (cnt_r == 3'd5) ? 3'd0 : cnt_r + 3'd1;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) cnt_r <= 0;
        else cnt_r <= cnt_w;
    end

    always @(*) begin
        sort_cnt_w = sort_cnt_r;
        if ((state == S_SORT) && (cnt_r == 3'd4)) begin
            sort_cnt_w = sort_cnt_r + 2'd1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) sort_cnt_r <= 0;
        else sort_cnt_r <= sort_cnt_w;
    end

    // valid
    always @(posedge clk or posedge reset) begin
        if (reset) valid <= 1'd0;
        else if (state == S_OUT) valid <= 1'd1;
        else valid <= 1'd0;
    end

    // fsm 
    always @(*) begin
        next_state = state;
        case (state)
            S_RECEIVER: next_state = S_OBJECT;
            S_OBJECT: begin
                if (cnt_r == 3'd5) next_state = S_SORT;
            end
            S_SORT: begin
                if ((sort_cnt_r == 2'd3) && (cnt_r == 3'd4)) next_state = S_CONVEX;
            end
            S_CONVEX: begin
                if (cnt_r == 3'd5) next_state = S_OUT;
            end
            S_OUT: next_state = S_RECEIVER;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) state <= S_RECEIVER;
        else state <= next_state;
    end


endmodule