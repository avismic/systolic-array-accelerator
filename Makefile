# Makefile for Systolic Array Simulation

# Simulator to use
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Design Sources
VERILOG_SOURCES += $(PWD)/src/pe.sv
VERILOG_SOURCES += $(PWD)/src/skew_buffer.sv
VERILOG_SOURCES += $(PWD)/src/systolic_array.sv
VERILOG_SOURCES += $(PWD)/src/top.sv

# Top-level module name (in your Verilog)
TOPLEVEL = top

# --- PATH FIXES ---
# 1. Fix for 'pygpi' error: Explicitly add site-packages to PYTHONPATH
export PYTHONPATH := $(shell python3 -c "import site; print(site.getsitepackages()[0])"):$(PYTHONPATH)

# 2. Fix for Test Location: Add the 'test' directory to the path so cocotb finds your script
export PYTHONPATH := $(PWD)/test:$(PYTHONPATH)

# Python test module name (the name of your .py file without the extension)
COCOTB_TEST_MODULES = test_systolic

# Include cocotb's simulation logic
include $(shell cocotb-config --makefiles)/Makefile.sim