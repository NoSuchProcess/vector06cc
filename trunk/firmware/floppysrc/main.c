#include "serial.h"
#include "specialio.h"
#include "integer.h"

#include "diskio.h"
#include "tff.h"

#include "timer.h"

/*---------------------------------------------------------*/
/* User Provided Timer Function for FatFs module           */
/*---------------------------------------------------------*/
/* This is a real time clock service to be called from     */
/* FatFs module. Any valid time must be returned even if   */
/* the system does not support a real time clock.          */
DWORD get_fattime (void)
{
	return 0;
}


FATFS fatfs;
FILINFO finfo;
BYTE Buff[2048];			/* Working buffer */

void print_result(DRESULT result) {
	switch (result) {
		case 0:
			ser_puts("pass");
			break;
		default:
			ser_puts("bad");
			break;
	}
	ser_puts("\n\r");
}

BYTE nybble_alpha(BYTE nybble) {
	return nybble + (nybble < 0x0a ? '0' : 'a'-0x0a);
}

void print_hex(BYTE b) {
	ser_putc(nybble_alpha((b & 0xf0) >> 4));
	ser_putc(nybble_alpha(b & 0x0f));
}

void print_buff() {
  WORD ofs;
  
  for (ofs = 0; ofs < 1024; ofs++) {
    if (ofs % 16 == 0) {
      ser_puts("\n\r");
    } else if (ofs % 8 == 0) {
      ser_putc('-');
    } else ser_putc(' ');
    print_hex(Buff[ofs]); 
  }
}

void main(void) {
	FATFS *fs = &fatfs;
	DWORD p1, p2;
	BYTE res;
	DIR dir;
	FIL	file1;
	char *ptrdir = "vector06c";
	char *ptrfile = "floppy.fdd";
	UINT bytesread;

	uint8_t leds = 0x01;
	DRESULT result;
	FRESULT fresult;
	
	GREEN_LEDS = 0xC3;

	
	ser_puts("@");
	delay2(100);
	ser_puts("\n\r}O{\n\rhello.jpg\n\r");
	delay2(50);

	MMC_A = 0;
	delay2(2);
	MMC_A = 1;
	delay2(2);
	MMC_A = 0;
	delay2(2);
	MMC_A = 1;

	print_hex(0x00);
	print_hex(0xff);
	print_hex(0x0a);
	print_hex(0x50);
	print_hex(0xc3);
	ser_puts("\n\r");

	ser_puts("disk_initialize(): ");
	result = disk_initialize(0);	
	print_result(result);

#if 0
	ser_puts("disk_read(): ");
	result = disk_read (0, Buff, 0, 1);
	print_result(result);

	print_buff();
#endif

	ser_puts("mounting filesystem: ");
	fresult = f_mount(0, &fatfs);
	print_result(fresult);
	
	ser_puts("f_opendir "); ser_puts(ptrdir);
	fresult = f_opendir(&dir, ptrdir);
	
	ser_puts("f_readdir:");
	fresult = f_readdir(&dir, &finfo);					print_result(fresult);
	
	ser_puts("f_open "); ser_puts(ptrfile);
	fresult = f_open(&file1, ptrfile, FA_READ);			print_result(fresult);
	
	//ser_puts("f_lseek");
	//fresult = f_lseek(&file1, p2);						print_result(fresult);
	
	ser_puts("f_read 2048:");
	fresult = f_read(&file1, Buff, 2048, &bytesread);	print_result(fresult);
	
	ser_puts("f_close:");
	fresult = f_close(&file1);							print_result(fresult);

	print_buff();

	for(;;) {
		GREEN_LEDS = leds;
		delay1(10);
		leds <<= 1;
		if (leds == 0) leds = 0x01;
	}
	
}