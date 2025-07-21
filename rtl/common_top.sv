module common_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,

               screen_width  = 640,
               screen_height = 480,

               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,

               w_x           = $clog2 ( screen_width  ),
               w_y           = $clog2 ( screen_height )
)
(
    input                        clk,
    input                        slow_clk,
    input                        rst,

    // Keys, switches, LEDs

    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,

    // A dynamic seven-segment display

    output logic [          7:0] abcdefgh,
    output logic [w_digit - 1:0] digit,

    // Graphics

    input                        display_on,
    input        [w_x     - 1:0] x,
    input        [w_y     - 1:0] y,

    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,

    // Microphone, sound output and UART

    input        [         23:0] mic,
    output       [         15:0] sound,

    input                        ps2_valid,
    input        [          7:0] ps2_scancode,
    input        [          7:0] ps2_ascii,

    input                        uart_rx,
    output                       uart_tx,

    // General-purpose Input/Output

    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------

       assign led        = '0;
    // assign abcdefgh   = '0;
    // assign digit      = '0;
    // assign red        = '0;
    // assign green      = '0;
    // assign blue       = '0;
       assign sound      = '0;
       assign uart_tx    = '1;

    //------------------------------------------------------------------------

    logic pixel_color;

    // character_buffer #(
    //     // .CLK_FREQ          ( ),
    //     // .CHAR_HORZ_CNT     ( ),
    //     // .CHAR_VERT_CNT     ( ),
    //     // .CHAR_HORZ_W       ( ),
    //     // .CHAR_VERT_W       ( ),
    //     // .CHAR_HORZ_PX_SIZE ( ),
    //     // .CHAR_VERT_PX_SIZE ( ),
    //     // .PIXEL_HPOS_W      ( ),
    //     // .PIXEL_VPOS_W      ( ),
    //     .CURSOR_BLINK_FREQ ( 1 )
    // ) i_cb (
    //     .clk           ( clk ),
    //     .rst           ( rst ),

    //     .char_hpos     ( key[0] ? sw : '0 ),
    //     .char_vpos     ( key[0] ? '0 : sw ),
    //     .char_write_en ( key[1] ),
    //     .char_symbol   ( 8'd97 ),

    //     .cursor_en     ( '0 ),
    //     .cursor_hpos   ( ),
    //     .cursor_vpos   ( ),

    //     .pixel_hpos    ( x ),
    //     .pixel_vpos    ( y ),
    //     .pixel_color   ( pixel_color )
    // );

    logic [7:0] ps2_scancode_r;
    logic [7:0] ps2_ascii_r;

    always_ff @( posedge clk or posedge rst ) begin
        if (rst)
        begin
            ps2_scancode_r <= '0;
            ps2_ascii_r    <= '0;
        end
        else if (ps2_valid & (8'd30 < ps2_ascii) & (ps2_ascii < 8'd130))
        begin
            ps2_scancode_r <= ps2_scancode;
            ps2_ascii_r    <= ps2_ascii;
        end
    end

    character_rom icr (
        .char_hpos  ( x ),
        .char_vpos  ( y ),
        .char_code  ( ps2_ascii_r ),
        .char_pixel ( pixel_color )
    );

    logic [3:0] x4;

    generate
        if (w_x > 6)
        begin : wide_x
            assign x4 = x [6:3];
        end
        else
        begin
            assign x4 = x;
        end
    endgenerate

    //------------------------------------------------------------------------

    logic [3:0] red_4, green_4, blue_4;

    always_comb
    begin
        red_4   = '0;
        green_4 = '0;
        blue_4  = '0;

        // This should be removed after we finish with display_on in wrapper
        // if (display_on)
        // begin
            red_4   = { 4 { pixel_color }};
            green_4 = { 4 { pixel_color }};
            blue_4  = { 4 { pixel_color }};
        // end
    end

    assign red   = w_red'   ( red_4   );
    assign green = w_green' ( green_4 );
    assign blue  = w_blue'  ( blue_4  );

    seven_segment_display
    # (
        .w_digit   ( 4   ),
        .clk_mhz   ( 50  ),
        .update_hz ( 120 )  // The default of 4 is too low for FIFO lab // Looks like a sane default
    )
    i_svn_seg_disp
    (
        .clk      ( clk ),
        .rst      ( rst ),
        .number   ( ps2_ascii_r ),
        .dots     ( '0 ),
        .abcdefgh ( abcdefgh ),
        .digit    ( digit )
    );

endmodule
