#
# BYOC-24 Assembler
#
# Copyright 2019-20 by RBW
#



import re
pvar = re.compile("[A-E,H-L,M]")
patt = re.compile("[^\t]+")

jmp_list = ['JZ','JNZ','JC','JNC']
ret_list = ['RZ','RNZ','RC','RNC']
rtr_list = ['RLC','RRC','RAL','RAR']
alu0_list = ['ADD','ADC','SUB','SBB']
alu1_list = ['AND','NOT']
rii_list = ['ADI','ACI','SUI','SBI','ANI','ORI','XRI','NTI']
bin_list = ['0','1']
hex_list = ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F']
opc_list = ['+','-','*','/',')']
spc_list = ['_','-']

import sys

arg_list = sys.argv

source = arg_list[1]
source_file = source + ".asm"
object_type = arg_list[2]

def TrimUcase(x):
    x = x.upper()
    x = x.strip(' ')
    return x

def Hex4S(x):
    x = (hex(ord(x) + 65536))
    x = x[-4:]
    return x

def Hex4(x):
    x = (hex(x + 65536))
    x = x[-4:]
    return x

def Hex6(x):
    x = (hex(x + 16777216))
    x = x[-6:]
    return x

stack = []    

def expression(e):
    e=term(e)
    if e == "":
        return
    elif e[0] == '+':
        e=term(e[1:len(e)])
        add()
        return e
    elif e[0] == '-':
        e=term(e[1:len(e)])
        sub()
        return e
    else:
        return e
        
def add():
    v0 = stack.pop()
    v1 = stack.pop()
    stack.append(v0+v1)
    
def sub():
    v0 = stack.pop()
    v1 = stack.pop()
    stack.append(v1-v0) 
    
def mul():
    v0 = stack.pop()
    v1 = stack.pop()
    stack.append(v0*v1)
    
def div():
    v0 = stack.pop()
    v1 = stack.pop()
    stack.append(int(v1/v0))
    
def factor(v):
    
    l = len(v)
    if v[0] == '(':
        v = expression(v[1:len(v)])
        if v[0] != ')':
            sys.exit("Missing closed parenthese")
        else:
            v = v[1:len(v)]
            return v
    elif v[0] == "\'":
        stack.append(ord(v[1:2]))
        if v[2] != "\'":
            system.exit("Missing apostrophy")
        return v[3:l]
    elif v[0:2] == "0B":
        l = len(v)
        v = v[2:l]
        l = l - 2
        m = 0
        n = 1
        for i in range(l):
            if len([sub for sub in bin_list if sub in v[i]]) == 1:
                m = m + n
            else:
                n = 0
        if m == 0:
            sys.exit("Invalid binary constant")
        stack.append(int(v[0:m],2))
        return v[m:l]
    elif v[0:2] == "0X":
        l = len(v)
        v = v[2:l]
        l = l - 2
        m = 0
        n = 1
        for i in range(l):
            if len([sub for sub in hex_list if sub in v[i]]) == 1:
                m = m + n
            else:
                n = 0
        if m == 0:
            sys.exit("Invalid hex constant")
        stack.append(int(v[0:m],16))
        return v[m:l]
    elif v[0:3] == "LO(":
        if v[2] == '(':
            v = expression(v[3:len(v)])
            if v[0] != ')':
                sys.exit("Missing closed parenthese")
            else:
                v0 = stack.pop()
                v1 = v0 % 256
                stack.append(v1)
                return v[1:len(v)]
    elif v[0:3] == "HI(":
        if v[2] == '(':
            v = expression(v[3:len(v)])
            if v[0] != ')':
                sys.exit("Missing closed parenthese")
            else:
                v0 = stack.pop()
                v1 = int((v0 - v0 % 256) / 256)
                stack.append(v1)
                return v[1:len(v)]
    else:
        l = len(v)
        m = 0
        n = 1
        for i in range(l):
            if len([sub for sub in opc_list if sub in v[i]]) == 0:
                m = m + n
            else:
                n = 0
        v0 = v[0:m]
        if v0.isdigit():
            v1 = int(v0)
            stack.append(v1)
            return v[m:l]
        elif v0.isalnum() or len([sub for sub in spc_list if sub in v0]) == 1:
            v1 = d_label[v0]
            stack.append(v1)
            return v[m:l]
        else:
            sys.exit("Unknown variable: " + v + " Source line:" + str(source_line))

