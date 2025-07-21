`include "config.svh"

// `define USE_DIGILENT_PMOD_MIC3

`ifdef USE_DIGILENT_PMOD_MIC3
    `define USE_SDRAM_PINS_AS_GPIO
`else
    `define USE_LCD_AS_GPIO
`endif

`define USE_INTERNALLY_WIDE_COLOR_CHANNELS

//----------------------------------------------------------------------------

module board_specific_top
# (
    parameter clk_mhz       = 50,
              pixel_mhz     = 25,

              w_key         = 4,
              w_sw          = 4,
              w_led         = 4,
              w_digit       = 4,

              `ifdef USE_SDRAM_PINS_AS_GPIO
              w_gpio        = 14,
              `elsif USE_LCD_AS_GPIO
              w_gpio        = 11,
              `else
              w_gpio        = 1,
              `endif

              screen_width  = 640,
              screen_height = 480,

              `ifdef USE_INTERNALLY_WIDE_COLOR_CHANNELS

              w_red         = 4,
              w_green       = 4,
              w_blue        = 4,

              `else

              w_red         = 1,
              w_green       = 1,
              w_blue        = 1,

              `endif

              w_x           = $clog2 ( screen_width  ),
              w_y           = $clog2 ( screen_height )
)
(
    input                  CLK,
    input                  RESET,

    input  [w_key   - 1:0] KEY_SW,
    output [w_led   - 1:0] LED,

    output [          7:0] SEG,
    output [w_digit - 1:0] DIG,

    output                 VGA_HSYNC,
    output                 VGA_VSYNC,
    output                 VGA_R,
    output                 VGA_G,
    output                 VGA_B,

    input                  UART_RXD,
    output                 UART_TXD,

    inout  [w_gpio  - 1:0] PSEUDO_GPIO_USING_SDRAM_PINS,

    inout                  LCD_RS,
    inout                  LCD_RW,
    inout                  LCD_E,
    inout  [          7:0] LCD_D,

    inout                  PS_CLOCK,
    inout                  PS_DATA
);

    //------------------------------------------------------------------------

    wire clk =   CLK;
    wire rst = ~ RESET;

    //------------------------------------------------------------------------

    wire [w_led   - 1:0] lab_led;

    // Seven-segment display

    wire [          7:0] abcdefgh;
    wire [w_digit - 1:0] digit;

    // Graphics

    wire                 display_on;

    wire [w_x     - 1:0] x;
    wire [w_y     - 1:0] y;

    wire [w_red   - 1:0] red;
    wire [w_green - 1:0] green;
    wire [w_blue  - 1:0] blue;

    assign VGA_R = display_on & ( | red   );
    assign VGA_G = display_on & ( | green );
    assign VGA_B = display_on & ( | blue  );

    // Sound

    wire [         23:0] mic;
    wire [         15:0] sound;

    // PS/2 Keyboard

    wire                 ps2_valid;
    wire [          7:0] ps2_scancode;
    wire [          7:0] ps2_ascii;

    //------------------------------------------------------------------------

    wire slow_clk;

    slow_clk_gen # (.fast_clk_mhz (clk_mhz), .slow_clk_hz (1))
    i_slow_clk_gen (.slow_clk (slow_clk), .*);

    //------------------------------------------------------------------------

    common_top
    # (
        .clk_mhz       (   clk_mhz       ),

        .w_key         (   w_key         ),
        .w_sw          (   w_sw          ),
        .w_led         (   w_led         ),
        .w_digit       (   w_digit       ),
        .w_gpio        (   w_gpio        ),

        .screen_width  (   screen_width  ),
        .screen_height (   screen_height ),

        .w_red         (   w_red         ),
        .w_green       (   w_green       ),
        .w_blue        (   w_blue        )
    )
    i_common_top
    (
        .clk           (   clk           ),
        .slow_clk      (   slow_clk      ),
        .rst           (   rst           ),

        .key           ( ~ KEY_SW        ),
        .sw            ( ~ KEY_SW        ),

        .led           (   lab_led       ),

        .abcdefgh      (   abcdefgh      ),
        .digit         (   digit         ),

        .x             (   x             ),
        .y             (   y             ),

        .red           (   red           ),
        .green         (   green         ),
        .blue          (   blue          ),

        .uart_rx       (   UART_RXD      ),
        .uart_tx       (   UART_TXD      ),

        .mic           (   mic           ),
        .sound         (   sound         ),

        .ps2_valid     (   ps2_press_down ),
        .ps2_scancode  (   ps2_scancode   ),
        .ps2_ascii     (   ps2_ascii      ),

        `ifdef USE_SDRAM_PINS_AS_GPIO
            .gpio ( PSEUDO_GPIO_USING_SDRAM_PINS )
        `elsif USE_LCD_AS_GPIO
            .gpio ({ LCD_RS, LCD_RW, LCD_E, LCD_D })
        `endif
    );

    //------------------------------------------------------------------------

    assign LED       = ~ lab_led;

    assign SEG       = ~ abcdefgh;
    assign DIG       = ~ digit;

    //------------------------------------------------------------------------

    wire [9:0] x10; assign x = x10;
    wire [9:0] y10; assign y = y10;

    vga
    # (
        .CLK_MHZ     ( clk_mhz   ),
        .PIXEL_MHZ   ( pixel_mhz )
    )
    i_vga
    (
        .clk         ( clk        ),
        .rst         ( rst        ),
        .hsync       ( VGA_HSYNC  ),
        .vsync       ( VGA_VSYNC  ),
        .display_on  ( display_on ),
        .hpos        ( x10        ),
        .vpos        ( y10        ),
        .pixel_clk   (            )
    );

    //------------------------------------------------------------------------

    wire ps2_rx_released;
    wire ps2_press_down = ps2_valid & (~ ps2_rx_released);

    ps2_keyboard_interface i_ps2 (
        .clk                      ( clk ),
        .reset                    ( rst ),
        .ps2_clk                  ( PS_CLOCK  ),
        .ps2_data                 ( PS_DATA ),
        .rx_extended              (  ),
        .rx_released              ( ps2_rx_released ),
        .rx_shift_key_on          (  ),
        .rx_data_ready            ( ps2_valid ), // rx_read_o
        .rx_read                  ( '1 ), // rx_read_ack_i
        .rx_scan_code             ( ps2_scancode ), // [7:0]    
        .rx_ascii                 ( ps2_ascii    ), // [7:0]
        .tx_data                  (  ), // [7:0]
        .tx_write                 ( '0 ),
        .tx_write_ack_o           (  ),
        .tx_error_no_keyboard_ack (  )
    );

    //------------------------------------------------------------------------

    `ifdef INSTANTIATE_MICROPHONE_INTERFACE_MODULE

        `ifdef USE_DIGILENT_PMOD_MIC3

            wire [11:0] mic_12;

            digilent_pmod_mic3_spi_receiver i_microphone
            (
                .clk   ( clk                               ),
                .rst   ( rst                               ),
                .cs    ( PSEUDO_GPIO_USING_SDRAM_PINS  [0] ),
                .sck   ( PSEUDO_GPIO_USING_SDRAM_PINS  [6] ),
                .sdo   ( PSEUDO_GPIO_USING_SDRAM_PINS  [4] ),
                .value ( mic_12                            )
            );

            assign PSEUDO_GPIO_USING_SDRAM_PINS [ 8] = 1'b0;  // GND
            assign PSEUDO_GPIO_USING_SDRAM_PINS [10] = 1'b1;  // VCC

            wire [11:0] mic_12_minus_offset = mic_12 - 12'h800;

            assign mic = { { 12 { mic_12_minus_offset [11] } },
                           mic_12_minus_offset };

        //--------------------------------------------------------------------

        `else  // USE_INMP_441_MIC

            inmp441_mic_i2s_receiver
            # (
                .clk_mhz ( clk_mhz   )
            )
            i_microphone
            (
                .clk     ( clk       ),
                .rst     ( rst       ),
                .lr      ( LCD_D [5] ),
                .ws      ( LCD_D [3] ),
                .sck     ( LCD_D [1] ),
                .sd      ( LCD_D [2] ),
                .value   ( mic       )
            );

            assign LCD_D [6] = 1'b0;  // GND
            assign LCD_D [4] = 1'b1;  // VCC

        `endif  // USE_INMP_441_MIC

    `endif  // INSTANTIATE_MICROPHONE_INTERFACE_MODULE

    //------------------------------------------------------------------------

    `ifdef INSTANTIATE_SOUND_OUTPUT_INTERFACE_MODULE

        i2s_audio_out
        # (
            .clk_mhz ( clk_mhz   )
        )
        inst_audio_out
        (
            .clk     ( clk       ),
            .reset   ( rst       ),
            .data_in ( sound     ),
            .mclk    ( LCD_E     ),  // Pin 143
            .bclk    ( LCD_RS    ),  // Pin 141
            .lrclk   ( LCD_RW    ),  // Pin 138
            .sdata   ( LCD_D [0] )   // Pin 142
        );                           // GND and VCC 3.3V (30-45 mA)

    `endif

endmodule
