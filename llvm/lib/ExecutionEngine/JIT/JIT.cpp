//===-- JIT.cpp - LLVM Just in Time Compiler ------------------------------===//
//
// This file implements the top-level support for creating a Just-In-Time
// compiler for the current architecture.
//
//===----------------------------------------------------------------------===//

#include "VM.h"
#include "../GenericValue.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Target/TargetMachineImpls.h"
#include "llvm/Module.h"
#include "Support/CommandLine.h"

// FIXME: REMOVE THIS
#include "llvm/PassManager.h"

#if !defined(ENABLE_X86_JIT) && !defined(ENABLE_SPARC_JIT)
#define NO_JITS_ENABLED
#endif

namespace {
  enum ArchName { x86, Sparc };

#ifndef NO_JITS_ENABLED
  cl::opt<ArchName>
  Arch("march", cl::desc("Architecture to JIT to:"), cl::Prefix,
       cl::values(
#ifdef ENABLE_X86_JIT
                  clEnumVal(x86, "  IA-32 (Pentium and above)"),
#endif
#ifdef ENABLE_SPARC_JIT
                  clEnumValN(Sparc, "sparc", "  Sparc-V9"),
#endif
                  0),
#if defined(ENABLE_X86_JIT)
  cl::init(x86)
#elif defined(ENABLE_SPARC_JIT)
  cl::init(Sparc)
#endif
       );
#endif /* NO_JITS_ENABLED */
}

/// create - Create an return a new JIT compiler if there is one available
/// for the current target.  Otherwise, return null.
///
ExecutionEngine *VM::create(Module *M) {
  TargetMachine* (*TargetMachineAllocator)(const Module &) = 0;

  // Allow a command-line switch to override what *should* be the default target
  // machine for this platform. This allows for debugging a Sparc JIT on X86 --
  // our X86 machines are much faster at recompiling LLVM and linking LLI.
#ifdef NO_JITS_ENABLED
  return 0;
#endif

  switch (Arch) {
#ifdef ENABLE_X86_JIT
  case x86:
    TargetMachineAllocator = allocateX86TargetMachine;
    break;
#endif
#ifdef ENABLE_SPARC_JIT
  case Sparc:
    TargetMachineAllocator = allocateSparcTargetMachine;
    break;
#endif
  default:
    assert(0 && "-march flag not supported on this host!");
  }

  // Allocate a target...
  TargetMachine *Target = TargetMachineAllocator(*M);
  assert(Target && "Could not allocate target machine!");
  
  // Create the virtual machine object...
  return new VM(M, Target);
}

VM::VM(Module *M, TargetMachine *tm) : ExecutionEngine(M), TM(*tm) {
  setTargetData(TM.getTargetData());

  // Initialize MCE
  MCE = createEmitter(*this);

  setupPassManager();

#ifdef ENABLE_SPARC_JIT
  // THIS GOES BEYOND UGLY HACKS
  if (TM.getName() == "UltraSparc-Native") {
    extern Pass *createPreSelectionPass(TargetMachine &TM);
    PassManager PM;
    // Specialize LLVM code for this target machine and then
    // run basic dataflow optimizations on LLVM code.
    PM.add(createPreSelectionPass(TM));
    PM.run(*M);
  }
#endif

  emitGlobals();
}

/// run - Start execution with the specified function and arguments.
///
GenericValue VM::run(Function *F, const std::vector<GenericValue> &ArgValues)
{
  assert (F && "Function *F was null at entry to run()");

  int (*PF)(int, char **, const char **) =
    (int(*)(int, char **, const char **))getPointerToFunction(F);
  assert(PF != 0 && "Pointer to fn's code was null after getPointerToFunction");

  // Call the function.
  int ExitCode = PF(ArgValues[0].IntVal, (char **) GVTOP (ArgValues[1]),
		    (const char **) GVTOP (ArgValues[2]));

  // Run any atexit handlers now!
  runAtExitHandlers();

  GenericValue rv;
  rv.IntVal = ExitCode;
  return rv;
}
