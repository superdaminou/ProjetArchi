#/* $begin seq-all-hcl */
#/* $begin seq-plus-all-hcl */
####################################################################
#  HCL Description of Control for Single Cycle Y86 Processor SEQ   #
#  Copyright (C) Randal E. Bryant, David R. O'Hallaron, 2002       #
####################################################################

####################################################################
#    C Include's.  Don't alter these                               #
####################################################################

quote '#include <stdio.h>'
quote '#include "isa.h"'
quote '#include "sim.h"'
quote 'int sim_main(int argc, char *argv[]);'
quote 'int gen_pc(){return 0;}'
quote 'int main(int argc, char *argv[])'
quote '  {plusmode=0;return sim_main(argc,argv);}'

####################################################################
#    Declarations.  Do not change/remove/delete any of these       #
####################################################################

##### Symbolic representation of Y86 Instruction Codes #############
intsig NOP 	'I_NOP'
intsig HALT	'I_HALT'
intsig RRMOVL	'I_RRMOVL'
#intsig IRMOVL	'I_IRMOVL'
intsig RMMOVL	'I_RMMOVL'
intsig MRMOVL	'I_MRMOVL'
intsig OPL	'I_ALU'
#intsig IOPL	'I_ALUI'
intsig JXX	'I_JXX'
intsig CALL	'I_CALL'
intsig RET	'I_RET'
intsig PUSHL	'I_PUSHL'
intsig POPL	'I_POPL'
intsig JMEM	'I_JMEM'
intsig JREG	'I_JREG'
intsig LEAVE	'I_LEAVE'
intsig ENTER	'I_ENTER'
##### Symbolic representation of Y86 Registers referenced explicitly #####
intsig RESP     'REG_ESP'    	# Stack Pointer
intsig REBP     'REG_EBP'    	# Frame Pointer
intsig RNONE    'REG_NONE'   	# Special value indicating "no register"

##### ALU Functions referenced explicitly                            #####
intsig ALUADD	'A_ADD'		# ALU should add its arguments

##### Signals that can be referenced by control logic ####################

##### Fetch stage inputs		#####
intsig pc 'pc'				# Program counter
##### Fetch stage computations		#####
intsig icode	'icode'			# Instruction control code
intsig ifun	'ifun'			# Instruction function
intsig rA	'ra'			# rA field from instruction
intsig rB	'rb'			# rB field from instruction
intsig valC	'valc'			# Constant from instruction
intsig valP	'valp'			# Address of following instruction

##### Decode stage computations		#####
intsig valA	'vala'			# Value from register A port
intsig valB	'valb'			# Value from register B port

##### Execute stage computations	#####
intsig valE	'vale'			# Value computed by ALU
boolsig Bch	'bcond'			# Branch test

##### Memory stage computations		#####
intsig valM	'valm'			# Value read from memory


####################################################################
#    Control Signal Definitions.                                   #
####################################################################

################ Fetch Stage     ###################################

# Does fetched instruction require a regid byte?
bool need_regids =
	icode in { RRMOVL, OPL, PUSHL, POPL, RMMOVL, MRMOVL };

# Does fetched instruction require a constant word?
bool need_valC =
	icode in {  RRMOVL,RMMOVL, MRMOVL, JXX, CALL,OPL};

bool instr_valid = icode in 
	{ NOP, HALT, RRMOVL, RMMOVL, MRMOVL,
	       OPL,  JXX, CALL, RET, PUSHL, POPL, ENTER};

int instr_next_ifun = [
	icode == ENTER 	&& ifun == 0 : 1;
	1:-1;
];

################ Decode Stage    ###################################

## What register should be used as the A source?

	
int srcA = [
	icode == ENTER && ifun == 0 : REBP;
	icode == ENTER && ifun == 1 : RESP;

	icode in { RRMOVL, RMMOVL, OPL, PUSHL } : rA;
	icode in { POPL, RET } : RESP;
	1 : RNONE; # Don't need register
];

## What register should be used as the B source?
int srcB = [

	icode == ENTER && ifun == 0 : RESP;

	icode in { OPL, RMMOVL,MRMOVL } : rB;

	

	icode in { PUSHL, POPL, CALL, RET } : RESP;
	1 : RNONE;  # Don't need register
];

## What register should be used as the E destination?
int dstE = [

 	icode == ENTER && ifun == 0 : RESP;
	icode == ENTER && ifun == 1 : REBP;

	icode in { RRMOVL, OPL} : rB;

	

	icode in { PUSHL, POPL, CALL, RET } : RESP;
	1 : RNONE;  # Don't need register
];

## What register should be used as the M destination?
int dstM = [
	icode in { MRMOVL, POPL } : rA;
	1 : RNONE;  # Don't need register
];

################ Execute Stage   ###################################

## Select input A to ALU
int aluA = [

	icode == ENTER && ifun == 0 : -4;
	icode == ENTER && ifun == 1 : valA;

	icode == OPL && rA == RNONE : valC;
	icode == OPL : valA;
	
	icode == RRMOVL && rA == RNONE : valC;
	icode == RRMOVL : valA;
	
	icode in {  RMMOVL, MRMOVL } : valC;
	icode in { CALL, PUSHL } : -4;
	icode in { RET, POPL } : 4;
	# Other instructions don't need ALU
];

## Select input B to ALU
int aluB = [

	icode == ENTER && ifun == 0 : valB;
	icode == ENTER && ifun == 1 : 0;

	icode in { RMMOVL, MRMOVL, OPL, CALL, PUSHL, RET, POPL } : valB;
	icode == RRMOVL : 0;
	# Other instructions don't need ALU
];

## Set the ALU function
int alufun = [
	icode == OPL: ifun;
	1 : ALUADD;
];

## Should the condition codes be updated?
bool set_cc = icode in { OPL };

################ Memory Stage    ###################################

## Set read control signal
bool mem_read = icode in { MRMOVL, POPL, RET };

## Set write control signal
bool mem_write = icode in { RMMOVL, PUSHL, CALL } || (icode == ENTER && ifun == 0);

## Select memory address
int mem_addr = [

	icode == ENTER && ifun == 0 : valE;

	icode in { RMMOVL, PUSHL, CALL, MRMOVL } : valE;
	icode in { POPL, RET } : valA;
	# Other instructions don't need address
];

## Select memory input data
int mem_data = [
	icode == ENTER && ifun == 0 : valA;
	# Value from register
	icode in { RMMOVL, PUSHL } : valA;
	# Return PC
	icode == CALL : valP;
	# Default: Don't write anything
];

################ Program Counter Update ############################

## What address should instruction be fetched at

int new_pc = [
	# Call.  Use instruction constant
	icode == CALL : valC;
	# Taken branch.  Use instruction constant
	icode == JXX && Bch : valC;
	# Completion of RET instruction.  Use value from stack
	icode == RET : valM;
	# Default: Use incremented PC
	1 : valP;
];
#/* $end seq-plus-all-hcl */
#/* $end seq-all-hcl */
