// #include <stdlib.h>
#include <libopencm3/cm3/common.h>
#include "delay.h"

volatile uint32_t sysTimerMs;

extern void sys_tick_handler(void);

// Called when systick fires
void sys_tick_handler(void) {
    sysTimerMs++;
    // xprintf("sysTimerMs: %u\n", sysTimerMs);
}

void delay(uint32_t wait) {
    uint32_t start = sysTimerMs;
    while (sysTimerMs - start <= wait);
}

uint32_t millis(void) {
    return sysTimerMs;
}