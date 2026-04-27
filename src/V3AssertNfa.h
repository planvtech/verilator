// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: NFA-based multi-cycle SVA assertion evaluation
//
// Code available from: https://verilator.org
//
//*************************************************************************
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of either the GNU Lesser General Public License Version 3
// or the Perl Artistic License Version 2.0.
// SPDX-FileCopyrightText: 2005-2026 Wilson Snyder
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************

#ifndef VERILATOR_V3ASSERTNFA_H_
#define VERILATOR_V3ASSERTNFA_H_

#include "config_build.h"
#include "verilatedos.h"

class AstClocking;
class AstDefaultDisable;
class AstNetlist;
class AstNodeModule;

//============================================================================
// Module-level defaults shared with V3AssertPre. IEEE 1800-2023 14.12 (default
// clocking) and 16.15 (default disable iff) are scanned via collectModuleDefaults
// so both passes see the same first-found default. Multiple-default diagnostics
// and clocking event-var creation live in V3AssertPre.

struct V3AssertModuleDefaults {
    AstClocking* defaultClockingp = nullptr;
    AstDefaultDisable* defaultDisablep = nullptr;
};

class V3AssertNfa final {
public:
    static void assertNfaAll(AstNetlist* nodep) VL_MT_DISABLED;
    static V3AssertModuleDefaults collectModuleDefaults(AstNodeModule* modp) VL_MT_DISABLED;
};

#endif  // Guard
