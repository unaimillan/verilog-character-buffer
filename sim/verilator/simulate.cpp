#define vmodule Vcommon_top
#define STR(x) #x
#define HEADER(x) STR(x.h)

#include <SDL.h>
#include <stdio.h>
#include <verilated.h>

#include HEADER(vmodule)

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;

typedef struct Pixel
{
    uint8_t a; // alpha
    uint8_t b; // blue
    uint8_t g; // green
    uint8_t r; // red
} Pixel;

int main(int argc, char *argv[])
{
    Verilated::commandArgs(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        printf("SDL init failed.\n");
        return 1;
    }

    Pixel screenbuffer[H_RES * V_RES];

    SDL_Window *sdl_window = NULL;
    SDL_Renderer *sdl_renderer = NULL;
    SDL_Texture *sdl_texture = NULL;

    sdl_window = SDL_CreateWindow("Output", SDL_WINDOWPOS_CENTERED,
                                  SDL_WINDOWPOS_CENTERED, H_RES, V_RES,
                                  SDL_WINDOW_SHOWN);
    if (!sdl_window)
    {
        printf("Window creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_renderer = SDL_CreateRenderer(
        sdl_window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!sdl_renderer)
    {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
                                    SDL_TEXTUREACCESS_TARGET, H_RES, V_RES);
    if (!sdl_texture)
    {
        printf("Texture creation failed: %s\n", SDL_GetError());
        return 1;
    }

    // https://wiki.libsdl.org/SDL_GetKeyboardState
    const Uint8 *keyb_state = SDL_GetKeyboardState(NULL);

    // initialize Verilog module
    vmodule *mod = new vmodule;

    // reset
    mod->rst = 1;
    mod->clk = 0;
    mod->eval();
    mod->clk = 1;
    mod->eval();
    mod->rst = 0;
    mod->clk = 0;
    mod->eval();

    uint64_t start_ticks = SDL_GetPerformanceCounter();
    uint64_t frame_count = 0;
    bool isworking = true;

    uint64_t switch_reg = 0;

    while (isworking)
    {
        for (int pix_vpos = 0; isworking && pix_vpos < V_RES; pix_vpos++)
        {
            for (int pix_hpos = 0; isworking && pix_hpos < H_RES; pix_hpos++)
            {
                mod->x = pix_hpos;
                mod->y = pix_vpos;

                // cycle clock
                mod->clk = 1;
                mod->eval();
                mod->clk = 0;
                mod->eval();

                const uint8_t SCALE_BRIGHTNESS = 5;

                // update screen during drawing interval
                Pixel *p = &screenbuffer[pix_vpos * H_RES + pix_hpos];
                p->a = 0xFF;
                p->r = mod->red << SCALE_BRIGHTNESS;
                p->g = mod->green << SCALE_BRIGHTNESS;
                p->b = mod->blue << SCALE_BRIGHTNESS;
            }

            // Handle incoming events
            SDL_Event evt;
            if (SDL_PollEvent(&evt))
            {
                if (evt.type == SDL_QUIT)
                {
                    isworking = false;
                }
                else if (evt.type == SDL_KEYDOWN)
                {
                    uint32_t key_pressed = evt.key.keysym.scancode;
                    // printf("Key press detected: %d\n", key_pressed);

                    if (SDL_SCANCODE_1 <= key_pressed && key_pressed <= SDL_SCANCODE_0)
                    {
                        int bit_num = key_pressed - SDL_SCANCODE_1;
                        switch_reg ^= 1 << bit_num;
                    }
                }
            }
            if (keyb_state[SDL_SCANCODE_Q] || keyb_state[SDL_SCANCODE_ESCAPE])
            {
                printf("Exiting\n");
                isworking = false;
            }

            // read switches
            mod->sw = switch_reg;

            mod->key = ((keyb_state[SDL_SCANCODE_Z]) << 1) |
                       ((keyb_state[SDL_SCANCODE_X]) << 0);
        }

        // update texture once per frame (in blanking)
        SDL_UpdateTexture(sdl_texture, NULL, screenbuffer,
                          H_RES * sizeof(Pixel));
        SDL_RenderClear(sdl_renderer);
        SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
        SDL_RenderPresent(sdl_renderer);
        frame_count++;

        printf("Frame rendered: %lu\n", frame_count);
    }

    // calculate frame rate
    uint64_t end_ticks = SDL_GetPerformanceCounter();
    double duration =
        ((double)(end_ticks - start_ticks)) / SDL_GetPerformanceFrequency();
    double fps = (double)frame_count / duration;
    printf("fps: %.1f\n", fps);

    // end simulation
    mod->final();

    SDL_DestroyTexture(sdl_texture);
    SDL_DestroyRenderer(sdl_renderer);
    SDL_DestroyWindow(sdl_window);
    SDL_Quit();
    return 0;
}
