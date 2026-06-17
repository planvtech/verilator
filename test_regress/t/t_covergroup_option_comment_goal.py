#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap
import re

test.scenarios('vlt')

test.compile(verilator_flags2=['--coverage'])
test.execute()

# Each covergroup point in coverage.dat carries the covergroup-level option.comment
# (recognized short key 'o') and option.goal (key 'goal').  Emit a sorted report of
# hierarchy/comment/goal so the golden pins that both options are surfaced.
contents = test.file_contents(test.coverage_filename)
entries = []
for m in re.finditer(r"C '([^']+)' \d+", contents):
    entry = m.group(1)
    if '\x01t\x02covergroup' not in entry:
        continue
    hier_m = re.search(r'\x01h\x02([^\x01]+)', entry)
    comment_m = re.search(r'\x01o\x02([^\x01]+)', entry)
    goal_m = re.search(r'\x01goal\x02([^\x01]+)', entry)
    if not hier_m:
        continue
    comment = comment_m.group(1) if comment_m else ''
    goal = goal_m.group(1) if goal_m else ''
    entries.append((hier_m.group(1), comment, goal))
entries.sort()

outfile = test.obj_dir + '/cg_options_report.txt'
with open(outfile, 'w', encoding='utf-8') as fh:
    for hier, comment, goal in entries:
        fh.write(f"{hier} comment='{comment}' goal={goal}\n")

test.files_identical(outfile, test.golden_filename)

test.passes()
