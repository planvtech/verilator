// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
//
// Copyright 2010-2011 by Wilson Snyder. This program is free software; you can
// redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License
// Version 2.0.
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************

#ifdef IS_VPI

#include "sv_vpi_user.h"

#else

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "verilated_vpi.h"

#ifdef T_VPI_VAR2
#include "Vt_vpi_var2.h"
#include "Vt_vpi_var2__Dpi.h"
#elif defined(T_VPI_VAR3)
#include "Vt_vpi_var3.h"
#include "Vt_vpi_var3__Dpi.h"
#else
#include "Vt_vpi_var.h"
#include "Vt_vpi_var__Dpi.h"
#endif

#include "svdpi.h"

#endif

#ifdef VERILATOR
#include "verilated.h"
#endif

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>

// These require the above. Comment prevents clang-format moving them
#include "TestCheck.h"
#include "TestSimulator.h"
#include "TestVpi.h"

int errors = 0;

#define TEST_MSG \
    if (0) printf

unsigned int main_time = 0;
unsigned int callback_count = 0;
unsigned int callback_count_half = 0;
unsigned int callback_count_quad = 0;
unsigned int callback_count_strs = 0;
unsigned int callback_count_strs_max = 500;

//======================================================================

// We cannot replace those with VL_STRINGIFY, not available when PLI is build
#define STRINGIFY(x) STRINGIFY2(x)
#define STRINGIFY2(x) #x

int _mon_check_mcd() {
    PLI_INT32 status;

    PLI_UINT32 mcd;
    PLI_BYTE8* filename = (PLI_BYTE8*)(STRINGIFY(TEST_OBJ_DIR) "/mcd_open.tmp");
    mcd = vpi_mcd_open(filename);
    CHECK_RESULT_NZ(mcd);

    {  // Check it got written
        FILE* fp = fopen(filename, "r");
        CHECK_RESULT_NZ(fp);
        fclose(fp);
    }

    status = vpi_mcd_printf(mcd, (PLI_BYTE8*)"hello %s", "vpi_mcd_printf");
    CHECK_RESULT(status, std::strlen("hello vpi_mcd_printf"));

    status = vpi_mcd_printf(0, (PLI_BYTE8*)"empty");
    CHECK_RESULT(status, 0);

    status = vpi_mcd_flush(mcd);
    CHECK_RESULT(status, 0);

    status = vpi_mcd_flush(0);
    CHECK_RESULT(status, 1);

    status = vpi_mcd_close(mcd);
    // Icarus says 'error' on ones we're not using, so check only used ones return 0.
    CHECK_RESULT(status & mcd, 0);

    status = vpi_flush();
    CHECK_RESULT(status, 0);

    return 0;
}

int _mon_check_callbacks_error(p_cb_data cb_data) {
    vpi_printf((PLI_BYTE8*)"%%Error: callback should not be executed\n");
    return 1;
}

int _mon_check_callbacks() {
    t_cb_data cb_data;
    cb_data.reason = cbEndOfSimulation;
    cb_data.cb_rtn = _mon_check_callbacks_error;
    cb_data.user_data = 0;
    cb_data.value = NULL;
    cb_data.time = NULL;

    TestVpiHandle vh = vpi_register_cb(&cb_data);
    CHECK_RESULT_NZ(vh);

    PLI_INT32 status = vpi_remove_cb(vh);
    vh.freed();
    CHECK_RESULT_NZ(status);

    return 0;
}

int _value_callback(p_cb_data cb_data) {
    if (verbose) vpi_printf(const_cast<char*>("     _value_callback:\n"));
    if (TestSimulator::is_verilator()) {
        // this check only makes sense in Verilator
        CHECK_RESULT(cb_data->value->value.integer + 10, main_time);
    }
    callback_count++;
    return 0;
}

int _value_callback_half(p_cb_data cb_data) {
    if (TestSimulator::is_verilator()) {
        // this check only makes sense in Verilator
        CHECK_RESULT(cb_data->value->value.integer * 2 + 10, main_time);
    }
    callback_count_half++;
    return 0;
}

int _value_callback_quad(p_cb_data cb_data) {
    for (int index = 0; index < 2; index++) {
        CHECK_RESULT_HEX(cb_data->value->value.vector[1].aval,
                         (unsigned long)((index == 2) ? 0x1c77bb9bUL : 0x12819213UL));
        CHECK_RESULT_HEX(cb_data->value->value.vector[0].aval,
                         (unsigned long)((index == 2) ? 0x3784ea09UL : 0xabd31a1cUL));
    }
    callback_count_quad++;
    return 0;
}

