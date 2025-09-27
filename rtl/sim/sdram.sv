`include "utils.sv"
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

/* verilator lint_off DECLFILENAME */
module sdram_sim #(
/* verilator lint_on DECLFILENAME */
    parameter banks = 4,
    parameter rows = 8192,
    parameter bus_width = 16,

    // The number of data entries within a column.
    parameter col_width = 512,

    parameter bank_addr_width = 2,
    parameter row_addr_width = 13,
    parameter col_addr_width = 9,

    // The number of clock cycles after *clk_en_i* is high before this SDRAM
    // chip is ready to be issued commands.
    parameter init_delay_cycles,

    // The clock cycles from a read / write command being issued to data being
    // written / read.
    parameter t_cas_lat,

    // The clock cycles after when a read / write issued before another
    // read / write command can be issued.
    parameter t_ccd_lat,

    // The clock cycles after an active command before a read / write command
    // can be issued to the same bank.
    parameter t_rcd_lat,

    // The clock cycles after an active command before another active command
    // can be issued to the same bank.
    parameter t_rc_lat,

    // The clock cycles after an active command before a precharge command can
    // be issued to the same bank.
    parameter t_ras_lat,

    // The clock cycles after an precharge command before a active command can
    // be issued to the same bank.
    parameter t_rp_lat,

    // The clock cycles after a load command before another command can be
    // issued.
    parameter t_mrd_lat
) (
    input clk_i,
    input clk_en_i,

    input cs_i,
    input ras_i,
    input cas_i,
    input we_i,

    input [bank_addr_width-1:0] bank_i,
    input [row_addr_width-1:0] sdram_a_i,

    inout [bus_width-1:0] dq_io
);
    logic [$clog2(init_delay_cycles)-1:0] init_cycles;
    logic [2:0] init_state;
    initial begin
        // TODO: This currently only supports DRAMs with 1 cycle tCCDs.
        assert(t_ccd_lat == 1);

        init_cycles = 0;
        init_state = 0;
    end

    always_ff @(posedge clk_i) if (clk_en_i)
        casez (init_state)
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
                $fatal(1, "expected precharge");
            end
        end 3: begin
            if (cmd == SDRAM_CMD_REFRESH) begin
                init_state <= 4;
            end else if (cmd != SDRAM_CMD_NOP) begin
                $fatal(1, "expected refresh found: %d", cmd);
            end
        end 4: begin
            if (cmd == SDRAM_CMD_REFRESH) begin
                init_state <= 5;
            end else if (cmd != SDRAM_CMD_NOP) begin
                $fatal(1, "expected refresh found: %d", cmd);
            end
        end 5: begin
            if (cmd == SDRAM_CMD_LOADMODE) begin
                init_state <= 6;
            end else if (cmd != SDRAM_CMD_NOP) begin
                $fatal(1, "expected loadmode found: %d", cmd);
            end
        end default: begin
        end
    endcase

    typedef logic [col_width-1:0][bus_width-1:0] row_s;

    row_s [banks-1:0][rows-1:0] data;

    row_s [banks-1:0] loaded;
    logic [banks-1:0][row_addr_width-1:0] loaded_rows;
    logic [banks-1:0] is_loaded;

    wire [row_addr_width-1:0] row_i = sdram_a_i;
    wire [col_addr_width-1:0] col_i = sdram_a_i[col_addr_width-1:0];

    wire precharge_all = sdram_a_i[10];
    wire auto_precharge = sdram_a_i[10];

    localparam t_ref_lat_val = t_rc_lat_val;
    logic [$clog2(t_rc_lat)-1:0] ref_lat;

    localparam t_mrd_lat_val = t_mrd_lat[$clog2(t_mrd_lat)-1:0] - 1;
    logic [$clog2(t_mrd_lat)-1:0] mrd_lat;

    localparam t_rcd_lat_val = t_rcd_lat[$clog2(t_rcd_lat)-1:0] - 1;
    logic [banks-1:0][$clog2(t_rcd_lat)-1:0] rcd_lats;

    localparam t_rc_lat_val = t_rc_lat[$clog2(t_rc_lat)-1:0] - 1;
    logic [banks-1:0][$clog2(t_rc_lat)-1:0] rc_lats;

    localparam t_ras_lat_val = t_ras_lat[$clog2(t_ras_lat)-1:0] - 1;
    logic [banks-1:0][$clog2(t_ras_lat)-1:0] ras_lats;

    localparam t_rp_lat_val = t_rp_lat[$clog2(t_rp_lat)-1:0] - 1;
    logic [banks-1:0][$clog2(t_rp_lat)-1:0] rp_lats;

    initial begin
        data = 0;
        is_loaded = 0;
        ref_lat = 0;
        mrd_lat = 0;
        rcd_lats = 0;
        rc_lats = 0;
        ras_lats = 0;
        rp_lats = 0;
    end

    always @(posedge clk_i) begin
        if (ref_lat != 0) ref_lat <= ref_lat - 1;
        if (mrd_lat != 0) mrd_lat <= mrd_lat - 1;

        for (int i = 0; i < banks; i=i+1) begin
            if (rcd_lats[i] != 0) rcd_lats[i] <= rcd_lats[i] - 1;
            if (rc_lats[i] != 0) rc_lats[i] <= rc_lats[i] - 1;
            if (ras_lats[i] != 0) ras_lats[i] <= ras_lats[i] - 1;
            if (rp_lats[i] != 0) rp_lats[i] <= rp_lats[i] - 1;
        end
    end

    typedef struct packed {
        logic valid;
        logic [bank_addr_width-1:0] bank;
        logic [col_addr_width-1:0] col;
    } read_s;

    // The read commands in progress.
    read_s [t_cas_lat-1:0] read_fifo;

    read_s this_read;
    assign this_read = read_fifo[0];
    always_ff @(posedge clk_i) begin
        if (this_read.valid) begin
            `assertEqual(1, is_loaded[this_read.bank]);
        end

        read_fifo[t_cas_lat-2:0] <= read_fifo[t_cas_lat-1:1];
        read_fifo[t_cas_lat-1] <= 0;
    end

    assign dq_io = (this_read.valid)
        ? loaded[this_read.bank][this_read.col]
        : bus_width'('bZ);

    typedef struct packed {
        logic valid;
        logic [bank_addr_width-1:0] bank;
        logic [col_addr_width-1:0] col;
        logic [bus_width-1:0] data;
    } write_s;

    // The write commands in progress.
    write_s [t_cas_lat-1:0] write_fifo;

    write_s this_write;
    assign this_write = write_fifo[0];
    always_ff @(posedge clk_i) begin
        if (this_write.valid) begin
            `assertEqual(1, is_loaded[this_write.bank]);
            loaded[this_write.bank][this_write.col] <= this_write.data;
        end

        write_fifo[t_cas_lat-2:0] <= write_fifo[t_cas_lat-1:1];
        write_fifo[t_cas_lat-1] <= 0;
    end

    sdram_cmd_e cmd;
    assign cmd = sdram_cmd_e'({ras_i, cas_i, we_i});

    sdram_burst_mode mode_burst;
    sdram_burst_len mode_burst_len;
    logic using_burst;

    // TODO: The cs_i command should be processed
    always_ff @(posedge clk_i)
    if (clk_en_i & !cs_i) casez (cmd)
        SDRAM_CMD_LOADMODE: begin
            `assertEqual(0, mrd_lat);
            `assertEqual(0, ref_lat);

            // Reserved
            `assertEqual(0, bank_i);
            `assertEqual(0, sdram_a_i[12:10]);

            // Write burst mode
            using_burst <= sdram_a_i[9];

            // Operating mode
            `assertEqual(0, sdram_a_i[8:7]);

            // Latency
            casez (sdram_a_i[6:4])
                3'b010: `assertEqual(t_rcd_lat, 2)
                3'b011: `assertEqual(t_rcd_lat, 3)
                default: $error("Reserved latency");
            endcase

            // Sequential burst
            mode_burst <= sdram_burst_mode'(sdram_a_i[3]);

            // Burst length
            casez (sdram_a_i[2:0])
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
            rp_lats[bank_i] <= t_rp_lat_val;

            if (precharge_all) begin
                for (int i = 0; i < banks; i=i+1) begin
                    if (is_loaded[i]) begin
                        `assertEqual(0, ras_lats[i]);

                        rp_lats[i] <= t_rp_lat_val;

                        is_loaded[i] <= 0;
                        data[i][loaded_rows[i]] <= loaded[i];
                    end
                end
            end else if (is_loaded[bank_i]) begin
                `assertEqual(0, ras_lats[bank_i]);

                is_loaded[bank_i] <= 0;
                data[bank_i][loaded_rows[bank_i]] <= loaded[bank_i];
            end
        end SDRAM_CMD_ACTIVE: begin
            `assertEqual(0, ref_lat);
            `assertEqual(0, mrd_lat);
            `assertEqual(0, rc_lats[bank_i]);
            `assertEqual(0, rp_lats[bank_i]);
            `assertEqual(0, is_loaded[bank_i]);

            rc_lats[bank_i] <= t_rc_lat_val;
            rcd_lats[bank_i] <= t_rcd_lat_val;
            ras_lats[bank_i] <= t_ras_lat_val;

            is_loaded[bank_i] <= 1;

            loaded[bank_i] <= data[bank_i][row_i];
            loaded_rows[bank_i] <= row_i;
        end SDRAM_CMD_WRITE: begin
            `assertEqual(0, ref_lat);
            `assertEqual(0, mrd_lat);
            `assertEqual(0, rcd_lats[bank_i]);

            write_fifo[t_cas_lat-1] <= '{
                valid: 1,
                bank: bank_i,
                col: col_i,
                data: dq_io
            };

            // TODO: Really this should factor in tDPL.
            if (auto_precharge) begin
                rp_lats[bank_i] <= t_rp_lat_val + 1;
            end
        end SDRAM_CMD_READ: begin
            `assertEqual(0, ref_lat);
            `assertEqual(0, mrd_lat);
            `assertEqual(0, rcd_lats[bank_i]);

            read_fifo[t_cas_lat-1] <= '{
                valid: 1,
                bank: bank_i,
                col: col_i
            };

            if (auto_precharge) begin
                rp_lats[bank_i] <= t_rp_lat_val + 1;
            end
        end default: begin end
    endcase
endmodule
