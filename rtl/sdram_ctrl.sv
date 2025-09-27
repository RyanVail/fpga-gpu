`include "sdram.svh"

module sdram_ctrl #(
    parameter bank_addr_width = 2,
    parameter row_addr_width = 13,
    parameter col_addr_width = 9,
    parameter bus_width = 16,

    parameter addr_width,
    parameter refresh_interval,
    parameter init_cycles,
    parameter t_cas_lat,
    parameter t_rc_lat,
    parameter t_ras_lat,
    parameter t_rp_lat
) (
    input clk_i,
    output enabled_o,

    input [addr_width-1:0] addr_i,

    output data_ready_o,

    input r_valid_i,
    input w_valid_i,

    output r_valid_o,

    output [bus_width-1:0] read_o,
    input [bus_width-1:0] write_i,

    // External SDRAM interface.
	output clk_en_o,
    output cs_o,
    output ras_o,
    output cas_o,
    output we_o,

    output [bank_addr_width-1:0] bank_o,
    output [row_addr_width-1:0] sdram_a_o,
    inout [bus_width-1:0] dq_io
);
    assign clk_en_o = 1;

    logic [bank_addr_width-1:0] bank;
    assign bank_o = bank;

    logic [row_addr_width-1:0] sdram_a;
    assign sdram_a_o = sdram_a;

    assign enabled_o = init_state == 15;

    logic [$clog2(init_cycles)-1:0] init_cnt;
    logic [3:0] init_state;

    logic [2:0] state;

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

    sdram_cmd_e cmd;
    assign {ras_o, cas_o, we_o} = cmd;

    initial begin
        cmd = SDRAM_CMD_NOP;
        init_cnt = 1;
        init_state = 0;
        state = 0;
    end

    assign cs_o = 0;

    typedef struct packed {
        logic [bank_addr_width-1:0] bank;
        logic [row_addr_width-1:0] row;
        logic [col_addr_width-1:0] col;
    } sdram_addr_s;

    sdram_addr_s sdram_addr;

    assign sdram_addr = addr_i;

    assign dq_io = (cmd == SDRAM_CMD_WRITE) ? write_data : bus_width ** {1'bZ};
    assign read_o = dq_io;

    // The bank and column currently being operated on.
    logic [bank_addr_width-1:0] bank_sel;
    logic [col_addr_width-1:0] col_sel;
    logic [bus_width-1:0] write_data;

    logic reading;
    logic reading_issued;

    assign r_valid_o = (cas_lat == 0) & reading_issued;

    assign data_ready_o = enabled_o
        && state == STATE_IDLE
        && !refreshing
        && rc_lat == 0
        && rp_lat == 0;

    localparam refresh_interval_val = refresh_interval[$clog2(refresh_interval)-1:0];
    logic [$clog2(refresh_interval)-1:0] refresh_lat;
    wire refreshing = refresh_lat < 16;

    localparam t_cas_lat_val = t_cas_lat[$clog2(t_cas_lat):0];
    logic [$clog2(t_cas_lat):0] cas_lat;

    localparam t_rc_lat_val = t_rc_lat[$clog2(t_rc_lat)-1:0] - 1;
    logic [$clog2(t_rc_lat)-1:0] rc_lat;

    localparam t_ras_lat_val = t_ras_lat[$clog2(t_ras_lat)-1:0] - 1;
    logic [$clog2(t_ras_lat)-1:0] ras_lat;

    localparam t_rp_lat_val = t_rp_lat[$clog2(t_rp_lat)-1:0] - 1;
    logic [$clog2(t_rp_lat)-1:0] rp_lat;

    initial begin
        refresh_lat = 0;
        cas_lat = 0;
        ras_lat = 0;
        rp_lat = 0;
    end

    // Managing latency timers.
    always_ff @(posedge clk_i) begin
        if (state == STATE_CLOSE) begin
            rp_lat <= t_rp_lat_val;
        end else begin
            if (rp_lat != 0) rp_lat <= rp_lat -1;
        end

        if (state == STATE_ACTIVE) begin
            ras_lat <= t_ras_lat_val;
        end else begin
            if (ras_lat != 0) ras_lat <= ras_lat -1;
        end

        if (state == STATE_READ_WRITE) begin
            cas_lat <= t_cas_lat_val;
        end else begin
            if (cas_lat != 0) cas_lat <= cas_lat -1;
        end

        if (state == STATE_IDLE && data_ready_o && (r_valid_i || w_valid_i)
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
    end

    always_ff @(posedge clk_i) begin
        casez (init_state)
            0: begin
                cmd <= SDRAM_CMD_NOP;
                init_cnt <= init_cnt + 1;
                init_state <= (init_cnt == 0) ? 1 : 0;
            end 1: begin
                cmd <= SDRAM_CMD_PRECHARGE;
                init_state <= 2;
                init_cnt <= 0;

                // Precharge all
                sdram_a[10] <= 1;
            end 2: begin
                cmd <= SDRAM_CMD_NOP;
                init_state <= 8;
                init_cnt <= 0;
            end 8: begin
                cmd <= SDRAM_CMD_REFRESH;
                init_state <= 3;
            end 3: begin
                cmd <= SDRAM_CMD_NOP;
                // TODO: Do this a better way.
                init_cnt <= init_cnt + 1;
                init_state <= init_cnt[4] ? 4 : 3;
            end 4: begin
                cmd <= SDRAM_CMD_REFRESH;
                init_state <= 5;
                init_cnt <= 0;
            end 5: begin
                cmd <= SDRAM_CMD_NOP;
                // TODO: Do this a better way.
                init_cnt <= init_cnt + 1;
                init_state <= init_cnt[4] ? 6 : 5;
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

        if (r_valid_i && data_ready_o) begin
            reading <= 1;
        end else if (state == STATE_READ_WRITE) begin
            reading <= 0;
            reading_issued <= reading;
        end

        if (enabled_o) casez (state)
            STATE_IDLE: begin
                if (refresh_lat == 0) begin
                    cmd <= SDRAM_CMD_PRECHARGE;
                    sdram_a[10] <= 1;

                    state <= STATE_REFRESH_PRECHARGE;
                end else if ((r_valid_i || w_valid_i) && data_ready_o) begin
                    cmd <= SDRAM_CMD_ACTIVE;
                    bank <= sdram_addr.bank;
                    sdram_a <= sdram_addr.row;

                    bank_sel <= sdram_addr.bank;
                    col_sel <= sdram_addr.col;

                    write_data <= write_i;

                    state <= STATE_ACTIVE;
                end else begin
                    cmd <= SDRAM_CMD_NOP;
                end
            end STATE_REFRESH_PRECHARGE: begin
                cmd <= (t_rp_lat == 0) ? SDRAM_CMD_REFRESH : SDRAM_CMD_NOP;
                state <= (t_rp_lat == 0) ? STATE_IDLE : STATE_REFRESH;
            end STATE_REFRESH: begin
                cmd <= SDRAM_CMD_NOP;
                state <= (refresh_lat == 0) ? STATE_IDLE : STATE_REFRESH;
            end STATE_ACTIVE: begin
                cmd <= SDRAM_CMD_NOP;

                state <= (rp_lat < 1) ? STATE_READ_WRITE : STATE_ACTIVE;
            end STATE_READ_WRITE: begin
                cmd <= reading ? SDRAM_CMD_READ : SDRAM_CMD_WRITE;
                bank <= bank_sel;
                sdram_a[col_addr_width-1:0] <= col_sel;

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