int _mon_check_value_callbacks() {
    s_vpi_value v;
    v.format = vpiIntVal;

    t_cb_data cb_data;
    cb_data.reason = cbValueChange;
    cb_data.time = NULL;

    {
        TestVpiHandle vh1 = VPI_HANDLE("count");
        CHECK_RESULT_NZ(vh1);

        vpi_get_value(vh1, &v);
        cb_data.value = &v;
        cb_data.obj = vh1;
        cb_data.cb_rtn = _value_callback;

        if (verbose) vpi_printf(const_cast<char*>("     vpi_register_cb(_value_callback):\n"));
        TestVpiHandle callback_h = vpi_register_cb(&cb_data);
        CHECK_RESULT_NZ(callback_h);
    }
    {
        TestVpiHandle vh1 = VPI_HANDLE("half_count");
        CHECK_RESULT_NZ(vh1);

        cb_data.obj = vh1;
        cb_data.cb_rtn = _value_callback_half;

        TestVpiHandle callback_h = vpi_register_cb(&cb_data);
        CHECK_RESULT_NZ(callback_h);
    }
    {
        TestVpiHandle vh1 = VPI_HANDLE("quads");
        CHECK_RESULT_NZ(vh1);

        v.format = vpiVectorVal;
        cb_data.obj = vh1;
        cb_data.cb_rtn = _value_callback_quad;

        TestVpiHandle callback_h = vpi_register_cb(&cb_data);
        CHECK_RESULT_NZ(callback_h);
    }
    {
        TestVpiHandle vh1 = VPI_HANDLE("quads");
        CHECK_RESULT_NZ(vh1);
        TestVpiHandle vh2 = vpi_handle_by_index(vh1, 2);
        CHECK_RESULT_NZ(vh2);

        cb_data.obj = vh2;
        cb_data.cb_rtn = _value_callback_quad;

        TestVpiHandle callback_h = vpi_register_cb(&cb_data);
        CHECK_RESULT_NZ(callback_h);
    }
    return 0;
}

int _mon_check_too_big() {
#ifdef VERILATOR
    s_vpi_value v;
    v.format = vpiVectorVal;

    TestVpiHandle h = VPI_HANDLE("too_big");
    CHECK_RESULT_NZ(h);

    Verilated::fatalOnVpiError(false);
    vpi_get_value(h, &v);
    Verilated::fatalOnVpiError(true);
    s_vpi_error_info info;
    CHECK_RESULT_NZ(vpi_chk_error(&info));

    v.format = vpiStringVal;
    vpi_get_value(h, &v);
    CHECK_RESULT_Z(vpi_chk_error(nullptr));
    CHECK_RESULT_CSTR_STRIP(v.value.str, "some text");
#endif

    return 0;
}

