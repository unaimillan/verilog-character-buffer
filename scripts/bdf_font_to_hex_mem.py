from pathlib import Path
from bdfparser import Font, Bitmap

PROJECT_ROOT_DIR = Path('./')
IBM_FONT_DIR = PROJECT_ROOT_DIR / 'include/ibmfonts/bdf'

RTL_DIR = PROJECT_ROOT_DIR / 'rtl'
assert RTL_DIR.exists()


def print_hex_bitmap(hex_bitmap: str = '30307878ccccccccfcfccccccccc0000'):
    arr = [hex_bitmap[i:i+2] for i in range(0, len(hex_bitmap), 2)]
    print(*[f"{int(i, 16):08b}" for i in arr], sep='\n')


def main():
    ibm_font = Font(str(IBM_FONT_DIR / 'ib8x16u.bdf'))
    print(ibm_font.props)
    print(ibm_font.headers)
    print(ibm_font.glyphs[97])
    print(ibm_font.glyphbycp(97).draw())

    memory = []
    for glyph_idx in range(0, 2**8):
        glyph_bitmap = Bitmap(['0'*8 for _ in range(16)])

        if glyph_idx in ibm_font.glyphs.keys():
            glyph_bitmap = ibm_font.glyphbycp(glyph_idx).draw()
        
        bitmap_transposed = list(map(lambda x: ''.join(x)[::-1], zip(*glyph_bitmap.todata())))[::-1]
        mem_elem = f"{int(''.join(bitmap_transposed), base=2):032x}"
        memory.append(mem_elem)
    
    mem_filepath = RTL_DIR / 'char_font_bitmap.hex'
    mem_filepath.write_text('\n'.join(memory))


if __name__ == '__main__':
    main()
