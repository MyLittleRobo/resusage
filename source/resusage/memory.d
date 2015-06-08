/**
 * The amount of virtual and physycal memory used by system or process.
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov).
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */

module resusage.memory;

import std.exception;

private {
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

/**
 * Total virtual memory in the system, in bytes.
 */
@trusted ulong totalVirtualMemory();

/**
 * Amout of virtual memory currently used, in bytes.
 */
@trusted ulong virtualMemoryUsed();


/**
 * Amount of virtual memory currently used by single process, in bytes.
 * Params:
 *  pid = Process id
 */
@trusted ulong virtualMemoryUsedByProcess(int pid);

/**
 * ditto, but returns info for this process.
 */
@trusted ulong virtualMemoryUsedByProcess();

/**
 * Total physycal memory (RAM) in the system, in bytes.
 */
@trusted ulong totalPhysicalMemory();

/**
 * Amout of physycal memory (RAM) currently used, in bytes.
 */
@trusted ulong physicalMemoryUsed();

/**
 * Amount of physycal memory (RAM) currently used by single process, in bytes.
 * Params:
 *  pid = Process id
 */
@trusted ulong physicalMemoryUsedByProcess(int pid);

/**
 * ditto, but returns info for this process.
 */
@trusted ulong physicalMemoryUsedByProcess();

version(linux)
{
    private {
        import core.sys.posix.sys.types;
        import core.sys.posix.unistd;
        
        static if (is(typeof({ import core.sys.linux.sys.sysinfo; }))) {
            import core.sys.linux.sys.sysinfo;
        } else {
            pragma(msg, "core.sys.linux.sys.sysinfo not found, fallback will be used.");
            extern(C) @nogc nothrow:
            struct sysinfo_
            {
                c_long uptime;     /* Seconds since boot */
                c_ulong[3] loads;  /* 1, 5, and 15 minute load averages */
                c_ulong totalram;  /* Total usable main memory size */
                c_ulong freeram;   /* Available memory size */
                c_ulong sharedram; /* Amount of shared memory */
                c_ulong bufferram; /* Memory used by buffers */
                c_ulong totalswap; /* Total swap space size */
                c_ulong freeswap;  /* swap space still available */
                ushort procs;      /* Number of current processes */
                ushort pad;        /* Explicit padding for m68k */
                c_ulong totalhigh; /* Total high memory size */
                c_ulong freehigh;  /* Available high memory size */
                uint mem_unit;     /* Memory unit size in bytes */
                ubyte[20-2 * c_ulong.sizeof - uint.sizeof] _f; /* Padding: libc5 uses this.. */
            }
            int sysinfo(sysinfo_ *info);
        }
        
        import core.sys.linux.config;
        
        import std.c.stdio : FILE, fopen, fclose, fscanf;
        import std.conv : to;
        import std.string : toStringz;
    }
    
    private @trusted void memoryUsedHelper(const(char)* proc, ref c_ulong vsize, ref c_long rss)
    {
        FILE* f = errnoEnforce(fopen(proc, "r"));
        pid_t pid;
        errnoEnforce(fscanf(f, 
                     "%d " //pid
                     "%*s " //comm
                     "%*c " //state
                     "%*d " //ppid
                     "%*d " //pgrp
                     "%*d " //session
                     "%*d " //tty_nr
                     "%*d " //tpgid
                     "%*u " //flags
                     "%*lu " //minflt
                     "%*lu " //cminflt
                     "%*lu " //majflt
                     "%*lu " //cmajflt
                     "%*lu " //utime
                     "%*lu " //stime
                     "%*ld " //cutime
                     "%*ld " //cstime
                     "%*ld " //priority
                     "%*ld " //nice
                     "%*ld " //num_threads
                     "%*ld " //itrealvalue
                     "%*llu " //starttime
                     "%lu " //vsize
                     "%ld ", //rss
               &pid, &vsize, &rss
              ));
        rss *= sysconf(_SC_PAGESIZE);
        fclose(f);
    }
    
    
    @trusted ulong totalVirtualMemory()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong totalMem = memInfo.totalram;
        totalMem += memInfo.totalswap;
        totalMem *= memInfo.mem_unit;
        return totalMem;
    }
    
    @trusted ulong virtualMemoryUsed()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong memUsed = memInfo.totalram - memInfo.freeram;
        memUsed += memInfo.totalswap - memInfo.freeswap;
        memUsed *= memInfo.mem_unit;
        return memUsed;
    }
    
    @trusted ulong virtualMemoryUsedByProcess()
    {
        c_ulong vsize;
        c_long rss;
        memoryUsedHelper("/proc/self/stat", vsize, rss);
        return vsize;
    }
    
    @trusted ulong virtualMemoryUsedByProcess(int pid)
    {
        c_ulong vsize;
        c_long rss;
        
        memoryUsedHelper(toStringz("/proc/" ~ to!string(pid) ~ "/stat"), vsize, rss);
        return vsize;
    }
    
    @trusted ulong totalPhysicalMemory()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong totalMem = memInfo.totalram;
        totalMem *= memInfo.mem_unit;
        return totalMem;
    }
    
    @trusted ulong physicalMemoryUsed()
    {
        sysinfo_ memInfo;
        errnoEnforce(sysinfo(&memInfo) == 0);
        
        ulong memUsed = memInfo.totalram - memInfo.freeram;
        memUsed *= memInfo.mem_unit;
        return memUsed;
    }
    
    @trusted ulong physicalMemoryUsedByProcess()
    {
        c_ulong vsize;
        c_long rss;
        memoryUsedHelper("/proc/self/stat", vsize, rss);
        return rss;
    }
    
    @trusted ulong physicalMemoryUsedByProcess(int pid)
    {
        c_ulong vsize;
        c_long rss;
        
        memoryUsedHelper(toStringz("/proc/" ~ to!string(pid) ~ "/stat"), vsize, rss);
        return rss;
    }
}