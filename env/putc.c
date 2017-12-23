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

#include <stddef.h>
#include <stdint.h>
#include "inc/putc.h"

#define UART_TX_OFFSET 4

#ifdef MEMSIZE

#define UART_TX_REG (MEMSIZE + UART_TX_OFFSET)

#else

#define UART_TX_REG (8192 + UART_TX_OFFSET)

#endif

void putchar(unsigned char c) {
  uint32_t a3;
  volatile uint32_t *tx_reg = (uint32_t *) UART_TX_REG;

  a3 = 1 | (c << 8);
  *tx_reg = a3;
  a3 = c  << 8;
  *tx_reg = a3;
  while (*((uint8_t*)tx_reg) == 0) {}
}

