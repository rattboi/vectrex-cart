#ifndef SYSTEM_H
#define SYSTEM_H

enum RGB_TYPE {
    RGB_TYPE_NONE = 0,
    RGB_TYPE_10 = 1,
    RGB_TYPE_4 = 2,
};

typedef struct {
    uint16_t size; // size of this struct
    uint16_t ver; // system_options version
    uint16_t hw_ver; // 0x0014 = 0.20
    uint16_t sw_ver; // 0x0016 = 0.22
    uint8_t  rgb_type; // RGB_LED_TYPE
    uint8_t  reserved[128-9];
} system_options;

#endif