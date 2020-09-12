#include "clock.h"


int set_tod_from_secs(int time_of_day_sec, tod_t *tod){
// Accepts time of day in seconds as an argument and modifies the
// struct pointed at by tod to fill in its hours, minutes,
// etc. fields.  If time_of_day_sec is invalid (negative or larger
// than the number of seconds in a day) does nothing to tod and
// returns 1 to indicate an error. Otherwise returns 0 to indicate
// success. This function DOES NOT modify any global variables
//
// CONSTRAINT: Uses only integer operations. No floating point
// operations are used as the target machine does not have a FPU.
// 
// CONSTRAINT: Limit the complexity of code as much as possible. Do
// not use deeply nested conditional structures. Seek to make the code
// as short, and simple as possible. Code longer than 40 lines may be
// penalized for complexity.

	// not counting leap time.
	const int hr_per_day  = 24;
	const int min_per_hr  = 60;
	const int sec_per_min = 60; 

	if (
		time_of_day_sec < 0 
	||  time_of_day_sec >= sec_per_min * min_per_hr * hr_per_day
	)
		return 1;

	// hours
	const int num_hours = time_of_day_sec / (sec_per_min * min_per_hr);
	time_of_day_sec %= sec_per_min * min_per_hr;
	tod->hours = (num_hours + 11) % 12 + 1;
	// am/pm
	tod->ispm = num_hours / 12;
	// minutes
	tod->minutes = time_of_day_sec / sec_per_min;
	// seconds
	time_of_day_sec %= sec_per_min;
	tod->seconds = time_of_day_sec;

	return 0;
}

int set_display_bits_from_tod(tod_t tod, int *display){
// Accepts a tod and alters the bits in the int pointed at by display
// to reflect how the clock should appear. If any fields of tod are
// negative or too large (e.g. bigger than 12 for hours, bigger than
// 59 for min/sec), no change is made to display and 1 is returned to
// indicate an error. Otherwise returns 0 to indicate success. This
// function DOES NOT modify any global variables
//
// May make use of an array of bit masks corresponding to the pattern
// for each digit of the clock to make the task easier.
// 
// CONSTRAINT: Limit the complexity of code as much as possible. Do
// not use deeply nested conditional structures. Seek to make the code
// as short, and simple as possible. Code longer than 85 lines may be
// penalized for complexity.
	
	if (
		tod.hours   < 0 || tod.hours   > 12
	 || tod.minutes < 0 || tod.minutes > 59
	 || tod.ispm    < 0 || tod.ispm    > 1
	 || tod.seconds < 0 || tod.seconds > 59
	)
		return 1;

	enum {
		minute_ones		= 0,
		minute_tens		= 7,
		hour_ones 		= 14,
		hour_tens		= 21,
		am_pm 			= 28
	};

	const unsigned char num_masks[] = {
		0b00111111, //0
		0b00000110, //1
		0b01011011, //2
		0b01001111, //3
		0b01100110, //4
		0b01101101, //5
		0b01111101, //6
		0b00000111, //7
		0b01111111, //8
		0b01101111 	//9
	};
	const unsigned char ampm_masks[] = {
		0b01,	//am
		0b10 	//pm
	};

	*display = 0;
	*display |= ampm_masks[(int)tod.ispm]		<< am_pm;
	*display |= num_masks[tod.minutes % 10] 	<< minute_ones;
	*display |= num_masks[tod.minutes / 10] 	<< minute_tens;
	*display |= num_masks[tod.hours % 10]		<< hour_ones;
	if(tod.hours / 10)
		*display |= num_masks[tod.hours / 10]	<< hour_tens;

	return 0;
}

int clock_update(){
// Examines the TIME_OF_DAY_SEC global variable to determine hour,
// minute, and am/pm.  Sets the global variable CLOCK_DISPLAY_PORT bits
// to show the proper time.  If TIME_OF_DAY_SEC appears to be in error
// (to large/small) makes no change to CLOCK_DISPLAY_PORT and returns 1
// to indicate an error. Otherwise returns 0 to indicate success.
//
// Makes use of the set_tod_from_secs() and
// set_display_bits_from_tod() functions.
// 
// CONSTRAINT: Does not allocate any heap memory as malloc() is NOT
// available on the target microcontroller.  Uses stack and global
// memory only.
	tod_t time_of_day;
	return set_tod_from_secs(TIME_OF_DAY_SEC, &time_of_day) 
	 ? 1 : set_display_bits_from_tod(time_of_day, &CLOCK_DISPLAY_PORT);
}
