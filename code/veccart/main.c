/*
 *  Copyright (C) 2015 Jeroen Domburg <jeroen at spritesmods.com>
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/syscfg.h>
#include <libopencm3/stm32/gpio.h>
#include <libopencm3/stm32/usart.h>
#include <libopencm3/stm32/exti.h>
#include <libopencm3/cm3/nvic.h>
#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/pwr.h>
#include <libopencm3/stm32/flash.h>
#include <stdlib.h>

#include "main.h"
#include "msc.h"

//#include "rom.h"
#include "xprintf.h"
#include "fatfs/ff.h"

//Memory for the menu ROM and the running cartridge.
//We keep both in memory so we can quickly exchange them when a reset has been detected.
char menuData[8*1024];
char cartData[64*1024];
char *romData=menuData;
unsigned char parmRam[256];

/*
//Pinning:
A0-A14,SWCTL - PC0-PC15
D0-D7 - PA0-PA7
nWR - PB1
nCART - PB15
led - PB0
USBPWR - PA9
*/

#define SYSCFG_MEMRMP			MMIO32(SYSCFG_BASE + 0x00)


void uart_output_func(unsigned char c){
	uint32_t reg;
	do {
		reg = USART_SR(USART1);
	} while ((reg & USART_SR_TXE) == 0);
	USART_DR(USART1) = (uint16_t) c & 0xff;
}

//Asm function
extern void romemu(void);

//Load a ROM into cartridge memory
void loadRom(char *fn) {
	FIL f;
	FRESULT fr;
	UINT r=0;
	int n;
	if (romData==cartData) n=sizeof(cartData); else n=sizeof(menuData);
	fr=f_open(&f, fn, FA_READ);
	if (fr) {
		xprintf("Error opening file: %d\n", fr);
	}
	f_read(&f, romData, 64*1024, &r);
	if (n>32*1024 && r<=32*1024) {
		//Duplicate bank to upper bank
		for (n=0; n<32*1024; n++) romData[n+32*1024]=romData[n];
	}
	xprintf("Read %d bytes of rom data.\n", r);
	f_close(&f);
}

//Get a listing of the roms in the 'roms/' directory and
//poke them into the menu cartridge space
void loadListing(void) {
	int strpos=0x800; //enough for 512 name ptrs
	int ptrpos=0x400;
	int i;
	char *name;
	DIR d;
	FILINFO fi;
	char lfn[_MAX_LFN + 1];
	fi.lfname=lfn;
	fi.lfsize=sizeof(lfn);
	xprintf("Reading root dir...\n");
	f_opendir(&d, "/roms");
	while (f_readdir(&d, &fi)==FR_OK) {
		if (fi.fname[0]==0) break;
		if (fi.fname[0]=='.') continue;
//		xprintf("Found file %s (%s)\n", fi.lfname, fi.fname);
		name=fi.lfname;
		if (name==NULL || name[0]==0) name=fi.fname; //use short name if no long name available
		romData[ptrpos++]=strpos>>8;
		romData[ptrpos++]=strpos&0xff;
		i=20;
		while (*name!=0 && i>0) {
			if (*name<32) {
				romData[strpos++]=' ';
			} else if (*name>=32 && *name<95) {
				romData[strpos++]=*name;
			} else if (*name>='a' && *name<='z') {
				romData[strpos++]=(*name-'a')+'A'; //convert to caps
			} else {
				romData[strpos++]='_';
			}
			name++;
			i--;
		}
		romData[strpos++]=0x80; //end of string
	}
	//finish with zero ptr
	romData[ptrpos++]=0;
	romData[ptrpos++]=0;
	f_closedir(&d);
	xprintf("Done.\n");
}


//Stream data, for the Bad Apple demo
//Name of the file sucks and I'd like to make a rpc function that's a bit
//more universal... you should eg be able to pass through the name of the
//file you'd like to stream and the address and chunk size... but this is
//a start.
FIL streamFile;
int streamLoaded=0;

void loadStreamData(int addr, int len) {
	UINT r=0;
	if (!streamLoaded) {
		f_open(&streamFile, "vec.bin", FA_READ);
		streamLoaded=1;
	}
	f_read(&streamFile, &romData[addr], len, &r);
}

//User has made a selection in the cart menu (chose the i'th item) so now we have to load
//the cartridge.
void doChangeRom(int i) {
	char buff[300]="/roms/";
	DIR d;
	FILINFO fi;
	char lfn[_MAX_LFN + 1];
	menuData[0x3ff]=i; //save selection so we can go back there after reset
	romData=cartData;
	fi.lfname=lfn;
	fi.lfsize=sizeof(lfn);
	xprintf("Changing to rom no %d\n", i);
	f_opendir(&d, "/roms");
	while (f_readdir(&d, &fi)==FR_OK) {
		if (fi.fname[0]==0) break;
		if (fi.fname[0]=='.') continue;
//		xprintf("Found file %s (%s), need to get %d more files\n", fi.lfname, fi.fname, i);
		if (i==0) break;
		--i;
	}
	i=0;
	while(fi.fname[i]!=0) buff[i+6]=fi.fname[i++];
	buff[i+6]=0;
	f_closedir(&d);
	romData=cartData;
	xprintf("Going to read rom image %s\n", buff);
	loadRom(buff);
}

