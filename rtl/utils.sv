`ifndef TEST_UTILS_SV
`define TEST_UTILS_SV

`define assertEqual(expected, value) \
    if ((value) !== (expected)) begin \
        $fatal(1, "expected=%0d, got=%0d (%m)", (expected), (value)); \
    end

`define assertRange(lowest, highest, value) \
    if ($rtoi(value) < (lowest)) begin \
        $fatal(1, "lowest=%0d, got=%0d (%m)", (lowest), (value)); \
    end else if ($rtoi(value) > (highest)) begin \
        $fatal(1, "highest=%0d, got=%0d (%m)", (highest), (value)); \
    end

`define assertWithinErr(expected, error, value) \
    `assertRange((expected) - (error), (expected) + (error), (value))

`endif
