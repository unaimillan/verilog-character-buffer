#!/bin/bash

set -Eexuo pipefail

yosys -s synth.ys

yosys -s sta.ys