int _mon_check_var() {
    TestVpiHandle vh1 = VPI_HANDLE("onebit");
    CHECK_RESULT_NZ(vh1);

    TestVpiHandle vh2 = vpi_handle_by_name((PLI_BYTE8*)TestSimulator::top(), NULL);
    CHECK_RESULT_NZ(vh2);

    // scope attributes
    const char* p;
    p = vpi_get_str(vpiName, vh2);
    CHECK_RESULT_CSTR(p, "t");
    p = vpi_get_str(vpiFullName, vh2);
    CHECK_RESULT_CSTR(p, TestSimulator::top());
    p = vpi_get_str(vpiType, vh2);
    CHECK_RESULT_CSTR(p, "vpiModule");

    TestVpiHandle vh3 = vpi_handle_by_name((PLI_BYTE8*)"onebit", vh2);
    CHECK_RESULT_NZ(vh3);

#ifdef T_VPI_VAR2
    // test scoped attributes
    TestVpiHandle vh_invisible1 = vpi_handle_by_name((PLI_BYTE8*)"invisible1", vh2);
    CHECK_RESULT_Z(vh_invisible1);

    TestVpiHandle vh_invisible2 = vpi_handle_by_name((PLI_BYTE8*)"invisible2", vh2);
    CHECK_RESULT_Z(vh_invisible2);

    TestVpiHandle vh_visibleParam1 = vpi_handle_by_name((PLI_BYTE8*)"visibleParam1", vh2);
    CHECK_RESULT_NZ(vh_visibleParam1);

    TestVpiHandle vh_invisibleParam1 = vpi_handle_by_name((PLI_BYTE8*)"invisibleParam1", vh2);
    CHECK_RESULT_Z(vh_invisibleParam1);

    TestVpiHandle vh_visibleParam2 = vpi_handle_by_name((PLI_BYTE8*)"visibleParam2", vh2);
    CHECK_RESULT_NZ(vh_visibleParam2);

#endif

    // onebit attributes
    PLI_INT32 d;
    d = vpi_get(vpiType, vh3);
    CHECK_RESULT(d, vpiReg);
    if (TestSimulator::has_get_scalar()) {
        d = vpi_get(vpiVector, vh3);
        CHECK_RESULT(d, 0);
    }

    p = vpi_get_str(vpiName, vh3);
    CHECK_RESULT_CSTR(p, "onebit");
    p = vpi_get_str(vpiFullName, vh3);
    CHECK_RESULT_CSTR(p, TestSimulator::rooted("onebit"));
    p = vpi_get_str(vpiType, vh3);
    CHECK_RESULT_CSTR(p, "vpiReg");

    // array attributes
    TestVpiHandle vh4 = VPI_HANDLE("fourthreetwoone");
    CHECK_RESULT_NZ(vh4);
    if (TestSimulator::has_get_scalar()) {
        d = vpi_get(vpiVector, vh4);
        CHECK_RESULT(d, 1);
        p = vpi_get_str(vpiType, vh4);
        CHECK_RESULT_CSTR(p, "vpiRegArray");
    }

    t_vpi_value tmpValue;
    tmpValue.format = vpiIntVal;
    {
        TestVpiHandle vh10 = vpi_handle(vpiLeftRange, vh4);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 4);
        CHECK_RESULT(vpi_get(vpiType, vh10), vpiConstant);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }
    {
        TestVpiHandle vh10 = vpi_handle(vpiRightRange, vh4);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 3);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }
    {
        TestVpiHandle vh10 = vpi_iterate(vpiReg, vh4);
        CHECK_RESULT_NZ(vh10);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiIterator");
        TestVpiHandle vh11 = vpi_scan(vh10);
        CHECK_RESULT_NZ(vh11);
        p = vpi_get_str(vpiType, vh11);
        CHECK_RESULT_CSTR(p, "vpiReg");
        TestVpiHandle vh12 = vpi_handle(vpiLeftRange, vh11);
        CHECK_RESULT_NZ(vh12);
        vpi_get_value(vh12, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 2);
        p = vpi_get_str(vpiType, vh12);
        CHECK_RESULT_CSTR(p, "vpiConstant");
        TestVpiHandle vh13 = vpi_handle(vpiRightRange, vh11);
        CHECK_RESULT_NZ(vh13);
        vpi_get_value(vh13, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 1);
        p = vpi_get_str(vpiType, vh13);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }

    TestVpiHandle vh5 = VPI_HANDLE("quads");
    CHECK_RESULT_NZ(vh5);
    {
        TestVpiHandle vh10 = vpi_handle(vpiLeftRange, vh5);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 2);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }
    {
        TestVpiHandle vh10 = vpi_handle(vpiRightRange, vh5);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 3);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }
    TestVpiHandle vh6 = vpi_handle_by_index(vh5, 2);
    CHECK_RESULT_NZ(vh6);
    {
        TestVpiHandle vh10 = vpi_handle(vpiLeftRange, vh6);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 0);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }
    {
        TestVpiHandle vh10 = vpi_handle(vpiRightRange, vh6);
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 61);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiConstant");
    }

    // C++ keyword collision
    {
        TestVpiHandle vh10 = VPI_HANDLE("nullptr");
        CHECK_RESULT_NZ(vh10);
        vpi_get_value(vh10, &tmpValue);
        CHECK_RESULT(tmpValue.value.integer, 123);
        p = vpi_get_str(vpiType, vh10);
        CHECK_RESULT_CSTR(p, "vpiParameter");
    }

    // non-integer variables
    tmpValue.format = vpiRealVal;
    {
        TestVpiHandle vh101 = VPI_HANDLE("real1");
        CHECK_RESULT_NZ(vh101);
        d = vpi_get(vpiType, vh101);
        CHECK_RESULT(d, vpiRealVar);
        vpi_get_value(vh101, &tmpValue);
        TEST_CHECK_REAL_EQ(tmpValue.value.real, 1.0, 0.0005);
        p = vpi_get_str(vpiType, vh101);
        CHECK_RESULT_CSTR(p, "vpiRealVar");
    }

    // string variable
    tmpValue.format = vpiStringVal;
    {
        TestVpiHandle vh101 = VPI_HANDLE("str1");
        CHECK_RESULT_NZ(vh101);
        d = vpi_get(vpiType, vh101);
        CHECK_RESULT(d, vpiStringVar);
        vpi_get_value(vh101, &tmpValue);
        CHECK_RESULT_CSTR(tmpValue.value.str, "hello");
        p = vpi_get_str(vpiType, vh101);
        CHECK_RESULT_CSTR(p, "vpiStringVar");
    }

    return errors;
}

