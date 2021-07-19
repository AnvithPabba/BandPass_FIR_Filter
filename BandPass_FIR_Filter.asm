.CSEG
LDI ZL, LOW(COEFF<<1);		Loading the address of the first COEFF into the Z pointer (i.e R30 and R31), Loading last byte of the address of first COEFF into the ZL byte (R30)
LDI ZH, HIGH(COEFF<<1);		Loading first byte of the address of first COEFF into the ZH byte (R31)
LDI XL, 0x60;				Loading 0x60 into the XL byte (R26)	
LDI XH, 0x00;				Loading 0x00 into the XH byte (R27)	
LDI R24, 0x05;.				R24 is the counter for the loop below, As there are 5 COEFF (5-Tap Filter), we load 0x05 into R24. Change it as necessary.

															;Loop to store the COEFF in memory locations starting from 0x0060 upto 0x0060+(NumberOfCoeff)-1
Storing_COEFF_In_SRAM:	LPM R23, Z+;						We Load the memory that Z points to into R23 and then Increment it Immediatly After
						ST X+, R23;							We Write into X the value in R23 and then Increment it
						DEC R24;							We the Decrement R24 (As 1 Loop has Completed)
						CPI R24, 0x00;						We compare 0x00 with the value in R24
						BREQ Storing_COEFF_In_SRAM_Complete;If they are Equal then Break to the Storing_COEFF_In_SRAM_Complete label
						RJMP Storing_COEFF_In_SRAM;			If Not then Loop back to Storing_COEFF_In_SRAM

	Storing_COEFF_In_SRAM_Complete:
	CLR ZL;							After All the Loops are Executed,  Clear the values In ZL and ZH, Clearing ZL
	CLR ZH;							Clearing ZH
	CLR R23;

LDI ZL, LOW(INPUTS<<1);		Loading the address of the first INPUT into the Z pointer (i.e R30 and R31), Loading last byte of the address of first INPUT into the ZL byte (R30)
LDI ZH, HIGH(INPUTS<<1);	Loading first byte of the address of first INPUT into the ZH byte (R31)
LDI YL, 0x8C;				Loading 0x8C into the YL byte (R28)	
LDI YH, 0x00;				Loading 0x00 into the XH byte (R29)	
CLR XL;						Clearing X, First Clearing XL
CLR XH;						Clearing XH
LDI R19, 0x06;.				R19 is the Counter for the BigLoop_Output loop below, The value loaded into the counter should be equal to "theNumberofINPUTS - 0x04" (please refer to the logic given in report)
							;Here I've just Taken 10 Inputs, so thats why I've loaded 0x06 into the Counter (0x0A- 0x04 = 0x06), Change it as necessary
							;Here we must load value (No.OfINPUTS-No.OfCOEFFs+1)


