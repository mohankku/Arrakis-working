--------------------------------------------------------------------------
-- Copyright (c) 2007-2010, ETH Zurich.
-- All rights reserved.
--
-- This file is distributed under the terms in the attached LICENSE file.
-- If you do not find this file, copies can be found by writing to:
-- ETH Zurich D-INFK, Haldeneggsteig 4, CH-8092 Zurich. Attn: Systems Group.
--
-- Architectural definitions for Barrelfish on ARMv5 ISA.
--
-- The build target is the integratorcp board on QEMU with the default
-- ARM926EJ-S cpu.
--
--------------------------------------------------------------------------

module ARMv8 where

import HakeTypes
import Path
import qualified Config
import qualified ArchDefaults

-------------------------------------------------------------------------
--
-- Architecture specific definitions for ARM
--
-------------------------------------------------------------------------

arch = "armv8"
archFamily = "aarch64"

toolprefix = "aarch64-none-elf-"

compiler = toolprefix ++ "gcc"
objcopy  = toolprefix ++ "objcopy"
objdump  = toolprefix ++ "objdump"
ar       = toolprefix ++ "ar"
ranlib   = toolprefix ++ "ranlib"
cxxcompiler = toolprefix ++ "g++"

ourCommonFlags = [ Str "-fno-unwind-tables",
                   Str "-Wno-packed-bitfield-compat",
                   Str "-fno-stack-protector",
                   Str "-mcpu=cortex-a57",
                   Str "-march=armv8-a",
                   Str "-mabi=lp64",
                   Str "-DPIC_REGISTER=X10",
                   Str "-fPIE",
                   Str "-ffixed-r9",
                   Str "-DTHREAD_REGISTER=X9",
                   Str "-D__ARM_CORTEX__",
                   Str "-D__ARM_ARCH_8A__",
                   Str "-Wno-unused-but-set-variable",
                   Str "-Wno-format"
 ]

cFlags = ArchDefaults.commonCFlags 
         ++ ArchDefaults.commonFlags
         ++ ourCommonFlags

cxxFlags = ArchDefaults.commonCxxFlags
           ++ ArchDefaults.commonFlags
           ++ ourCommonFlags

cDefines = ArchDefaults.cDefines options

ourLdFlags = [ Str "-Wl,-section-start,.text=0x400000",
               Str "-Wl,-section-start,.data=0x600000",
               Str "-Wl,--build-id=none" ]

ldFlags = ArchDefaults.ldFlags arch ++ ourLdFlags
ldCxxFlags = ArchDefaults.ldCxxFlags arch ++ ourLdFlags

stdLibs = ArchDefaults.stdLibs arch ++ [ Str "-lgcc" ]

options = (ArchDefaults.options arch archFamily) { 
            optFlags = cFlags,
            optCxxFlags = cxxFlags,
            optDefines = cDefines,
            optDependencies = 
                [ PreDep InstallTree arch "/include/trace_definitions/trace_defs.h",
                  PreDep InstallTree arch "/include/errors/errno.h",
                  PreDep InstallTree arch "/include/barrelfish_kpi/capbits.h",
                  PreDep InstallTree arch "/include/asmoffsets.h"
                   ],
            optLdFlags = ldFlags,
            optLdCxxFlags = ldCxxFlags,
            optLibs = stdLibs,
            optInterconnectDrivers = ["lmp", "ump"],
            optFlounderBackends = ["lmp", "ump"]
          }

--
-- Compilers
--
cCompiler = ArchDefaults.cCompiler arch compiler
cxxCompiler = ArchDefaults.cxxCompiler arch cxxcompiler
makeDepend = ArchDefaults.makeDepend arch compiler
makeCxxDepend  = ArchDefaults.makeCxxDepend arch cxxcompiler
cToAssembler = ArchDefaults.cToAssembler arch compiler
assembler = ArchDefaults.assembler arch compiler
archive = ArchDefaults.archive arch
linker = ArchDefaults.linker arch compiler
cxxlinker = ArchDefaults.cxxlinker arch cxxcompiler


--
-- The kernel is "different"
--

kernelCFlags = [ Str s | s <- [ "-fno-builtin",
                                "-fno-unwind-tables",
                                "-nostdinc",
                                "-std=c99",
                                "-mcpu=cortex-a57",
                                "-march=armv8-a",
                                "-mabi=lp64",
                                "-fPIE",
                                "-U__linux__",
                                "-Wall",
                                "-Wshadow",
                                "-Wstrict-prototypes",
                                "-Wold-style-definition",
                                "-Wmissing-prototypes",
                                "-Wmissing-declarations",
                                "-Wmissing-field-initializers",
                                "-Wredundant-decls",
                                "-Werror",
                                "-imacros deputy/nodeputy.h",
                                "-fno-stack-check",
                                "-ffreestanding",
                                "-fomit-frame-pointer",
                                "-Wmissing-noreturn",
                                "-ffixed-r9",
                                "-DTHREAD_REGISTER=X9",
                                "-D__ARM_CORTEX__",
                                "-D__ARM_ARCH_8A__",
                                "-Wno-unused-but-set-variable",
                                "-Wno-format"
                              ]]

kernelLdFlags = [ Str "-Wl,-N",
                  Str "-fno-builtin",
                  Str "-nostdlib",
                  Str "-pie",
                  Str "-Wl,--fatal-warnings"
                ]


--
-- Link the kernel (CPU Driver)
--
linkKernel :: Options -> [String] -> [String] -> String -> HRule
linkKernel opts objs libs name =
    let linkscript = "/kernel/" ++ name ++ ".lds"
        kernelmap  = "/kernel/" ++ name ++ ".map"
        kasmdump   = "/kernel/" ++ name ++ ".asm"
        kbinary    = "/sbin/" ++ name
        kbootable  = kbinary ++ ".bin"
    in
        Rules [ Rule ([ Str compiler, Str Config.cOptFlags,
                      NStr "-T", In BuildTree arch linkscript,
                      Str "-o", Out arch kbinary,
                      NStr "-Wl,-Map,", Out arch kernelmap
                    ]
                    ++ (optLdFlags opts)
                    ++
                    [ In BuildTree arch o | o <- objs ]
                    ++
                    [ In BuildTree arch l | l <- libs ]
                    ++
                    [ Str "-lgcc" ]
                   ),
              -- Generate kernel assembly dump
              Rule [ Str objdump, 
                     Str "-d", 
                     Str "-M reg-names-raw",
                     In BuildTree arch kbinary, 
                     Str ">", Out arch kasmdump ],
              Rule [ Str "cpp",
                     NStr "-I", NoDep SrcTree "src" "/kernel/include/arch/armv8",
                     Str "-D__ASSEMBLER__",
                     Str "-P", In SrcTree "src" "/kernel/arch/armv8/linker.lds.in",
                     Out arch linkscript
                   ]
            ]
