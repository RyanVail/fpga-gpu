`ifndef TEST_UTILS_SVH
`define TEST_UTILS_SVH

`define assertEqual(expected, value) \
    if ((value) !== (expected)) begin \
        $error("expected=%0d, got=%0d (%m)", (expected), (value)); \
    end

`define assertRange(lowest, highest, value) \
    if ($rtoi(value) < (lowest)) begin \
        $error("lowest=%0d, got=%0d (%m)", (lowest), (value)); \
    end else if ($rtoi(value) > (highest)) begin \
        $error("highest=%0d, got=%0d (%m)", (highest), (value)); \
    end

`define assertWithinErr(expected, error, value) \
    `assertRange((expected) - (error), (expected) + (error), (value))

`endif
