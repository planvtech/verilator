#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import os

import vltest_bootstrap

test.scenarios('vlt')

test.compile()

# Fake solver: forward to the real z3 but replace the first randomize()'s
# check-sat answer with `unknown` (what a per-check-sat timeout produces). Only
# that one call fails; the run must finish without hanging or a cascade.
solver = os.path.abspath(test.obj_dir + "/timeout_solver.sh")
with open(solver, "w") as fh:
    fh.write("#!/usr/bin/env bash\n")
    fh.write("z3 -in | awk 'BEGIN{n=0} "
             "/^(sat|unsat|unknown)$/ { n++; if (n==2) { print \"unknown\"; fflush(); next } } "
             "{ print; fflush() }'\n")
os.chmod(solver, 0o755)

test.execute(run_env='VERILATOR_SOLVER=' + solver + ' VERILATOR_SOLVER_TIMEOUT=5000 ')

test.passes()
