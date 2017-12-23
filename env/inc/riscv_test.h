/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __RISCV_TEST_MACROS_H__
#define __RISCV_TEST_MACROS_H__

#define RVTEST_RV32U                  \
  .macro init;                        \
  .endm

#define RVTEST_CODE_BEGIN             \
        .globl _start;                \
_start:                               \
        addi x1,x0,0;                 \
        addi x3,x0,0;                 \
        addi x4,x0,0;                 \
        addi x5,x0,0;                 \
        addi x6,x0,0;                 \
        addi x7,x0,0;                 \
        addi x8,x0,0;                 \
        addi x9,x0,0;                 \
        addi x10,x0,0;                \
        addi x11,x0,0;                \
        addi x12,x0,0;                \
        addi x13,x0,0;                \
        addi x14,x0,0;                \
        addi x15,x0,0;                \
        addi x16,x0,0;                \
        addi x17,x0,0;                \
        addi x18,x0,0;                \
        addi x19,x0,0;                \
        addi x20,x0,0;                \
        addi x21,x0,0;                \
        addi x22,x0,0;                \
        addi x23,x0,0;                \
        addi x24,x0,0;                \
        addi x25,x0,0;                \
        addi x26,x2,0; /*save stack */\
        addi x27,x0,0;                \
        addi x28,x0,0;                \
        addi x29,x0,0;                \
        addi x30,x0,0;                \
        addi x31,x0,0;                \

#define RVTEST_CODE_END               \

#define RVTEST_PASS                   \
        addi x2,x26,0; /*load stack*/ \
        j pass_test;

#define TESTNUM gp

#define RVTEST_FAIL                   \
        addi x2,x26,0;                \
        j fail_test;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN             \
        EXTRA_DATA                    \
        .align 4;
#define RVTEST_DATA_END

#endif //__RISCV_TEST_MACROS_H__
