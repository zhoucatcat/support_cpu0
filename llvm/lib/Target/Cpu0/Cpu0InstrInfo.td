
def SDT_Cpu0Ret : SDTypeProfile<0, 1, [SDTCisInt<0>]>;

def Cpu0Ret : SDNode<"Cpu0ISD::Ret", SDT_Cpu0Ret,
                     [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

include "Cpu0InstrFormats.td"

// Signed Operand    单一操作数，  "DecodeSimm16" 是后续需要实现的接口；
def simm16 : Operand<i32> {
  let DecoderMethod = "DecodeSimm16";
}

// Address operand   地址操作数定义
def mem : Operand<iPTR> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops CPURegs, simm16);
  let EncoderMethod = "getMemEncoding";
}

// 定义立即数约束；
def immSExt16 : PatLeaf<(imm), [{ return isInt<16>(N->getSExtValue()); }]>;

// 栈地址约束；
// Cpu0 Address Mode! SDNode frameindex could posibily be a match since
// load and store instructions from stack used it.
def addr : ComplexPattern<iPTR, 2, "SelectAddr",
                          [frameindex], [SDNPWantParent]>;

//===----------------------------------------------------------------------===//
// Pattern fragment for load/store
//===----------------------------------------------------------------------===//
// 做了合法性约束？
class AlignedLoad<PatFrag Node>
  : PatFrag<(ops node:$ptr), (Node node:$ptr),
            [{
              LoadSDNode *LD = cast<LoadSDNode>(N);
              return LD->getMemoryVT().getSizeInBits()/8 <= LD->getAlignment();
            }]>;

class AlignedStore<PatFrag Node>
  : PatFrag<(ops node:$val, node:$ptr), (Node node:$val, node:$ptr),
            [{
              StoreSDNode *ST = cast<StoreSDNode>(N);
              return ST->getMemoryVT().getSizeInBits()/8 <= ST->getAlignment();
            }]>;

// Load/Store PatFrags
def load_a  : AlignedLoad<load>;
def store_a : AlignedStore<store>;

class ArighLogicI<bits<8> op, string instrAsm, SDNode opNode,
                  Operand od, PatLeaf immType, RegisterClass regClass>
  : FL<op, (outs GPROut:$ra), (ins regClass:$rb, od:$imm16),
       !strconcat(instrAsm, "\t$ra, $rb, $imm16"),
       [(set GPROut:$ra, (opNode regClass:$rb, immType:$imm16))], IIAlu> {
  let isReMaterializable = 1;
}

class FMem<bits<8> op, dag outs, dag ins, string asmStr, list<dag> pattern,
           InstrItinClass itin>
  : FL<op, outs, ins, asmStr, pattern, itin> {
  bits<20> addr;
  let Inst{19-16}   = addr{19-16};
  let Inst{15-0}    = addr{15-0};
  let DecoderMethod = "DecodeMem";
}

// Memory Load/Store
let canFoldAsLoad = 1 in
class LoadM<bits<8> op, string instrAsm, PatFrag opNode, RegisterClass regClass,
            Operand od, bit pseudo>
  : FMem<op, (outs regClass:$ra), (ins od:$addr),
         !strconcat(instrAsm, "\t$ra, $addr"),
         [(set regClass:$ra, (opNode addr:$addr))], IILoad> {
  let isPseudo = pseudo;
}

class StoreM<bits<8> op, string instrAsm, PatFrag opNode, RegisterClass regClass,
             Operand od, bit pseudo>
  : FMem<op, (outs), (ins regClass:$ra, od:$addr),
         !strconcat(instrAsm, "\t$ra, $addr"),
         [(opNode regClass:$ra, addr:$addr)], IIStore> {
  let isPseudo = pseudo;
}






// 32-bit load
multiclass LoadM32<bits<8> op, string instrAsm,
                   PatFrag opNode, bit pseudo=0> {
  def NAME# : LoadM<op, instrAsm, opNode, GPROut, mem, pseudo>;
}

// 32-bit store
multiclass StoreM32<bits<8> op, string instrAsm,
                    PatFrag opNode, bit pseudo=0> {
  def NAME# : StoreM<op, instrAsm, opNode, CPURegs, mem, pseudo>;
}

// JumpFR
let isBranch=1, isTerminator=1, isBarrier=1, hasDelaySlot=1,
    isIndirectBranch=1 in
class JumpFR<bits<8> op, string instrAsm, RegisterClass regClass>
  : FL<op, (outs), (ins regClass:$ra),
       !strconcat(instrAsm, "\t$ra"), [(brind regClass:$ra)], IIBranch> {
  let rb = 0;
  let imm16 = 0;
}

// Return
class RetBase<RegisterClass regClass> : JumpFR<0x3c, "ret", regClass> {
  let isReturn = 1;
  let isCodeGenOnly = 1;
  let hasCtrlDep = 1;
  let hasExtraSrcRegAllocReq = 1;
}


//===----------------------------------------------------------------------===//
// Instruction definition
//===----------------------------------------------------------------------===//

// Load and Store Instructions
// already aligned
defm LD      : LoadM32<0x01,   "ld",   load_a>;
defm ST      : StoreM32<0x02,  "st",   store_a>;

// Arithmetic Instructions (ALU Immediate)
def ADDiu    : ArighLogicI<0x09, "addiu", add, simm16, immSExt16, CPURegs>;

// Arithmetic Instructions (3-Operand, R-Type)

// Shift Instructions

// Jump Instructions
def JR       : JumpFR<0x3c, "jr", GPROut>;

def RET      : RetBase<GPROut>;

// No Operation Instructions
let addr=0 in
  def NOP    : FJ<0, (outs), (ins), "nop", [], IIAlu>;

  //===----------------------------------------------------------------------===//
  // Arbitrary patterns that map to one or more instructions
  //===----------------------------------------------------------------------===//

  // Small Immediates
  def : Pat<(i32 immSExt16:$in), (ADDiu ZERO, imm:$in)>;