int _mon_check_varlist() {
    const char* p;

    TestVpiHandle vh2 = VPI_HANDLE("sub");
    CHECK_RESULT_NZ(vh2);
    p = vpi_get_str(vpiName, vh2);
    CHECK_RESULT_CSTR(p, "sub");
    if (TestSimulator::is_verilator()) {
        p = vpi_get_str(vpiDefName, vh2);
        CHECK_RESULT_CSTR(p, "sub");
    }

    TestVpiHandle vh10 = vpi_iterate(vpiReg, vh2);
    CHECK_RESULT_NZ(vh10);
    CHECK_RESULT(vpi_get(vpiType, vh10), vpiIterator);

    {
        TestVpiHandle vh11 = vpi_scan(vh10);
        CHECK_RESULT_NZ(vh11);
        p = vpi_get_str(vpiFullName, vh11);
        CHECK_RESULT_CSTR(p, TestSimulator::rooted("sub.subsig1"));
    }
    {
        TestVpiHandle vh12 = vpi_scan(vh10);
        CHECK_RESULT_NZ(vh12);
        p = vpi_get_str(vpiFullName, vh12);
        CHECK_RESULT_CSTR(p, TestSimulator::rooted("sub.subsig2"));
    }
    {
        TestVpiHandle vh13 = vpi_scan(vh10);
        vh10.freed();  // IEEE 37.2.2 vpi_scan at end does a vpi_release_handle
        CHECK_RESULT(vh13, 0);
    }
    return 0;
}

void touch_signal() {
    TestVpiHandle vh1 = VPI_HANDLE("count");
    TEST_CHECK_NZ(vh1);
    s_vpi_value v;
    v.format = vpiIntVal;
    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;
    v.value.integer = 0;
    vpi_put_value(vh1, &v, &t, vpiNoDelay);
}

int _mon_check_ports() {
#ifdef TEST_VERBOSE
    printf("-mon_check_ports()\n");
#endif
    // test writing to input port
    TestVpiHandle vh1 = VPI_HANDLE("a");
    TEST_CHECK_NZ(vh1);

    PLI_INT32 d;
    d = vpi_get(vpiType, vh1);
    if (TestSimulator::is_verilator()) {
        TEST_CHECK_EQ(d, vpiReg);
    } else {
        TEST_CHECK_EQ(d, vpiNet);
    }

    const char* portFullName;
    if (TestSimulator::is_verilator()) {
        portFullName = "TOP.a";
    } else {
        portFullName = "t.a";
    }

    const char* name = vpi_get_str(vpiFullName, vh1);
    TEST_CHECK_EQ(strcmp(name, portFullName), 0);
    std::string handleName1 = name;

    s_vpi_value v;
    v.format = vpiIntVal;
    vpi_get_value(vh1, &v);
    TEST_CHECK_EQ(v.value.integer, 0);

    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;
    v.value.integer = 2;
    vpi_put_value(vh1, &v, &t, vpiNoDelay);
    v.value.integer = 100;
    vpi_get_value(vh1, &v);
    TEST_CHECK_EQ(v.value.integer, 2);

    // get handle of toplevel module
    TestVpiHandle vht = VPI_HANDLE("");
    TEST_CHECK_NZ(vht);

    d = vpi_get(vpiType, vht);
    TEST_CHECK_EQ(d, vpiModule);

    TestVpiHandle vhi = vpi_iterate(vpiReg, vht);
    TEST_CHECK_NZ(vhi);

    TestVpiHandle vh11;
    std::string handleName2;
    while ((vh11 = vpi_scan(vhi))) {
        const char* fn = vpi_get_str(vpiFullName, vh11);
#ifdef TEST_VERBOSE
        printf("       scanned %s\n", fn);
#endif
        if (0 == strcmp(fn, portFullName)) {
            handleName2 = fn;
            break;
        }
    }
    TEST_CHECK_NZ(vh11);  // If get zero we never found the variable
    vhi.release();
    TEST_CHECK_EQ(vpi_get(vpiType, vh11), vpiReg);

    TEST_CHECK_EQ(handleName1, handleName2);

    return errors;
}

int _mon_check_getput() {
    TestVpiHandle vh2 = VPI_HANDLE("onebit");
    CHECK_RESULT_NZ(vh2);
    const char* p = vpi_get_str(vpiFullName, vh2);
    CHECK_RESULT_CSTR(p, "t.onebit");

    s_vpi_value v;
    v.format = vpiIntVal;
    vpi_get_value(vh2, &v);
    CHECK_RESULT(v.value.integer, 0);

    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;
    v.value.integer = 0;
    vpi_put_value(vh2, &v, &t, vpiNoDelay);
    vpi_get_value(vh2, &v);
    CHECK_RESULT(v.value.integer, 0);

    v.value.integer = 1;
    vpi_put_value(vh2, &v, &t, vpiNoDelay);
    vpi_get_value(vh2, &v);
    CHECK_RESULT(v.value.integer, 1);

    // real
    TestVpiHandle vh3 = VPI_HANDLE("real1");
    CHECK_RESULT_NZ(vh3);
    v.format = vpiRealVal;
    vpi_get_value(vh3, &v);
    TEST_CHECK_REAL_EQ(v.value.real, 1.0, 0.0005);

    v.value.real = 123456.789;
    vpi_put_value(vh3, &v, &t, vpiNoDelay);
    v.value.real = 0.0f;
    vpi_get_value(vh3, &v);
    TEST_CHECK_REAL_EQ(v.value.real, 123456.789, 0.0005);

    // string
    TestVpiHandle vh4 = VPI_HANDLE("str1");
    CHECK_RESULT_NZ(vh4);
    v.format = vpiStringVal;
    vpi_get_value(vh4, &v);
    CHECK_RESULT_CSTR(v.value.str, "hello");

    v.value.str = const_cast<char*>("something a lot longer than hello");
    vpi_put_value(vh4, &v, &t, vpiNoDelay);
    v.value.str = 0;
    vpi_get_value(vh4, &v);
    TEST_CHECK_CSTR(v.value.str, "something a lot longer than hello");

    return errors;
}