//Handle an RPC event
void doHandleEvent(int data) {
	xprintf("Event: %d. arg1: 0x%x\n", data, (int)parmRam[254]);
	if (data==1) doChangeRom((int)parmRam[254]);
	if (data==2) loadStreamData(0x4000, 1024+512);
	xprintf("Event handled. Resuming.\n");
}

void doDbgHook(int adr, int data) {
	xprintf("R %x %x\n", adr, data);
}

static FATFS FatFs;

int main(void) {
//	void (*runptr)(void)=run;
	void (*runptr)(void)=romemu;

	//Make the STM run at 100MHz
	const clock_scale_t hse_8mhz_3v3_96MHz={
			.pllm = 8,
			.plln = 192,
			.pllp = 2,
			.pllq = 4,
			.hpre = RCC_CFGR_HPRE_DIV_NONE,
			.ppre1 = RCC_CFGR_PPRE_DIV_2,
			.ppre2 = RCC_CFGR_PPRE_DIV_NONE,
			.flash_config = FLASH_ACR_ICE | FLASH_ACR_DCE | FLASH_ACR_LATENCY_3WS,
			.apb1_frequency = 50000000,
			.apb2_frequency = 100000000,
		};

	//...well, actually, we're cheating and running the thing at 120MHz...
	rcc_clock_setup_hse_3v3(&hse_8mhz_3v3[CLOCK_3V3_120MHZ]);
//	rcc_clock_setup_hse_3v3(&hse_8mhz_3v3_96MHz);
	rcc_periph_clock_enable(RCC_GPIOA);
	rcc_periph_clock_enable(RCC_GPIOB);
	rcc_periph_clock_enable(RCC_GPIOC);
	rcc_periph_clock_enable(RCC_USART1);
	rcc_periph_clock_enable(RCC_SYSCFG);


	//LED - output
	gpio_mode_setup(GPIOB, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO0);
	//USB power - input
	gpio_mode_setup(GPIOA, GPIO_MODE_INPUT, GPIO_PUPD_PULLDOWN, GPIO9);

	//PB6/PB7: txd/rxd
	gpio_mode_setup(GPIOB, GPIO_MODE_AF, GPIO_PUPD_NONE,
			GPIO6 | GPIO7);
	gpio_set_af(GPIOB, GPIO_AF7, GPIO6 | GPIO7);

	usart_set_baudrate(USART1, 115200);
	usart_set_databits(USART1, 8);
	usart_set_stopbits(USART1, USART_STOPBITS_1);
	usart_set_mode(USART1, USART_MODE_TX);
	usart_set_parity(USART1, USART_PARITY_NONE);
	usart_set_flow_control(USART1, USART_FLOWCONTROL_NONE);
	/* Finally enable the USART. */
	usart_enable(USART1);
	xdev_out(uart_output_func);

	//Address lines - input
	gpio_mode_setup(GPIOC, GPIO_MODE_INPUT, GPIO_PUPD_PULLDOWN, 
		GPIO0|GPIO1|GPIO2|GPIO3|GPIO4|GPIO5|GPIO6|GPIO7|GPIO8|GPIO9|GPIO10|GPIO11|GPIO12|GPIO13|GPIO14|GPIO15);
	gpio_mode_setup(GPIOB, GPIO_MODE_INPUT, GPIO_PUPD_NONE, 
		GPIO13|GPIO14);

	//Data lines - output
	gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, 
		GPIO0|GPIO1|GPIO2|GPIO3|GPIO4|GPIO5|GPIO6|GPIO7);

	//Control lines - input
	gpio_mode_setup(GPIOB, GPIO_MODE_INPUT, GPIO_PUPD_NONE, 
		GPIO1|GPIO15);
	xprintf("Inited.\n");

	//If USB power pin is high, boot into USB disk mode
	if (gpio_get(GPIOA, GPIO9)) {
		xprintf("USB dev mode.\n");
		ramdiskmain();
	} else {
		//Load the menu game
		f_mount(&FatFs, "", 0);
		loadRom("/multicart.bin");
		loadListing();

		//Go emulate a ROM.
		SYSCFG_MEMRMP=0x3; //mak ram at 0
		runptr=(char*)(((int)runptr&0x1ffff)|1); //map to lower mem
		xprintf("Gonna start romemu at %08x\n", romemu);
		runptr();
	}

	return 0;
}