def term(t):
    t = factor(t)
    if t == "":
        return t
    elif t[0] == '*':
        t=factor(t[1:len(t)])
        mul()
        return t
    elif t[0] == '/':
        t=term(t[1:len(t)])
        div()
        return t
    else:
        return t   

    
loc_dest = 262144   #LSB location of destination code
loc_srce = 32768    #LSB location of source code
loc_type = 2097152  #LSB of TYPE code
loc_oper = 2048     #LSB of ALU operator code
loc_jzc = 262144    #LSB of jump conditional code
loc_jmp = 1048576   #LSB of jump unconditional code
loc_crt = 1048576   #LSB of call unconditional code
spcl0 = 128         #Special control bit
spcl1 = 256         #Special control bit
spcl2 = 512         #Special control bit
spcl3 = 1024        #Special control bit
ldi0 = 65536        #Special control bit
ldi1 = 131072       #Special control bit
ldi2 = 262144       #Special control bit
ldi3 = 524288       #Special control bit
ldi4 = 1048576      #Special control bit

d_opcode = { 
"MVI": 0,
"MOV": 1,
"LSR": 2,
"IDX": 3,
"RRO": 4,
"XIO": 5,
"CRT": 6,
"JPC": 7,
"ADD": 0,
"ADI": 0,
"SUB": 1,
"SUI": 1,
"CMP": 1,
"CPI": 1,
"ADC": 2,
"ACI": 2,
"SBB": 3,
"SBI": 3,
"AND": 4,
"ANI": 4,
"OR": 5,
"ORI": 5,
"XOR": 6,
"XRI": 6,
"NOT": 7,
"NTI": 7,
"RLC": 8,
"RRC": 9,
"RAL": 10,
"RAR": 11,
"INR": 12,
"DCR": 13,
"STC": 14,
"JZ": 0,
"JNZ": 1,
"JC": 2,
"JNC": 3,
"JMP": 1,
"PCHL": 1,
"LDR": 0,
"LDX": 1,
"STX": 1,
"STR": 2,
"INP": 0,
"OUT": 1,
"POP": 2,
"PUSH": 3,
"CALL": 0,
"RET": 1,
"RZ": 4,
"RNZ": 6,
"RC": 5,
"RNC": 7,
"IRAM": 0,
"IROM": 1,
"INX": 0,
"DCX": 1,
"LDHL": 0,
"LXI": 0,
"ADHL": 1,
"CPHL": 2,
"IRAML": 4,
"IRAMH": 5,
"IROML": 6,
"IROMH": 7
}

d_srce = { 
"M": 0,
"L": 1,
"H": 2,
"E": 3,
"D": 4,
"C": 5,
"B": 6,
"A": 7
}

d_dest = {
"M": 0,
"L": 1,
"H": 2,
"E": 3,
"D": 4,
"C": 5,
"B": 6,
"A": 7
}

object_address = 0

d_label = {
    }

data_rom = []
prgm_rom = []

f = open(source_file, "r")

source_line = 1

line = TrimUcase(f.readline())
while line[0:4].upper() != "DATA":
    if line[0] != ";":
        if line[0] == '\t':
            line = "?" + line
        if line.count("\t") == 1:
            line = line + "\t?"
        if line.count("\n") > 0:
            line = line.replace("\n","")
        linelist = patt.findall(line)
        source_label = TrimUcase(linelist[0])
        source_opcode = TrimUcase(linelist[1])
        if source_opcode[0:4] in d_opcode:
            if source_label != "?":
                d_label[source_label[:-1]] = object_address
                object_address += 1
            else:
                object_address += 1
        else:
            sys.exit("No such opcode")
    line = TrimUcase(f.readline())
    source_line += 1
    
