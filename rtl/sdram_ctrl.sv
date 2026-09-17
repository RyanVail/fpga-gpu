`include "sdram.svh"

module sdram_ctrl #(
    parameter sdram_if_params p
) (
    input clk_i,

    sdram_ctrl_if.device ctrl_bus,
    sdram_if.controller bus
);
    assign bus.clk_en = 1;

    logic [p.bank_addr_width-1:0] bank;
    assign bus.bank = bank;

    logic [p.row_addr_width-1:0] sdram_a;
    assign bus.a = sdram_a;

    assign ctrl_bus.enabled = init_state == 15;

    localparam int init_cycles = $rtoi(
        $ceil(p.init_delay_ns / p.clk_cycle_ns)
    );

    logic [$clog2(init_cycles)-1:0] init_cnt = init_cycles[$clog2(init_cycles)-1:0];
    logic [3:0] init_state = 0;

    logic [2:0] state = 0;

    // Waiting for the next command to come through.
    localparam [2:0] STATE_IDLE = 0;

    // Activating a bank.
    localparam [2:0] STATE_ACTIVE = 1;

    // Closing a bank.
    localparam [2:0] STATE_CLOSE = 2;

    // Refreshing.
    localparam [2:0] STATE_REFRESH_PRECHARGE = 3;
    localparam [2:0] STATE_REFRESH = 4;

    localparam [2:0] STATE_READ_WRITE = 5;

    sdram_cmd_e cmd = SDRAM_CMD_NOP;
    assign {bus.ras, bus.cas, bus.we} = cmd;

    assign bus.cs = 0;

    typedef struct packed {
        logic [p.bank_addr_width-1:0] bank;
        logic [p.row_addr_width-1:0] row;
        logic [p.col_addr_width-1:0] col;
    } sdram_addr_s;

    sdram_addr_s sdram_addr;
    assign sdram_addr = ctrl_bus.addr;

    assign bus.dq = (cmd == SDRAM_CMD_WRITE)
        ? write_data
        : {p.bus_width{1'bZ}};

    assign ctrl_bus.read = bus.dq;

    // The bank and column currently being operated on.
    logic [p.bank_addr_width-1:0] bank_sel;
    logic [p.col_addr_width-1:0] col_sel;
    logic [p.bus_width-1:0] write_data;

    logic reading;
    logic reading_issued;

    assign ctrl_bus.r_valid = (cas_lat == 0) & reading_issued;

    assign ctrl_bus.can_req = ctrl_bus.enabled
        && state == STATE_IDLE
        && !refreshing
        && rc_lat == 0
        && rp_lat == 0;

    localparam cycles_per_sec = 1e9 / p.clk_cycle_ns;

    localparam refresh_interval = $rtoi(
        $ceil(cycles_per_sec / p.refreshes_per_sec)
    );

    localparam refresh_interval_val = refresh_interval[$clog2(refresh_interval)-1:0];
    logic [$clog2(refresh_interval)-1:0] refresh_lat = 0;
    wire refreshing = refresh_lat < 16;

    localparam t_cas_lat_val = p.t_cas_lat[$clog2(p.t_cas_lat):0];
    logic [$clog2(p.t_cas_lat):0] cas_lat = 0;

    localparam t_rc_lat_val = p.t_rc_lat[$clog2(p.t_rc_lat)-1:0] - 1;
    logic [$clog2(p.t_rc_lat)-1:0] rc_lat = 0;

    localparam t_ras_lat_val = p.t_ras_lat[$clog2(p.t_ras_lat)-1:0] - 1;
    logic [$clog2(p.t_ras_lat)-1:0] ras_lat = 0;

    localparam t_rp_lat_val = p.t_rp_lat[$clog2(p.t_rp_lat)-1:0] - 1;
    logic [$clog2(p.t_rp_lat)-1:0] rp_lat = 0;

    always_ff @(posedge clk_i) begin
        if (state == STATE_CLOSE
        || (refresh_lat == 0 && state == STATE_IDLE)) begin
            rp_lat <= t_rp_lat_val;
        end else begin
            if (rp_lat != 0) rp_lat <= rp_lat - 1;
        end

        if (state == STATE_ACTIVE) begin
            ras_lat <= t_ras_lat_val;
        end else begin
            if (ras_lat != 0) ras_lat <= ras_lat - 1;
        end

        if (state == STATE_READ_WRITE) begin
            cas_lat <= t_cas_lat_val;
        end else begin
            if (cas_lat != 0) cas_lat <= cas_lat - 1;
        end

        if (state == STATE_IDLE
        && ctrl_bus.can_req
        && (ctrl_bus.r_req || ctrl_bus.w_req)
            || state == STATE_REFRESH_PRECHARGE || state == STATE_REFRESH)
        begin
            rc_lat <= t_rc_lat_val;
        end else begin
            if (rc_lat != 0) rc_lat <= rc_lat - 1;
        end

        if (state == STATE_REFRESH) begin
            refresh_lat <= refresh_interval_val;
        end else begin
            if (refresh_lat != 0) refresh_lat <= refresh_lat - 1;
        end

        casez (init_state)
            0: begin
                cmd <= SDRAM_CMD_NOP;
                init_cnt <= init_cnt - 1;
                init_state <= (init_cnt == 0) ? 1 : 0;
            end 1: begin
                cmd <= SDRAM_CMD_PRECHARGE;
                init_state <= 2;

                // Precharge all
                sdram_a[10] <= 1;
            end 2: begin
                cmd <= SDRAM_CMD_NOP;
                init_state <= 8;
            end 8: begin
                cmd <= SDRAM_CMD_REFRESH;
                init_state <= 3;
                init_cnt <= t_rp_lat_val;
            end 3: begin
                cmd <= SDRAM_CMD_NOP;
                init_cnt <= init_cnt - 1;
                init_state <= (init_cnt == 0) ? 4 : 3;
            end 4: begin
                cmd <= SDRAM_CMD_REFRESH;
                init_state <= 5;
                init_cnt <= t_rp_lat_val;
            end 5: begin
                cmd <= SDRAM_CMD_NOP;
                init_state <= (init_cnt == 0) ? 6 : 5;
                init_cnt <= init_cnt - 1;
            end 6: begin
                cmd <= SDRAM_CMD_LOADMODE;

                // Reserved
                bank <= 0;
                sdram_a[12:10] <= 0;

                // Write burst mode = single location
                sdram_a[9] <= 1;

                // Normal operating mode
                sdram_a[8:7] <= 0;

                // Two cycle latency
                sdram_a[6:4] <= 3'b010;

                // Sequential burst
                sdram_a[3] <= 0;

                // Burst length = 1
                sdram_a[2:0] <= 0;

                init_state <= 7;
            end 7: begin
                cmd <= SDRAM_CMD_NOP;
                init_state <= 9;
            end 9: begin
                cmd <= SDRAM_CMD_NOP;
                init_state <= 15;
            end default: begin
                init_state <= 15;
            end
        endcase

        if (ctrl_bus.r_req && ctrl_bus.can_req) begin
            reading <= 1;
        end else if (state == STATE_READ_WRITE) begin
            reading <= 0;
            reading_issued <= reading;
        end else if (ctrl_bus.r_valid) begin
            reading_issued <= 0;
        end

        if (ctrl_bus.enabled) casez (state)
            STATE_IDLE: begin
                if (refresh_lat == 0) begin
                    cmd <= SDRAM_CMD_PRECHARGE;
                    sdram_a[10] <= 1;

                    state <= STATE_REFRESH_PRECHARGE;
                end else if ((ctrl_bus.r_req || ctrl_bus.w_req)
                && ctrl_bus.can_req) begin
                    cmd <= SDRAM_CMD_ACTIVE;
                    bank <= sdram_addr.bank;
                    sdram_a <= sdram_addr.row;

                    bank_sel <= sdram_addr.bank;
                    col_sel <= sdram_addr.col;

                    write_data <= ctrl_bus.write;

                    state <= STATE_ACTIVE;
                end else begin
                    cmd <= SDRAM_CMD_NOP;
                end
            end STATE_REFRESH_PRECHARGE: begin
                cmd <= (rp_lat == 0) ? SDRAM_CMD_REFRESH : SDRAM_CMD_NOP;
                state <= (rp_lat == 0)
                    ? STATE_REFRESH
                    : STATE_REFRESH_PRECHARGE;
            end STATE_REFRESH: begin
                cmd <= SDRAM_CMD_NOP;
                state <= (refresh_lat == 0) ? STATE_IDLE : STATE_REFRESH;
            end STATE_ACTIVE: begin
                cmd <= SDRAM_CMD_NOP;

                state <= (rp_lat < 1) ? STATE_READ_WRITE : STATE_ACTIVE;
            end STATE_READ_WRITE: begin
                cmd <= reading ? SDRAM_CMD_READ : SDRAM_CMD_WRITE;
                bank <= bank_sel;
                sdram_a[p.col_addr_width-1:0] <= col_sel;

                state <= STATE_CLOSE;
            end STATE_CLOSE: begin
                cmd <= (ras_lat == 0 && cas_lat == 0) ? SDRAM_CMD_PRECHARGE : SDRAM_CMD_NOP;

                state <= (ras_lat == 0 && cas_lat == 0) ? STATE_IDLE : STATE_CLOSE;
            end default begin
                $fatal(1, "unreachable: %d", state);
            end
        endcase
    end
endmodule
