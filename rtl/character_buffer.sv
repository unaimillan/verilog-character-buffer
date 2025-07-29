module character_buffer #(
    parameter CLK_FREQ          = 50_000_000,

              CHAR_HORZ_CNT     = 16, // Size 80x25 is standard for unix tty
              CHAR_VERT_CNT     = 2,
              
              CHAR_HORZ_W       = $clog2(CHAR_HORZ_CNT),
              CHAR_VERT_W       = $clog2(CHAR_VERT_CNT),

              CHAR_HORZ_PX_SIZE = 640 / CHAR_HORZ_CNT,
              CHAR_VERT_PX_SIZE = 480 / CHAR_VERT_CNT,

              CHAR_PX_SCALE     = 1,
              
              PIXEL_HPOS_W      = 10,
              PIXEL_VPOS_W      = 10,

              CURSOR_BLINK_FREQ = 1
) (
    input                       clk,
    input                       rst,

    input  [CHAR_HORZ_W  - 1:0] char_hpos,
    input  [CHAR_VERT_W  - 1:0] char_vpos,
    input                       char_write_en,
    input  [               7:0] char_symbol,

    input                       cursor_valid,
    input                       cursor_display_en,
    input  [CHAR_HORZ_W  - 1:0] cursor_hpos,
    input  [CHAR_VERT_W  - 1:0] cursor_vpos,

    input  [PIXEL_HPOS_W - 1:0] pixel_hpos,
    input  [PIXEL_VPOS_W - 1:0] pixel_vpos,
    output                      pixel_color
);

    // -------------------------------------------------------------------------

    localparam CHAR_BUFF_SIZE = CHAR_HORZ_CNT * CHAR_VERT_CNT;
    localparam CHAR_BUFF_ADDR_W = $clog2(CHAR_BUFF_SIZE);

    logic [7:0] char_buffer [CHAR_BUFF_SIZE - 1:0];

    wire [CHAR_BUFF_ADDR_W - 1:0] char_write_addr = char_hpos * CHAR_VERT_CNT + char_vpos;

    // Debug char_buffer display
    // initial char_buffer = "abcdefghijklmnopqrstuvwxyz12345678";

    always_ff @ (posedge clk)
        if (char_write_en)
            char_buffer[char_write_addr] <= char_symbol;

    // -------------------------------------------------------------------------

    logic [CHAR_HORZ_W       - 1:0] cur_char_hpos;
    logic [CHAR_VERT_W       - 1:0] cur_char_vpos;
    logic [CHAR_HORZ_PX_SIZE - 1:0] cur_char_hpix;
    logic [CHAR_VERT_PX_SIZE - 1:0] cur_char_vpix;
    logic [                    7:0] cur_char_symbol;
    logic                           cur_char_pixel;

    assign cur_char_hpos   = pixel_hpos / CHAR_HORZ_PX_SIZE;
    assign cur_char_vpos   = pixel_vpos / CHAR_VERT_PX_SIZE;

    wire [CHAR_BUFF_ADDR_W - 1:0] char_read_addr = cur_char_hpos * CHAR_VERT_CNT + cur_char_vpos;

    assign cur_char_symbol = char_buffer[char_read_addr];

    assign cur_char_hpix   = pixel_hpos % CHAR_HORZ_PX_SIZE;
    assign cur_char_vpix   = pixel_vpos % CHAR_VERT_PX_SIZE;

    character_rom i_char_rom (
        .char_code  ( cur_char_symbol ),
        .char_hpos  ( cur_char_hpix   ),
        .char_vpos  ( cur_char_vpix   ),
        .char_pixel ( cur_char_pixel  )
    );

    // -------------------------------------------------------------------------

    localparam CURSOR_BLINK_HALF_PERIOD = CLK_FREQ / CURSOR_BLINK_FREQ / 2;
    localparam CURSOR_CNT_W            = $clog2 (CURSOR_BLINK_HALF_PERIOD);

    logic [CURSOR_CNT_W - 1:0] cnt;
    logic                      cursor_blink_on;

    always_ff @ (posedge clk or posedge rst)
        if (rst)
        begin
            cnt             <= '0;
            cursor_blink_on <= '0;
        end
        else if (cnt == '0)
        begin
            cnt             <= CURSOR_CNT_W' (CURSOR_BLINK_HALF_PERIOD - 1);
            cursor_blink_on <= ~ cursor_blink_on;
        end
        else
        begin
            cnt <= cnt - 1'd1;
        end
    
    // -------------------------------------------------------------------------

    wire draw_cursor = ( cursor_hpos == cur_char_hpos ) & ( cursor_vpos == cur_char_vpos );
    // wire drawing_char_bottom_line = (cur_char_vpix - CHAR_VERT_PX_SIZE) <= 2;
    
    // assign pixel_color = cursor_blink_on;
    assign pixel_color = cursor_display_en ? 
        ((draw_cursor & cursor_blink_on) ? 1'b1 : cur_char_pixel) : 
        cur_char_pixel;

endmodule
