# -------------------------------------------------
# Makefile – run the cocotb testbench
# -------------------------------------------------
# 1) Tell cocotb what language we are using
TOPLEVEL_LANG ?= verilog            # SystemVerilog is accepted via -g2005-sv

# 2) Source files – everything under src/
VERILOG_SOURCES = $(shell find src -name "*.sv")

# 3) Top‑level module of the design
TOPLEVEL = top

# 4) Python testbench module (filename = test_systolic.py)
MODULE = test_systolic

# 5) Simulator (icarus works for SystemVerilog)
SIM ?= icarus

# OPTIONAL – keep a full VCD (helpful for debugging)
# export COCOTB_REDUCE_DUMP=0   # uncomment if you want every signal

# -------------------------------------------------
# Pull in the generic cocotb makefile that defines the
#   <module>   target, clean, etc.
# -------------------------------------------------
include $(shell cocotb-config --makefiles)/Makefile.sim
