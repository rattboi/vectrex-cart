#ifndef MENU_H
#define MENU_H

#include "fatfs/ff.h"

#define MENU_TEXT_LEN 20

typedef struct {
	int is_dir;
	char fname[_MAX_LFN + 1];
} file_entry;

typedef struct {
	int num_files;
	file_entry f_entry[80];
} dir_listing;

int removeExtension(char* filename, char* extension);
void sortDirectory(char *fdir, dir_listing *listing); 
void loadListing(char *fdir, dir_listing *listing, char *romData, const int fnptrs, const int strptrs, const int num_files_ptr); 

#endif
