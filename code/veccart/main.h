#ifndef MAIN_H
#define MAIN_H

void uart_output_func(unsigned char c);
void loadListing(void);
void loadRom(char *fn);
void loadStreamData(int addr, int len);
void doChangeRom(int i);
void doHandleEvent(int data);
void doDbgHook(int adr, int data); 

#endif