object_address = 0
line = f.readline()
source_line += 1
while line[0:3].upper() != "END":
    if line[0] != ';':
        if line[0] == '\t':
            line = "?" + line
        if line.count("\t") == 1:
            line = line + "\t?"
        if line.count("\n") > 0:
            line = line.replace("\n","")
        linelist = patt.findall(line)
        source_label = TrimUcase(linelist[0])
        source_opcode = TrimUcase(linelist[1])
        if source_opcode == "DB":
            if source_label != "?":
                d_label[source_label[:-1]] = object_address
            source_operand = TrimUcase(linelist[2]) 
            operand_list = source_operand.split(",")
            for x in operand_list:
                rval = expression(TrimUcase(x))
                data_rom.append(Hex4(stack.pop()))
                object_address +=1
        elif source_opcode == "DS":
            source_operand = linelist[2] 
            thisMsgLen = len(source_operand)
            if thisMsgLen == 0:
                sys.exit("Invalid message")
            d_label[source_label[:-1]] = object_address
            object_address = object_address + thisMsgLen + 1
            for i in range(0,thisMsgLen):
                data_rom.append(Hex4S(source_operand[i]))
            data_rom.append("0000")
        elif source_opcode == "EQU":
            source_operand = TrimUcase(linelist[2]) 
            rval = expression(source_operand)
            d_label[source_label] = stack.pop()
    line = f.readline()
    source_line += 1
    
f.close()
               
f = open(source_file, "r")
f_list = open(source + "-list.txt", "w")
object_address = 0
source_line = 1

