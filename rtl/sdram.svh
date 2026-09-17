`ifndef SDRAM_SVH
`define SDRAM_SVH

typedef enum bit [2:0] {
    SDRAM_CMD_LOADMODE = 3'b000,
    SDRAM_CMD_REFRESH = 3'b001,
    SDRAM_CMD_PRECHARGE = 3'b010,
    SDRAM_CMD_ACTIVE = 3'b011,
    SDRAM_CMD_WRITE = 3'b100,
    SDRAM_CMD_READ = 3'b101,
    SDRAM_CMD_NOP = 3'b111
} sdram_cmd_e;

typedef struct {
    int banks;
    int rows;
    int bus_width;

    // The number of data entries within a column.
    int col_width;

    int bank_addr_width;
    int row_addr_width;
    int col_addr_width;

    // The number of nanoseconds between clock cycles.
    real clk_cycle_ns;

    // The number of nanoseconds from startup before the SDRAM is ready.
    real init_delay_ns;

    // The number of times per second the SDRAM should be refreshed.
    real refreshes_per_sec;

    // The clock cycles from a read / write command being issued to data being
    // written / read.
    int t_cas_lat;

    // The clock cycles after when a read / write issued before another
    // read / write command can be issued.
    int t_ccd_lat;

    // The clock cycles after an active command before a read / write command
    // can be issued to the same bank.
    int t_rcd_lat;

    // The clock cycles after an active command before another active command
    // can be issued to the same bank.
    int t_rc_lat;

    // The clock cycles after an active command before a precharge command can
    // be issued to the same bank.
    int t_ras_lat;

    // The clock cycles after an precharge command before a active command can
    // be issued to the same bank.
    int t_rp_lat;

    // The clock cycles after a load command before another command can be
    // issued.
    int t_mrd_lat;
} sdram_if_params;

`endif
