`include "utils.svh"
`include "sdram.svh"

typedef enum bit {
    BURST_MODE_SEQUENTIAL = 0,
    BURST_MODE_INTERLEAVED = 1
} sdram_burst_mode;

typedef enum bit [2:0] {
    BURST_LEN_1,
    BURST_LEN_2,
    BURST_LEN_4,
    BURST_LEN_8,
    BURST_LEN_PAGE
} sdram_burst_len;

module sdram_sim #(
    parameter sdram_if_params p
) (
    input clk_i,

    sdram_if.device bus
);
    localparam int init_delay_cycles = $rtoi(
        $ceil(p.init_delay_ns / p.clk_cycle_ns)
    );

    logic [$clog2(init_delay_cycles)-1:0] init_cycles = 0;
    logic [2:0] init_state = 0;

    // TODO: This currently only supports DRAMs with 1 cycle tCCDs.
    initial assert(p.t_ccd_lat == 1);

    typedef logic [p.col_width-1:0][p.bus_width-1:0] row_s;

    row_s [p.rows-1:0] data[p.banks];

    row_s [p.banks-1:0] loaded;
    logic [p.banks-1:0][p.row_addr_width-1:0] loaded_rows;
    logic [p.banks-1:0] is_loaded = 0;

    wire [p.row_addr_width-1:0] row_i = bus.a;
    wire [p.col_addr_width-1:0] col_i = bus.a[p.col_addr_width-1:0];

    wire precharge_all = bus.a[10];
    wire auto_precharge = bus.a[10];

    localparam t_ref_lat_val = t_rc_lat_val;
    logic [$clog2(p.t_rc_lat)-1:0] ref_lat = 0;

    localparam t_mrd_lat_val = p.t_mrd_lat[$clog2(p.t_mrd_lat)-1:0] - 1;
    logic [$clog2(p.t_mrd_lat)-1:0] mrd_lat = 0;

    localparam t_rcd_lat_val = p.t_rcd_lat[$clog2(p.t_rcd_lat)-1:0] - 1;
    logic [p.banks-1:0][$clog2(p.t_rcd_lat)-1:0] rcd_lats = 0;

    localparam t_rc_lat_val = p.t_rc_lat[$clog2(p.t_rc_lat)-1:0] - 1;
    logic [p.banks-1:0][$clog2(p.t_rc_lat)-1:0] rc_lats = 0;

    localparam t_ras_lat_val = p.t_ras_lat[$clog2(p.t_ras_lat)-1:0] - 1;
    logic [p.banks-1:0][$clog2(p.t_ras_lat)-1:0] ras_lats = 0;

    localparam t_rp_lat_val = p.t_rp_lat[$clog2(p.t_rp_lat)-1:0] - 1;
    logic [p.banks-1:0][$clog2(p.t_rp_lat)-1:0] rp_lats = 0;

    typedef struct packed {
        logic valid;
        logic [p.bank_addr_width-1:0] bank;
        logic [p.col_addr_width-1:0] col;
    } read_s;

    // The read commands in progress.
    read_s [p.t_cas_lat-1:0] read_fifo;

    read_s this_read;
    assign this_read = read_fifo[0];

    assign bus.dq = (this_read.valid)
        ? loaded[this_read.bank][this_read.col]
        : {p.bus_width{1'bZ}};

    typedef struct packed {
        logic valid;
        logic [p.bank_addr_width-1:0] bank;
        logic [p.col_addr_width-1:0] col;
        logic [p.bus_width-1:0] data;
    } write_s;

    // The write commands in progress.
    write_s [p.t_cas_lat-1:0] write_fifo;

    write_s this_write;
    assign this_write = write_fifo[0];

    sdram_cmd_e cmd;
    assign cmd = sdram_cmd_e'({bus.ras, bus.cas, bus.we});

    sdram_burst_mode mode_burst;
    sdram_burst_len mode_burst_len;
    logic using_burst;

    // TODO: The bus.cs command should be processed
    always_ff @(posedge clk_i) begin
        if (this_read.valid) begin
            `assertEqual(1, is_loaded[this_read.bank]);
        end

        read_fifo[p.t_cas_lat-2:0] <= read_fifo[p.t_cas_lat-1:1];
        read_fifo[p.t_cas_lat-1] <= 0;

        if (ref_lat != 0) ref_lat <= ref_lat - 1;
        if (mrd_lat != 0) mrd_lat <= mrd_lat - 1;

        for (int i = 0; i < p.banks; i=i+1) begin
            if (rcd_lats[i] != 0) rcd_lats[i] <= rcd_lats[i] - 1;
            if (rc_lats[i] != 0) rc_lats[i] <= rc_lats[i] - 1;
            if (ras_lats[i] != 0) ras_lats[i] <= ras_lats[i] - 1;
            if (rp_lats[i] != 0) rp_lats[i] <= rp_lats[i] - 1;
        end

        if (bus.clk_en) casez (init_state)
            0: begin
                init_cycles <= init_cycles + 1;
                init_state <= (init_cycles == init_cycles) ? 2 : 1;
            end 1: begin
                `assertEqual(SDRAM_CMD_NOP, cmd)
            end 2: begin
                if (cmd == SDRAM_CMD_PRECHARGE) begin
                    init_state <= 3;
                    `assertEqual(1, precharge_all);
                end else if (cmd != SDRAM_CMD_NOP) begin
                    $error("expected precharge");
                end
            end 3: begin
                if (cmd == SDRAM_CMD_REFRESH) begin
                    init_state <= 4;
                end else if (cmd != SDRAM_CMD_NOP) begin
                    $error("expected refresh found: %d", cmd);
                end
            end 4: begin
                if (cmd == SDRAM_CMD_REFRESH) begin
                    init_state <= 5;
                end else if (cmd != SDRAM_CMD_NOP) begin
                    $error("expected refresh found: %d", cmd);
                end
            end 5: begin
                if (cmd == SDRAM_CMD_LOADMODE) begin
                    init_state <= 6;
                end else if (cmd != SDRAM_CMD_NOP) begin
                    $error("expected loadmode found: %d", cmd);
                end
            end default: begin
            end
        endcase

        if (this_write.valid) begin
            `assertEqual(1, is_loaded[this_write.bank]);
            loaded[this_write.bank][this_write.col] <= this_write.data;
        end

        write_fifo[p.t_cas_lat-2:0] <= write_fifo[p.t_cas_lat-1:1];
        write_fifo[p.t_cas_lat-1] <= 0;

        if (bus.clk_en & !bus.cs) casez (cmd)
            SDRAM_CMD_LOADMODE: begin
                `assertEqual(0, mrd_lat);
                `assertEqual(0, ref_lat);

                // Reserved
                `assertEqual(0, bus.bank);
                `assertEqual(0, bus.a[12:10]);

                // Write burst mode
                using_burst <= bus.a[9];

                // Operating mode
                `assertEqual(0, bus.a[8:7]);

                // Latency
                casez (bus.a[6:4])
                    3'b010: `assertEqual(p.t_rcd_lat, 2)
                    3'b011: `assertEqual(p.t_rcd_lat, 3)
                    default: $error("Reserved latency");
                endcase

                // Sequential burst
                mode_burst <= sdram_burst_mode'(bus.a[3]);

                // Burst length
                casez (bus.a[2:0])
                    3'b000: mode_burst_len <= BURST_LEN_1;
                    3'b001: mode_burst_len <= BURST_LEN_2;
                    3'b010: mode_burst_len <= BURST_LEN_4;
                    3'b011: mode_burst_len <= BURST_LEN_8;
                    3'b111: mode_burst_len <= BURST_LEN_PAGE;
                    default: $error("Reserved burst length");
                endcase

                // TODO: Implement these.
                `assertEqual(mode_burst, BURST_MODE_SEQUENTIAL);
                `assertEqual(mode_burst_len, BURST_LEN_1);
                `assertEqual(using_burst, 0);

                mrd_lat <= t_mrd_lat_val;
            // TODO: This should have errors when there's no refreshing.
            end SDRAM_CMD_REFRESH: begin
                `assertEqual(0, ref_lat);
                `assertEqual(0, mrd_lat);
                `assertEqual(0, rp_lats);

                // Can only refresh when all banks are idle.
                `assertEqual(0, is_loaded);

                ref_lat <= t_ref_lat_val;
            end SDRAM_CMD_PRECHARGE: begin
                `assertEqual(0, ref_lat);
                `assertEqual(0, mrd_lat);
                rp_lats[bus.bank] <= t_rp_lat_val;

                if (precharge_all) begin
                    for (int i = 0; i < p.banks; i=i+1) begin
                        if (is_loaded[i]) begin
                            `assertEqual(0, ras_lats[i]);

                            rp_lats[i] <= t_rp_lat_val;

                            is_loaded[i] <= 0;
                            data[i][loaded_rows[i]] <= loaded[i];
                        end
                    end
                end else if (is_loaded[bus.bank]) begin
                    `assertEqual(0, ras_lats[bus.bank]);

                    is_loaded[bus.bank] <= 0;
                    data[bus.bank][loaded_rows[bus.bank]] <= loaded[bus.bank];
                end
            end SDRAM_CMD_ACTIVE: begin
                `assertEqual(0, ref_lat);
                `assertEqual(0, mrd_lat);
                `assertEqual(0, rc_lats[bus.bank]);
                `assertEqual(0, rp_lats[bus.bank]);
                `assertEqual(0, is_loaded[bus.bank]);

                rc_lats[bus.bank] <= t_rc_lat_val;
                rcd_lats[bus.bank] <= t_rcd_lat_val;
                ras_lats[bus.bank] <= t_ras_lat_val;

                is_loaded[bus.bank] <= 1;

                loaded[bus.bank] <= data[bus.bank][row_i];
                loaded_rows[bus.bank] <= row_i;
            end SDRAM_CMD_WRITE: begin
                `assertEqual(0, ref_lat);
                `assertEqual(0, mrd_lat);
                `assertEqual(0, rcd_lats[bus.bank]);

                write_fifo[p.t_cas_lat-1] <= '{
                    valid: 1,
                    bank: bus.bank,
                    col: col_i,
                    data: bus.dq
                };

                // TODO: Really this should factor in tDPL.
                if (auto_precharge) begin
                    rp_lats[bus.bank] <= t_rp_lat_val + 1;
                end
            end SDRAM_CMD_READ: begin
                `assertEqual(0, ref_lat);
                `assertEqual(0, mrd_lat);
                `assertEqual(0, rcd_lats[bus.bank]);

                read_fifo[p.t_cas_lat-1] <= '{
                    valid: 1,
                    bank: bus.bank,
                    col: col_i
                };

                if (auto_precharge) begin
                    rp_lats[bus.bank] <= t_rp_lat_val + 1;
                end
            end default: begin end
        endcase
    end
endmodule
