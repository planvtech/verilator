#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import shutil

import vltest_bootstrap

test.scenarios('vlt')

if not test.have_solver:
    test.skip("No constraint solver installed")
if not shutil.which('z3'):
    test.skip("No z3 in PATH")

test.compile()

# Solver stops consuming stdin after the handshake while staying alive: the
# oversized transaction must hit write backpressure and fail at the wall
# deadline instead of blocking in write() forever
# Status-line index: 1 = spawn handshake, 2 = main check-sat, 3 = first diversity round
test.execute(run_env='VERILATOR_SOLVER=' + test.t_dir +
             '/randomize_solver_tamper.py TAMPER=stall_stdin TAMPER_AT=1' +
             ' VERILATOR_SOLVER_TIMEOUT=2000')

test.file_grep(test.run_log_filename, r'Solver died; restarting it')
test.file_grep(test.run_log_filename, r'NFAIL=3')
test.file_grep(test.run_log_filename, r'All Finished')

test.passes()
