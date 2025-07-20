module character_rom #(
    parameter CHAR_HORZ_PX_SIZE = 8,
              CHAR_VERT_PX_SIZE = 16,

              CHAR_HORZ_PX_W    = $clog2(CHAR_HORZ_PX_SIZE),
              CHAR_VERT_PX_W    = $clog2(CHAR_VERT_PX_SIZE)
) (
    input  [CHAR_HORZ_PX_W - 1:0] char_hpos,
    input  [CHAR_VERT_PX_W - 1:0] char_vpos,
    input  [                 7:0] char_code,
    
    output                        char_pixel
);
    
    logic [CHAR_HORZ_PX_SIZE - 1:0][CHAR_VERT_PX_SIZE - 1:0] char_bitmap [2**8 - 1:0];

    initial $readmemh ("./rtl/char_font_bitmap.hex", char_bitmap);

    assign char_pixel = char_bitmap[char_code][char_hpos][char_vpos];

endmodule
