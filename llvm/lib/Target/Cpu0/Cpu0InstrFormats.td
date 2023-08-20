// 定义指令类型
class Format<bits<4> val>{
  bits<4> Value = val;
}

def Pseudo	: Format<0>;
def FrmA	: Format<1>;
def FrmL	: Format<2>;
def FrmJ	: Format<3>;
def FrmOther	: Format<4>;

// 通用 Cpu0 指令格式
class Cpu0Inst<dag outs, dag ins, string asmStr, list<dag> pattern,
               InstrItinClass itin, Format f> : Instruction
{
  field bits<32> Inst;
  Format Form = f;
  let Namespace = "Cpu0";
  let Size = 4;
  bits<8> Opcode = 0;

  let Inst{31-24} = Opcode;

  let OutOperandList = outs;
  let InOperandList = ins;

  let AsmString = asmStr;
  let Pattern = pattern;
  let Itinerary = itin;

  bits<4> FormBits = f.Value;

  let TSFlags{3-0} = FormBits;

  let DecoderNamespace = "Cpu0";

  field bits<32> SoftFail = 0;
}

class FA<bits<8> op, dag outs, dag ins, string asmStr, list<dag> pattern,
         InstrItinClass itin> : Cpu0Inst<outs, ins, asmStr, pattern, itin, FrmA>
{
  bits<4> ra;
  bits<4> rb;
  bits<4> rc;
  bits<12> shamt;

  let Opcode = op;

  let Inst{23 - 20} = ra;
  let Inst{19 - 16} = rb;
  let Inst{15 - 12} = rc;
  let Inst{15 - 12} = rc;
  let Inst { 11 - 0 } = shamt;
}


class FL<bits<8> op, dag outs, dag ins, string asmStr,
         list<dag> pattern, InstrItinClass itin>
  : Cpu0Inst<outs, ins, asmStr, pattern, itin, FrmL>
{
  bits<4>  ra;
  bits<4>  rb;
  bits<16> imm16;

  let Opcode = op;

  let Inst{23-20} = ra;
  let Inst{19-16} = rb;
  let Inst{15-0}  = imm16;
}

//===----------------------------------------------------------------------===//
// Format J instruction class in Cpu0 : <|opcode|address|>
//===----------------------------------------------------------------------===//

class FJ<bits<8> op, dag outs, dag ins, string asmStr,
         list<dag> pattern, InstrItinClass itin>
  : Cpu0Inst<outs, ins, asmStr, pattern, itin, FrmJ>
{
  bits<24> addr;

  let Opcode = op;

  let Inst{23-0} = addr;
}