line = TrimUcase(f.readline())
source_line += 1
while line[0:4] != "DATA":
    
    if line[0] != ';':
        if line[0] == '\t':
            line = '?' + line
        if line.count("\t\t") == 1:
            line = line + "\t?"
        if line.count("\t") == 1:
            line = line + "\t?"
        if line.count("\n") > 0:
            line = line.replace("\n","")
        linelist = patt.findall(line)
        source_label = TrimUcase(linelist[0])
        source_opcode = TrimUcase(linelist[1])
        source_opcode = source_opcode[0:4]
        source_operand = TrimUcase(linelist[2])
        current_object_address = object_address
        if source_opcode == "CPI":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if dest[0] == 'I':
                prgm_rom.append(Hex6(d_opcode["IDX"] * loc_type + d_opcode[dest] * ldi2 + ldi0 + ldi3 + value))
                object_address += 1
            else:
                if pvar.findall(dest) == 0:
                    sys.exit("Invalid variable")
                prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + spcl1 + spcl2 + value ))
                object_address += 1
        elif source_opcode == "INR" or source_opcode == "DCR":
            dest = TrimUcase(source_operand)
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + d_dest[dest] * loc_dest + d_opcode[source_opcode] * loc_oper))
            object_address += 1            
        elif source_opcode == "INP":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["XIO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * spcl1 + value))
            object_address += 1
        elif source_opcode == "OUT":
            operand_list = source_operand.split(",",1)
            rval = expression(operand_list[0].strip())
            value = stack.pop()
            srce = operand_list[1].strip()
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["XIO"] * loc_type + loc_srce * d_srce[srce] + d_opcode[source_opcode] * spcl1 + value))
            object_address += 1
        elif source_opcode == "POP":
            dest = source_operand.strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["XIO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * spcl1))
            object_address += 1
        elif source_opcode == "PUSH":
            srce = source_operand.strip()
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["XIO"] * loc_type + loc_srce * d_srce[srce] + d_opcode[source_opcode] * spcl1))
            object_address += 1
        elif source_opcode == "STX":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if dest[0] == "(":
                dest = dest[1:5]
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            if dest != "IRAM" and dest != "IROM":
                sys.exit("Invalid index variable")
            prgm_rom.append(Hex6(d_opcode["LSR"] * loc_type + loc_srce * d_srce[srce] + d_opcode["STR"] * spcl1 + spcl3 ))
            object_address += 1
        elif source_opcode == "STR":
            operand_list = source_operand.split(",",1)
            rval = expression(operand_list[0].strip())
            value = stack.pop()
            srce = operand_list[1].strip()
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["LSR"] * loc_type + loc_srce * d_srce[srce] + d_opcode[source_opcode] * spcl1 + value))
            object_address += 1
        elif source_opcode == "LDX":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if srce[0] == "(":
                srce = srce[1:5]
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if srce != "IRAM" and srce != "IROM":
                sys.exit("Invalid index variable")
            prgm_rom.append(Hex6(d_opcode["LSR"] * loc_type + loc_dest * d_dest[dest] + loc_srce * d_srce["M"] + d_opcode[srce] * spcl2 + d_opcode[source_opcode] * spcl1 ))
            object_address += 1
        elif source_opcode == "LDR":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["LSR"] * loc_type + loc_dest * d_dest[dest] + d_srce["M"] * loc_srce + d_opcode[source_opcode] * spcl1 + value))
            object_address += 1
        elif source_opcode == "LXI":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            if dest != "IRAM" and dest != "IROM":
                sys.exit("Invalid index variable")
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["IDX"] * loc_type + d_opcode[dest] * ldi2 + d_opcode["LXI"] * ldi0 + ldi3 + value))
            object_address += 1
        elif source_opcode == "INX" or source_opcode == "DCX":
            dest = TrimUcase(source_operand)
            if dest != "IRAM" and dest != "IROM":
                sys.exit("Invalid index variable")
            prgm_rom.append(Hex6(d_opcode["IDX"] * loc_type + d_opcode[dest] * ldi2 + ldi1 + d_opcode[source_opcode] * ldi0))
            object_address += 1            
        elif source_opcode == "LDHL" or source_opcode == "ADHL":
            dest = TrimUcase(source_operand)
            if dest != "IRAM" and dest != "IROM":
                sys.exit("Invalid index variable")
            prgm_rom.append(Hex6(d_opcode["IDX"] * loc_type + d_opcode[dest] * ldi2 + d_opcode[source_opcode] * ldi0))
            object_address += 1            
        elif source_opcode == "CPHL":
            dest = TrimUcase(source_operand)
            if dest != "IRAM" and dest != "IROM":
                sys.exit("Invalid index variable")
            prgm_rom.append(Hex6(d_opcode["IDX"] * loc_type + d_opcode[dest] * ldi2 + ldi0 + ldi3 + ldi4))
            object_address += 1            
        elif source_opcode == "MVI":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["MVI"] * loc_type + loc_dest * d_dest[dest] + value))
            object_address += 1
        elif len([sub for sub in rii_list if sub in source_opcode]) == 1:
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            rval = expression(operand_list[1].strip())
            value = stack.pop()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + spcl2 + value))
            object_address += 1
        elif source_opcode == 'STC':
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + d_opcode[source_opcode] * loc_oper))
            object_address += 1
        elif source_opcode == "CMP":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + spcl1 + loc_srce * d_srce[srce]))
            object_address += 1
        elif len([sub for sub in alu0_list if sub in source_opcode]) == 1:
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + loc_srce * d_srce[srce]))
            object_address += 1
        elif len([sub for sub in alu1_list if sub in source_opcode]) >= 1:
            operand_list = source_operand.split(",")
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + loc_srce * d_srce[srce]))
            object_address += 1
        elif source_opcode == 'OR':
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + loc_srce * d_srce[srce]))
            object_address += 1
        elif source_opcode == 'XOR':
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if pvar.findall(dest) == 0:
                sys.exit("Invalid variable")
            if pvar.findall(srce) == 0:
                sys.exit("Invalid variable")
            prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + loc_dest * d_dest[dest] + d_opcode[source_opcode] * loc_oper + loc_srce * d_srce[srce]))
            object_address += 1
        elif source_opcode[0] == "R":
            if source_opcode[1:3] == 'ET':
                prgm_rom.append(Hex6(d_opcode["CRT"] * loc_type + d_opcode[source_opcode] * loc_crt))
                object_address += 1
            elif len([sub for sub in rtr_list if sub in source_opcode]) == 1:
                dest = TrimUcase(source_operand)
                if pvar.findall(dest) == 0:
                    sys.exit("Invalid variable")
                prgm_rom.append(Hex6(d_opcode["RRO"] * loc_type + d_dest[dest] * loc_dest + d_opcode[source_opcode] * loc_oper + d_srce[dest] * loc_srce))
                object_address += 1            
            elif len([sub for sub in ret_list if sub in source_opcode]) == 1:
                prgm_rom.append(Hex6(d_opcode["CRT"] * loc_type + d_opcode["RET"] * loc_crt + d_opcode[source_opcode] * ldi1))
                object_address += 1                
        elif source_opcode == "CALL":
            rval = expression(source_operand.strip())
            value = stack.pop()
            value = (value | (d_opcode["CRT"] * loc_type)) + d_opcode[source_opcode] * loc_crt
            prgm_rom.append(Hex6(value))
            object_address += 1
        elif source_opcode == "PCHL":
            prgm_rom.append(Hex6(d_opcode["JPC"] * loc_type + d_opcode[source_opcode] * loc_jmp + ldi1))
            object_address += 1
        elif source_opcode == "MOV":
            operand_list = source_operand.split(",",1)
            dest = operand_list[0].strip()
            srce = operand_list[1].strip()
            if srce[0] == 'I':
                prgm_rom.append(Hex6(d_opcode["MOV"] * loc_type + loc_dest * d_dest[dest] + loc_srce * 0 + d_opcode[srce] * spcl0))
                object_address += 1
            else:
                if pvar.findall(dest) == 0:
                    sys.exit("Invalid variable")
                if pvar.findall(srce) == 0:
                    sys.exit("Invalid variable")
                prgm_rom.append(Hex6(d_opcode["MOV"] * loc_type + loc_dest * d_dest[dest] + loc_srce * d_srce[srce]))
                object_address += 1
        elif source_opcode[0] == 'J':
            if source_opcode[1:3] == 'MP':
                rval = expression(source_operand.strip())
                value = stack.pop()
                value = (value | (d_opcode["JPC"] * loc_type)) + d_opcode[source_opcode] * loc_jmp
                prgm_rom.append(Hex6(value))
                object_address += 1
            else:
                if len([sub for sub in jmp_list if sub in source_opcode]) == 0:
                    sys.exit("Unknown opcode: " + source_opcode)
                rval = expression(source_operand.strip())
                value = stack.pop()
                value = (value | (d_opcode["JPC"] * loc_type)) + d_opcode[source_opcode] * loc_jzc
                prgm_rom.append(Hex6(value))
                object_address += 1
    
        if line[0] == "?":
            line = "\t" + line[1:]
        f_list.write(Hex4(object_address - 1) + "  " + prgm_rom[-1] + "  " + line + "\n")
               
        if current_object_address == object_address:
            sys.exit("Unresolvable instruction")
    line = TrimUcase(f.readline())
    source_line += 1
        