int _mon_check_var_long_name() {
    TestVpiHandle vh2 = VPI_HANDLE(
        "LONGSTART_a_very_long_name_which_will_get_hashed_a_very_long_name_which_will_get_hashed_"
        "a_very_long_name_which_will_get_hashed_a_very_long_name_which_will_get_hashed_LONGEND");
    CHECK_RESULT_NZ(vh2);
    const char* p = vpi_get_str(vpiFullName, vh2);
    CHECK_RESULT_CSTR(p, "t.LONGSTART_a_very_long_name_which_will_get_hashed_a_very_long_name_"
                         "which_will_get_hashed_a_very_long_name_which_will_get_hashed_a_very_"
                         "long_name_which_will_get_hashed_LONGEND");
    return 0;
}

int _mon_check_getput_iter() {
    TestVpiHandle vh2 = VPI_HANDLE("sub");
    CHECK_RESULT_NZ(vh2);
    TestVpiHandle vh10 = vpi_iterate(vpiReg, vh2);
    CHECK_RESULT_NZ(vh10);
    CHECK_RESULT(vpi_get(vpiType, vh10), vpiIterator);

    TestVpiHandle vh11;
    while (1) {
        vh11 = vpi_scan(vh10);
        CHECK_RESULT_NZ(vh11);  // If get zero we never found the variable
        const char* p = vpi_get_str(vpiFullName, vh11);
#ifdef TEST_VERBOSE
        printf("       scanned %s\n", p);
#endif
        if (0 == strcmp(p, "t.sub.subsig1")) break;
    }
    CHECK_RESULT(vpi_get(vpiType, vh11), vpiReg);

    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;
    s_vpi_value v;
    v.format = vpiIntVal;
    v.value.integer = 0;
    vpi_put_value(vh11, &v, &t, vpiNoDelay);
    vpi_get_value(vh11, &v);
    CHECK_RESULT(v.value.integer, 0);

    v.value.integer = 1;
    vpi_put_value(vh11, &v, &t, vpiNoDelay);
    vpi_get_value(vh11, &v);
    CHECK_RESULT(v.value.integer, 1);
    return 0;
}

int _mon_check_quad() {
    TestVpiHandle vh2 = VPI_HANDLE("quads");
    CHECK_RESULT_NZ(vh2);

    s_vpi_value v;
    t_vpi_vecval vv[2];
    bzero(&vv, sizeof(vv));

    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;

    TestVpiHandle vhidx2 = vpi_handle_by_index(vh2, 2);
    CHECK_RESULT_NZ(vhidx2);
    TestVpiHandle vhidx3 = vpi_handle_by_index(vh2, 3);
    CHECK_RESULT_NZ(vhidx3);

    // Packed words should be indexable
    TestVpiHandle vhidx3idx0 = vpi_handle_by_index(vhidx3, 0);
    CHECK_RESULT_NZ(vhidx3idx0);
    TestVpiHandle vhidx2idx2 = vpi_handle_by_index(vhidx2, 2);
    CHECK_RESULT_NZ(vhidx2idx2);
    TestVpiHandle vhidx3idx3 = vpi_handle_by_index(vhidx3, 3);
    CHECK_RESULT_NZ(vhidx3idx3);
    TestVpiHandle vhidx2idx61 = vpi_handle_by_index(vhidx2, 61);
    CHECK_RESULT_NZ(vhidx2idx61);

    v.format = vpiVectorVal;
    v.value.vector = vv;
    v.value.vector[1].aval = 0x12819213UL;
    v.value.vector[0].aval = 0xabd31a1cUL;
    vpi_put_value(vhidx2, &v, &t, vpiNoDelay);

    v.format = vpiVectorVal;
    v.value.vector = vv;
    v.value.vector[1].aval = 0x1c77bb9bUL;
    v.value.vector[0].aval = 0x3784ea09UL;
    vpi_put_value(vhidx3, &v, &t, vpiNoDelay);

    vpi_get_value(vhidx2, &v);
    CHECK_RESULT(v.value.vector[1].aval, 0x12819213UL);
    CHECK_RESULT(v.value.vector[1].bval, 0);

    vpi_get_value(vhidx3, &v);
    CHECK_RESULT(v.value.vector[1].aval, 0x1c77bb9bUL);
    CHECK_RESULT(v.value.vector[1].bval, 0);

    return 0;
}

