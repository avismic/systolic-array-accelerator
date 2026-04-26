# sim/Makefile
# Tells cocotb how to compile and simulate your design.

SIM        = icarus            # Use Icarus Verilog as simulator
TOPLEVEL_LANG = verilog

# List ALL your RTL files
VERILOG_SOURCES  = $(PWD)/../rtl/pe.sv
VERILOG_SOURCES += $(PWD)/../rtl/systolic_array.sv
VERILOG_SOURCES += $(PWD)/../rtl/skew_buffer.sv
VERILOG_SOURCES += $(PWD)/../rtl/top.sv

# Top-level module name must match your top.sv module name
TOPLEVEL   = top

# Python test file (without .py extension)
MODULE     = test_systolic

# Extra Icarus flags: enable SystemVerilog support
COMPILE_ARGS += -g2012

# Dump waveforms to a VCD file for GTKWave
COCOTB_RESOLVE_X = ZEROS
PLUSARGS += -dumpfile=waves.vcd -dumpvars=0
export PYTHONPATH := /usr/local/python/3.12.1/lib/python3.12/site-packages:$(PYTHONPATH)
include $(shell cocotb-config --makefiles)/Makefile.sim