f_list.close

# print(d_label) 
# print(data_rom)
# print(prgm_rom)

if object_type.upper() == "-L":
        
    f = open(source + "-prom.txt", "w")
    f.write("v2.0 raw" + "\n")
    for s in prgm_rom:
        f.write(s + "\n")
    f.close()
    
    f = open(source + "-drom.txt", "w")
    f.write("v2.0 raw" + "\n")
    for s in data_rom:
        f.write(s + "\n")
    f.close()
    
elif object_type.upper() == "-C":
    
    f = open("BYOC-PROM.mif", "w")
    
    f.write("\n" + "-- Quartus Prime generated Memory Initialization File (.mif)" + "\n\n")
    f.write("-- " + source + ".asm\n\n")
    f.write("WIDTH=24;" + "\n")
    f.write("DEPTH=65536;" + "\n\n")
    f.write("ADDRESS_RADIX=UNS;" + "\n")
    f.write("DATA_RADIX=HEX;" + "\n\n")
    f.write("CONTENT BEGIN" + "\n\n")
    object_address = 0
    for s in prgm_rom:
        f.write("       " + str(object_address) + "    :    " + s + ";\n")
        object_address += 1
    f.write("\n\n             [" + str(object_address) + "..65535]    :    000000;\nEND")
    f.close()
    
    f = open("BYOC-DROM.mif", "w")
    
    f.write("\n" + "-- Quartus Prime generated Memory Initialization File (.mif)" + "\n\n")
    f.write("-- " + source + ".asm\n\n")
    f.write("WIDTH=8;" + "\n")
    f.write("DEPTH=65536;" + "\n\n")
    f.write("ADDRESS_RADIX=UNS;" + "\n")
    f.write("DATA_RADIX=HEX;" + "\n\n")
    f.write("CONTENT BEGIN" + "\n\n")
    object_address = 0
    for s in data_rom:
        f.write("       " + str(object_address) + "    :    " + s + ";\n")
        object_address += 1
    f.write("\n\n             [" + str(object_address) + "..65535]    :    000000;\nEND")
    f.close()


else:
    sys.exit("Unknown object type")
    
print("Assembly Completed")