int _mon_check_delayed() {
    TestVpiHandle vh = VPI_HANDLE("delayed");
    CHECK_RESULT_NZ(vh);

    s_vpi_time t;
    t.type = vpiSimTime;
    t.high = 0;
    t.low = 0;

    s_vpi_value v;
    v.format = vpiIntVal;
    v.value.integer = 123;
    vpi_put_value(vh, &v, &t, vpiInertialDelay);
    CHECK_RESULT_Z(vpi_chk_error(nullptr));
    vpi_get_value(vh, &v);
    CHECK_RESULT(v.value.integer, 0);

    TestVpiHandle vhMem = VPI_HANDLE("delayed_mem");
    CHECK_RESULT_NZ(vhMem);
    TestVpiHandle vhMemWord = vpi_handle_by_index(vhMem, 7);
    CHECK_RESULT_NZ(vhMemWord);
    v.value.integer = 456;
    vpi_put_value(vhMemWord, &v, &t, vpiInertialDelay);
    CHECK_RESULT_Z(vpi_chk_error(nullptr));

    // test unsupported vpiInertialDelay cases
    // - should these also throw vpi errors?
    v.format = vpiStringVal;
    v.value.str = nullptr;
    vpi_put_value(vh, &v, &t, vpiInertialDelay);
    CHECK_RESULT_NZ(vpi_chk_error(nullptr));

    v.format = vpiVectorVal;
    v.value.vector = nullptr;
    vpi_put_value(vh, &v, &t, vpiInertialDelay);
    CHECK_RESULT_NZ(vpi_chk_error(nullptr));

    // This format throws an error now
    Verilated::fatalOnVpiError(false);
    v.format = vpiObjTypeVal;
    vpi_put_value(vh, &v, &t, vpiInertialDelay);
    Verilated::fatalOnVpiError(true);

    return 0;
}

int _mon_check_string() {
    static struct {
        const char* name;
        const char* initial;
        const char* value;
    } text_test_obs[] = {
        {"text_byte", "B", "xxA"},  // x's dropped
        {"text_half", "Hf", "xxT2"},  // x's dropped
        {"text_word", "Word", "Tree"},
        {"text_long", "Long64b", "44Four44"},
        {"text", "Verilog Test module", "lorem ipsum"},
    };

    for (int i = 0; i < 5; i++) {
        TestVpiHandle vh1 = VPI_HANDLE(text_test_obs[i].name);
        CHECK_RESULT_NZ(vh1);

        s_vpi_value v;
        s_vpi_time t = {vpiSimTime, 0, 0, 0.0};
        s_vpi_error_info e;

        v.format = vpiStringVal;
        vpi_get_value(vh1, &v);
        if (vpi_chk_error(&e)) printf("%%vpi_chk_error : %s\n", e.message);

        (void)vpi_chk_error(NULL);

        CHECK_RESULT_CSTR_STRIP(v.value.str, text_test_obs[i].initial);

        v.value.str = (PLI_BYTE8*)text_test_obs[i].value;
        vpi_put_value(vh1, &v, &t, vpiNoDelay);
    }

    return 0;
}

