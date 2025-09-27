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

`endif
