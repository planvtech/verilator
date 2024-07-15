all: simulate

TOPLEVEL_MODULE = implication_con_and_if_else_con
#TESTBENCH_MODULE = sv_tb_top
SIMULATOR = vsim

UVM_ROOT ?=/opt/questasim/verilog_src/uvm-1.2/
#UVM_ROOT ?= ../../../../uvm-verilator
#UVM_TEST ?= case0_test
USES_DPI = 1
GUI = 0

DPI_INCLUDE ?= /opt/questasim/include
#VSIM_COV ?= -coverage

ifeq ($(USES_DPI),1)
	DPILIB_VLOG_OPT = 
	DPILIB_VSIM_OPT = -sv_lib /opt/questasim/uvm-1.2/linux_x86_64/uvm_dpi
	DPILIB_TARGET = dpi_lib$(BITS)
else
	DPILIB_VLOG_OPT = +define+UVM_NO_DPI
	DPILIB_VSIM_OPT =
	DPILIB_TARGET =
endif

LIBDIR = $(UVM_ROOT)/src/lib
LIBNAME = uvm_dpi

VERILOG_DEFINE_FILES = ../implication_con_and_if_else_con.sv

WORK_DIR = work

SV_FILES := ../implication_con_and_if_else_con.sv

VSIM_OPTS = $(DPILIB_VSIM_OPT) -do "run -all" -l simulate.log

ifeq ($(GUI),1)
	VSIM_OPTS += -gui
else
	VSIM_OPTS += -c
endif

compile: $(SV_FILES)
	$(SIMULATOR) -work $(WORK_DIR) -c -do \
	"vlib $(WORK_DIR); \
	vmap work $(WORK_DIR); \
	vlog -work $(WORK_DIR) $(VERILOG_DEFINE_FILES); \
	quit"

simulate: compile
	$(SIMULATOR) -64 -lib $(WORK_DIR) $(TOPLEVEL_MODULE) $(VSIM_OPTS)

clean:
	rm -rf $(WORK_DIR)
	rm -f dump.vcd modelsim.ini simulate.log tr_db.log transcript vsim.wlf vsim_stacktrace.vstf

.PHONY: all compile simulate clean