int _mon_check_putget_str(p_cb_data cb_data) {
    static TestVpiHandle cb;
    static struct {
        TestVpiHandle scope, sig, rfr, check, verbose;
        std::string str;
        int type;  // value type in .str
        union {
            PLI_INT32 integer;
            s_vpi_vecval vector[4];
        } value;  // reference
    } data[129];

    if (cb_data) {
        if (verbose) vpi_printf(const_cast<char*>("     _mon_check_putget_str callback:\n"));

        // this is the callback
        static unsigned int seed = 1;
        s_vpi_time t;
        t.type = vpiSimTime;
        t.high = 0;
        t.low = 0;
        for (int i = 2; i <= 6; i++) {
            static s_vpi_value v;
            int words = (i + 31) >> 5;
            TEST_MSG("========== %d ==========\n", i);
            if (callback_count_strs) {
                // check persistence
                if (data[i].type) {
                    v.format = data[i].type;
                } else {
                    static PLI_INT32 vals[]
                        = {vpiBinStrVal, vpiOctStrVal, vpiHexStrVal, vpiDecStrVal};
                    v.format = vals[rand_r(&seed) % ((words > 2) ? 3 : 4)];
                    TEST_MSG("new format %d\n", v.format);
                }
                vpi_get_value(data[i].sig, &v);
                TEST_MSG("%s\n", v.value.str);
                if (data[i].type) {
                    CHECK_RESULT_CSTR(v.value.str, data[i].str.c_str());
                } else {
                    data[i].type = v.format;
                    data[i].str = std::string{v.value.str};
                }
            }

            // check for corruption
            v.format = (words == 1) ? vpiIntVal : vpiVectorVal;
            vpi_get_value(data[i].sig, &v);
            if (v.format == vpiIntVal) {
                TEST_MSG("%08x %08x\n", v.value.integer, data[i].value.integer);
                CHECK_RESULT(v.value.integer, data[i].value.integer);
            } else {
                for (int k = 0; k < words; k++) {
                    TEST_MSG("%d %08x %08x\n", k, v.value.vector[k].aval,
                             data[i].value.vector[k].aval);
                    CHECK_RESULT_HEX(v.value.vector[k].aval, data[i].value.vector[k].aval);
                }
            }

            if (callback_count_strs & 7) {
                // put same value back - checking encoding/decoding equivalent
                v.format = data[i].type;
                v.value.str = (PLI_BYTE8*)(data[i].str.c_str());  // Can't reinterpret_cast
                vpi_put_value(data[i].sig, &v, &t, vpiNoDelay);
                v.format = vpiIntVal;
                v.value.integer = 1;
                // vpi_put_value(data[i].verbose, &v, &t, vpiNoDelay);
                vpi_put_value(data[i].check, &v, &t, vpiNoDelay);
            } else {
                // stick a new random value in
                unsigned int mask = ((i & 31) ? (1 << (i & 31)) : 0) - 1;
                if (words == 1) {
                    v.value.integer = rand_r(&seed);
                    data[i].value.integer = v.value.integer &= mask;
                    v.format = vpiIntVal;
                    TEST_MSG("new value %08x\n", data[i].value.integer);
                } else {
                    TEST_MSG("new value\n");
                    for (int j = 0; j < 4; j++) {
                        data[i].value.vector[j].aval = rand_r(&seed);
                        if (j == (words - 1)) data[i].value.vector[j].aval &= mask;
                        TEST_MSG(" %08x\n", data[i].value.vector[j].aval);
                    }
                    v.value.vector = data[i].value.vector;
                    v.format = vpiVectorVal;
                }
                vpi_put_value(data[i].sig, &v, &t, vpiNoDelay);
                vpi_put_value(data[i].rfr, &v, &t, vpiNoDelay);
            }
            if ((callback_count_strs & 1) == 0) data[i].type = 0;
        }
        if (++callback_count_strs == callback_count_strs_max) {
            int success = vpi_remove_cb(cb);
            cb.freed();
            CHECK_RESULT_NZ(success);
        };
    } else {
        // setup and install
        for (int i = 1; i <= 6; i++) {
            char buf[32];
            snprintf(buf, sizeof(buf), TestSimulator::rooted("arr[%d].arr"), i);
            CHECK_RESULT_NZ(data[i].scope = vpi_handle_by_name((PLI_BYTE8*)buf, NULL));
            CHECK_RESULT_NZ(data[i].sig = vpi_handle_by_name((PLI_BYTE8*)"sig", data[i].scope));
            CHECK_RESULT_NZ(data[i].rfr = vpi_handle_by_name((PLI_BYTE8*)"rfr", data[i].scope));
            CHECK_RESULT_NZ(data[i].check
                            = vpi_handle_by_name((PLI_BYTE8*)"check", data[i].scope));
            CHECK_RESULT_NZ(data[i].verbose
                            = vpi_handle_by_name((PLI_BYTE8*)"verbose", data[i].scope));
        }

        for (int i = 1; i <= 6; i++) {
            char buf[32];
            snprintf(buf, sizeof(buf), TestSimulator::rooted("subs[%d].subsub"), i);
            CHECK_RESULT_NZ(data[i].scope = vpi_handle_by_name((PLI_BYTE8*)buf, NULL));
        }

        static t_cb_data cb_data;
        static s_vpi_value v;
        TestVpiHandle count_h = VPI_HANDLE("count");

        cb_data.reason = cbValueChange;
        cb_data.cb_rtn = _mon_check_putget_str;  // this function
        cb_data.obj = count_h;
        cb_data.value = &v;
        cb_data.time = NULL;
        v.format = vpiIntVal;

        cb = vpi_register_cb(&cb_data);
        // It is legal to free the callback handle immediately if not otherwise needed
        CHECK_RESULT_NZ(cb);
    }
    return 0;
}

