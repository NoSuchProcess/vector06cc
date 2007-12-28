#ifndef _FDDIMAGE_H
#define _FDDIMAGE_H

#include "integer.h"
#include "tff.h"

typedef struct {
	uint8_t nsides;
	uint8_t ntracks;
	uint8_t nsectors;
	uint16_t sectorsize;
	
	uint8_t cur_side;
	uint8_t cur_sector;
	uint8_t cur_track;
	
	FIL* file;
	uint16_t offset;		// current offset into buffer
	uint8_t	ready;			// 1 => read operation must be performed first
	uint8_t	buffer[512];
} FDDImage;

uint8_t fdd_clearerror();
uint8_t fdd_load(FIL* file, FDDImage *fdd);
uint8_t fdd_seek(FDDImage *fdd, uint8_t side, uint8_t track, uint8_t sector);
uint8_t fdd_nextbyte(FDDImage* fdd);
FRESULT fdd_readsector(FDDImage* fdd);

#endif