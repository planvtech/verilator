#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# Copyright 2024 by Wilson Snyder. This program is free software; you
# can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')

# On Verilator, we expect this to pass.
#
# TBD: Will event-based simulators match Verilator's behavior
# closely enough to pass the same test?
# If not -- probably we should switch this to be vlt-only.

test.compile(verilator_flags2=["--trace-vcd"])

test.execute()

test.vcd_identical(test.trace_filename, test.golden_filename)

test.passes()
