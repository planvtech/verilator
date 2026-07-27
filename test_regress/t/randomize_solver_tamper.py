#!/usr/bin/env python3
# DESCRIPTION: Verilator: fake SMT solver wrapper for solver resilience tests
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3,
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
#
# Forwards the SMT-LIB conversation to a real z3 and tampers the reply stream.
# Response index = 1-based count of sat/unsat/unknown lines (1 = init handshake).
#
# Env:
#   TAMPER    : none | err_once | err_all | unknown_once | die_at | silent_at
#               | crlf | success | multiline | stall_stdin
#   TAMPER_AT : response index for *_once/die_at/silent_at/stall_stdin (default 2)
#               1 = spawn handshake, 2 = main check-sat, 3 = first diversity round

# pylint: disable=consider-using-with

import os
import subprocess
import sys
import threading

mode = os.environ.get("TAMPER", "none")
at = int(os.environ.get("TAMPER_AT", "2"))
z3 = os.environ.get("REAL_Z3", "z3")

stall = threading.Event()

if mode == "stall_stdin":
    # Interpose stdin so the pump can stop consuming, backpressuring the model
    proc = subprocess.Popen([z3, "-in"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    def pump():
        while not stall.is_set():
            data = sys.stdin.buffer.read1(4096)
            if not data:
                proc.stdin.close()
                return
            proc.stdin.write(data.decode())
            proc.stdin.flush()

    threading.Thread(target=pump, daemon=True).start()
else:
    proc = subprocess.Popen([z3, "-in"], stdin=sys.stdin, stdout=subprocess.PIPE, text=True)

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
            elif mode == "stall_stdin":
                stall.set()
                done = True
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
