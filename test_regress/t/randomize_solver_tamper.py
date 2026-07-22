#!/usr/bin/env python3
# DESCRIPTION: Verilator: fake SMT solver wrapper for solver resilience tests
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3,
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 PlanV GmbH
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
#
# Forwards the SMT-LIB conversation to a real z3 and tampers the reply stream.
# Response index = 1-based count of sat/unsat/unknown lines (1 = init handshake).
#
# Env:
#   TAMPER    : none | err_once | err_all | unknown_once | die_at | silent_at
#               | crlf | success | multiline
#   TAMPER_AT : response index for *_once/die_at/silent_at (default 2)

import os
import subprocess
import sys

mode = os.environ.get("TAMPER", "none")
at = int(os.environ.get("TAMPER_AT", "2"))

proc = subprocess.Popen(["z3", "-in"], stdin=sys.stdin, stdout=subprocess.PIPE, text=True)
n = 0
done = False


def emit(line, ending="\n"):
    sys.stdout.write(line + ending)
    sys.stdout.flush()


for line in proc.stdout:
    line = line.rstrip("\n")
    is_status = line in ("sat", "unsat", "unknown")
    if is_status:
        n += 1
        if not done and n >= at:
            if mode in ("err_once", "err_all"):
                emit('(error "injected transient desync")')
                done = mode == "err_once"
            elif mode == "unknown_once":
                emit("unknown")
                done = True
                continue
            elif mode == "die_at":
                proc.kill()
                sys.exit(0)
            elif mode == "silent_at":
                emit('(error "injected silence")')
                done = True
                continue
    if mode == "crlf":
        emit(line, "\r\n")
    elif mode == "success":
        if is_status:
            emit("success")
        emit(line)
    elif mode == "multiline" and line.startswith("(") and not line.startswith("(error"):
        for tok in line.split():
            emit(tok)
    else:
        emit(line)