BigLoop_Output:	LDI XL, 0x64;.	Making Xpointer point to 0x0064 memory location, Loading XL as 0x64 (Last byte of X, R26)
				LDI XH, 0x00;	Loading XH as 0x00 (First byte of X, R27)
				LDI R24, 0x05;	R24 is the counter for the SmallLoop_FIR loop below, As there are 5 COEFF (5-Tap Filter) there are 5 loops in the multiplication and addition cycle.
				LDI R18, 0x00;	Loading 0x00 into R18, this will be Incremented if any kind of overflow is detected
				LDI R23, 0x00;	Loading 0x00 into R23, this will be used to Manually Decrement the Xpointer, as there is NO Decrement function such as -X or X-
				LDI R20, 0x00;	Initializing R20 as 0x00, R20 will be used to Decrement the Z at the start of every BigLoop
				LDI R16, 0x00;	Initializing R16 as 0x00, R16 will be used as the lowest byte of the SUM of the FIR Output 
				LDI R17, 0x00;	Initializing R17 as 0x00, R17 will be used as the higher byte of the SUM of the FIR Output
				LDI R18, 0x00;	Initializing R18 as 0x00, R18 has the overflow and is the highest byte of the FIR Output 
								;these 3 registers form the ACCUMULATOR

	SmallLoop_FIR:	LDI XL, 0x64;.		Making Xpointer point to 0x0064 memory location, Loading XL as 0x64 (Last byte of X, R26)
					LDI XH, 0x00;		Loading XH as 0x00 (First byte of X, R27)
					MOV R15, XL;		Moving last bit of value pointed by Xpointer into R15
					SUB R15, R23;		Manually Decrement R15 using R23 (R23 Increments After Every Cycle)
					MOV XL, R15;		Moving back the Decremented R15 into the last bit of Xpointer
					LD R22, X;			Load value pointed by X into R22, this is the h[n-k] term, k=value in R23
					LPM R21, Z+;		Load from memory what Z points to into R21, Then Increment Z, This is x[k]
					MULS R22, R21;		Perform MULS (Signed Multiplication Function, last byte of the Result goes to R0 and the First byte goes to R1)
					ADD R16, R0;		Add R16 and the lower byte from the MULS output
					ADC R17, R1;		Add R17, the Carry from the Previous Addition and the upper byte from the MULS output 
					INC R23;			Increment R23 (Manually decrements Xp next counter)
					BRVC No_Overflow;	Check if theres an Overflow in the Above Addition, if there is then go to the No_Overflow label
					INC R18;			If there is an Overflow then Increment the Overflow Counter
						
					No_Overflow:	CLR R22;			Clear R22 for the next loop
									CLR R21;			Clear R21 for the next loop
									DEC R24;			Decrement the COEFF Counter
									BRNE SmallLoop_FIR;	If R24 is 0x00 then the Small Loops over amd its time to Store the Outputs 
														;(If R24 is 0x00 then all the multiplications and additions are done in the small loop)

									ST Y+, R18;			Storing The Overflow Byte in SRAM
									ST Y+, R17;			Storing The Higher Byte in SRAM
									ST Y+, R16;			Storing The Lower Byte in SRAM
									MOV R20, ZL;		Decrementing the Z pointer by 4 places
									SUBI R20, 0x04;.	(As We've Already Incremented it 5 times in the loop, so by decrementing it by 4, next time Z will just be Z+)
									MOV ZL, R20;
									DEC R19;			Decrementing the BigLoop counter i.e R19
									BRNE BigLoop_Output;Checking if all the Loops are Completed i.e R19 == 0x00, if notover then Loop again
									RJMP END;			If its over then Jump to the End label

END: NOP;	End Label is the End of the program

COEFF: .db 0xCE, 0x0D, 0x59, 0x0D, 0xCE; These are the 5 tap COEFF given in the PDF after Scaling by 2^7
INPUTS: .db 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80;	If input is DC with an Amplitude of 1, These are 10 of those Inputs Scaled by 2^7
;6 inputs of a sinusod with ampkitude 1 and freq 1800 Hz is:
; 0x00, 0x79, 0x4B, 0xB4, 0x86, 0x00, 0x79, 0x4B, 0xB4, 0x86
; 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80
;128*-0.30696,128*0.24256,128*1.960611,128*-0.92577,128*2.533311,128*-0.95565,128*2.148561,128*0.513147,128*-0.04464,128*0.505999,128*-0.1451,128*1.054625,128*0.99752,128*-0.08789,128*-0.85484,128*0.475384,128*0.507766,128*1.154118,128*0.34611,128*0.732507,128*0.514595,128*-0.21482,128*0.208045,128*-0.55735,128*0.628936,128*-0.81206,128*-0.7567,128*-0.57308,128*-2.08439,128*1.018295,128*0.230217,-128*0.53445,128*0.970097,128*-1.21166,128*-0.07238,128*-0.17093,128*0.225981,128*0.221487,128*-0.61229,128*-0.02127,128*-128*0.11673,128*0.444383,128*0.773973,128*0.785305,128*-0.61142,128*128*0.054766,128*-0.85953,128*-0.7883,128*-0.00485,128*1.0850194 WHITE NOISE INPUTS
;rows with a . after the ; represent values that need to be changed when increasing taps or inputs
