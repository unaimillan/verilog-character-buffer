.PHONY: all clean

VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`


gen_font:
	python3 scripts/bdf_font_to_hex_mem.py

gen:
	scripts/run_scripts.bash

build: rtl/common_top.sv
	verilator ${VFLAGS} -Irtl -cc $< --exe sim/verilator/simulate.cpp -o common_top.out \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}" --Mdir sim/verilator/output_files \
		--timescale 1ns/1ps -Wno-fatal # -Wno-MULTIDRIVEN -Wno-LATCH
	make -C ./sim/verilator/output_files -f Vcommon_top.mk

run:
	./sim/verilator/output_files/common_top.out

clean:
	rm -rf ./sim/verilator/output_files/

start: clean build run
