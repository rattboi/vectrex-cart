#ifndef MAIN_H
#define MAIN_H

void uart_output_func(unsigned char c);
void loadRom(char *fn);
void loadStreamData(int addr, int len);
void doChangeRom(char* basedir, int i);
void doHandleEvent(int data);
void doDbgHook(int adr, int data);

#endif