int _mon_check_vlog_info() {
    s_vpi_vlog_info vlog_info;
    PLI_INT32 rtn = vpi_get_vlog_info(&vlog_info);
    CHECK_RESULT(rtn, 1);
    CHECK_RESULT(vlog_info.argc, 4);
    CHECK_RESULT_CSTR(vlog_info.argv[1], "+PLUS");
    CHECK_RESULT_CSTR(vlog_info.argv[2], "+INT=1234");
    CHECK_RESULT_CSTR(vlog_info.argv[3], "+STRSTR");
    CHECK_RESULT_Z(vlog_info.argv[4]);
    if (TestSimulator::is_verilator()) {
        CHECK_RESULT_CSTR(vlog_info.product, "Verilator");
        CHECK_RESULT(std::strlen(vlog_info.version) > 0, 1);
    }
    return 0;
}

extern "C" int mon_check() {
    // Callback from initial block in monitor
#ifdef TEST_VERBOSE
    printf("-mon_check()\n");
#endif

    if (int status = _mon_check_mcd()) return status;
    if (int status = _mon_check_callbacks()) return status;
    if (int status = _mon_check_value_callbacks()) return status;
    if (int status = _mon_check_var()) return status;
    if (int status = _mon_check_varlist()) return status;
    if (int status = _mon_check_var_long_name()) return status;
// Ports are not public_flat_rw in t_vpi_var
#if defined(T_VPI_VAR2) || defined(T_VPI_VAR3)
    if (int status = _mon_check_ports()) return status;
#endif
    if (int status = _mon_check_getput()) return status;
    if (int status = _mon_check_getput_iter()) return status;
    if (int status = _mon_check_quad()) return status;
    if (int status = _mon_check_string()) return status;
    if (int status = _mon_check_putget_str(NULL)) return status;
    if (int status = _mon_check_vlog_info()) return status;
    if (int status = _mon_check_delayed()) return status;
    if (int status = _mon_check_too_big()) return status;
#ifndef IS_VPI
    VerilatedVpi::selfTest();
#endif
    return 0;  // Ok
}

//======================================================================

#ifdef IS_VPI

static int mon_check_vpi() {
    TestVpiHandle href = vpi_handle(vpiSysTfCall, 0);
    s_vpi_value vpi_value;

    vpi_value.format = vpiIntVal;
    vpi_value.value.integer = mon_check();
    vpi_put_value(href, &vpi_value, NULL, vpiNoDelay);

    return 0;
}

static s_vpi_systf_data vpi_systf_data[] = {{vpiSysFunc, vpiIntFunc, (PLI_BYTE8*)"$mon_check",
                                             (PLI_INT32(*)(PLI_BYTE8*))mon_check_vpi, 0, 0, 0},
                                            0};

// cver entry
void vpi_compat_bootstrap(void) {
    p_vpi_systf_data systf_data_p;
    systf_data_p = &(vpi_systf_data[0]);
    while (systf_data_p->type != 0) vpi_register_systf(systf_data_p++);
}

// icarus entry
void (*vlog_startup_routines[])() = {vpi_compat_bootstrap, 0};

#else

double sc_time_stamp() { return main_time; }
int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    uint64_t sim_time = 1100;
    contextp->debug(0);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<VM_PREFIX> topp{new VM_PREFIX{contextp.get(),
                                                        // Note null name - we're flattening it out
                                                        ""}};

#ifdef VERILATOR
#ifdef TEST_VERBOSE
    contextp->scopesDump();
#endif
#endif

#if VM_TRACE
    contextp->traceEverOn(true);
    VL_PRINTF("Enabling waves...\n");
    VerilatedVcdC* tfp = new VerilatedVcdC;
    topp->trace(tfp, 99);
    tfp->open(STRINGIFY(TEST_OBJ_DIR) "/simx.vcd");
#endif

    topp->eval();
    topp->clk = 0;
    main_time += 10;

    while (vl_time_stamp64() < sim_time && !contextp->gotFinish()) {
        main_time += 1;
        VerilatedVpi::doInertialPuts();
        topp->eval();
        VerilatedVpi::callValueCbs();
        topp->clk = !topp->clk;
        // mon_do();
#if VM_TRACE
        if (tfp) tfp->dump(main_time);
#endif
    }
    CHECK_RESULT(callback_count, 501);
    CHECK_RESULT(callback_count_half, 250);
    CHECK_RESULT(callback_count_quad, 2);
    CHECK_RESULT(callback_count_strs, callback_count_strs_max);
    VerilatedVpi::clearEvalNeeded();
    if (VerilatedVpi::evalNeeded()) {
        vl_fatal(FILENM, __LINE__, "main", "%Error: Unexpected VPI dirty state");
    }
    touch_signal();
    if (!VerilatedVpi::evalNeeded()) {
        vl_fatal(FILENM, __LINE__, "main", "%Error: Unexpected VPI clean state");
    }
    if (!contextp->gotFinish()) {
        vl_fatal(FILENM, __LINE__, "main", "%Error: Timeout; never got a $finish");
    }
    topp->final();

#if VM_TRACE
    if (tfp) tfp->close();
#endif

    return 0;
}

#endif
