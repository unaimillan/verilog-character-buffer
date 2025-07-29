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

    input                        ps2_scancode_vld,
    input        [          7:0] ps2_scancode,

    input                        ps2_ascii_vld,
    input        [          7:0] ps2_ascii,

    input                        uart_rx,
    output                       uart_tx,

    // General-purpose Input/Output

    inout        [w_gpio  - 1:0] gpio
);

    //------------------------------------------------------------------------

    // assign led        = '0;
    // assign abcdefgh   = '0;
    // assign digit      = '0;
    // assign red        = '0;
    // assign green      = '0;
    // assign blue       = '0;
    assign sound      = '0;
    assign uart_tx    = '1;

    //------------------------------------------------------------------------

    logic pixel_color;

    logic [15:0] cursor_hpos;
    logic [15:0] cursor_vpos;

    always_ff @( posedge clk or posedge rst ) begin
        if (rst)
        begin
            cursor_hpos <= '0;
            cursor_vpos <= '0;
        end
        else if (ps2_ascii_vld)
        begin
            if (cursor_hpos == 16'd15)
            begin
                cursor_hpos <= 16'b0;
                cursor_vpos <= 16'b1;
            end
            else
            begin
                cursor_hpos <= cursor_hpos + 1'd1;
            end
        end
        else if (ps2_scancode_vld)
        begin
            if (ps2_scancode == 8'h6b)
                cursor_hpos <= cursor_hpos - 1'b1;
            if (ps2_scancode == 8'h74)
                cursor_hpos <= cursor_hpos + 1'b1;
            if (ps2_scancode == 8'h75)
                cursor_vpos <= cursor_vpos - 1'b1;
            if (ps2_scancode == 8'h72)
                cursor_vpos <= cursor_vpos + 1'b1;
        end
        
    end


    character_buffer #(
        // .CLK_FREQ          ( ),
        // .CHAR_HORZ_CNT     ( 80 ),
        // .CHAR_VERT_CNT     ( 25 ),
        // .CHAR_HORZ_W       ( ),
        // .CHAR_VERT_W       ( ),
        // .CHAR_HORZ_PX_SIZE ( ),
        // .CHAR_VERT_PX_SIZE ( ),
        // .PIXEL_HPOS_W      ( ),
        // .PIXEL_VPOS_W      ( ),
        .CURSOR_BLINK_FREQ ( 1 )
    ) i_cb (
        .clk           ( clk ),
        .rst           ( rst ),

        .char_hpos     ( cursor_hpos ),
        .char_vpos     ( cursor_vpos ),
        .char_write_en ( ps2_ascii_vld ),
        .char_symbol   ( ps2_ascii ),

        .cursor_valid  ( key[1] ),
        .cursor_display_en ( '1 ),
        .cursor_hpos   ( cursor_hpos ),
        .cursor_vpos   ( cursor_vpos ),

        .pixel_hpos    ( x ),
        .pixel_vpos    ( y ),
        .pixel_color   ( pixel_color )
    );

    // assign led = pixel_color;

    logic [7:0] ps2_scancode_r;
    logic [7:0] ps2_ascii_r;

    always_ff @( posedge clk or posedge rst ) begin
        if (rst)
        begin
            ps2_scancode_r <= '0;
            ps2_ascii_r    <= '0;
        end
        else
        begin
            if (ps2_scancode_vld)
                ps2_scancode_r <= ps2_scancode;

            if (ps2_ascii_vld)
                ps2_ascii_r    <= ps2_ascii;
        end
    end

    // character_rom icr (
    //     .char_hpos  ( x ),
    //     .char_vpos  ( y ),
    //     .char_code  ( ps2_ascii_r ),
    //     .char_pixel ( pixel_color )
    // );

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
        // if ((x < 128) & (y < 64))
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
        .number   ( key[0] ? ps2_scancode_r : ps2_ascii_r ),
        .dots     ( '0 ),
        .abcdefgh ( abcdefgh ),
        .digit    ( digit )
    );

endmodule
