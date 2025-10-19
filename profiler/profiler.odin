package profiler

import "core:fmt"
import "core:time"

// Anchor represents a single profiled block of code
Anchor :: struct {
    name:            string,
    hit_count:       u64,
    elapsed_ticks:   time.Duration,
    children_ticks:  time.Duration,
    start_tick:      time.Tick,
}

// Profiler holds all profiling data
Profiler :: struct {
    anchors:         map[string]Anchor,
    call_stack:      [dynamic]string, // Stack to track nested calls
    start_tick:      time.Tick,
    initialized:     bool,
}

// Global profiler instance
@(private)
g_profiler: Profiler

// Initialize the profiler
init :: proc() {
    if g_profiler.initialized {
        return
    }
    
    g_profiler.anchors = make(map[string]Anchor)
    g_profiler.call_stack = make([dynamic]string, 0, 64)
    g_profiler.start_tick = time.tick_now()
    g_profiler.initialized = true
}

// Destroy the profiler and free resources
destroy :: proc() {
    if !g_profiler.initialized {
        return
    }
    
    delete(g_profiler.anchors)
    delete(g_profiler.call_stack)
    g_profiler.initialized = false
}

// Begin a profiling block manually
begin_block :: proc(name: string) {
    if !g_profiler.initialized {
        init()
    }
    
    start_tick := time.tick_now()
    
    // Add to call stack
    append(&g_profiler.call_stack, name)
    
    // Get or create anchor
    anchor, exists := &g_profiler.anchors[name]
    if exists {
        anchor.hit_count += 1
        anchor.start_tick = start_tick
    } else {
        g_profiler.anchors[name] = Anchor{
            name = name,
            hit_count = 1,
            elapsed_ticks = 0,
            children_ticks = 0,
            start_tick = start_tick,
        }
    }
}

// End a profiling block manually
end_block :: proc(name: string) {
    if !g_profiler.initialized {
        return
    }
    
    end_tick := time.tick_now()
    
    // Pop from call stack
    if len(g_profiler.call_stack) == 0 {
        fmt.eprintln("Warning: end_block called without matching begin_block")
        return
    }
    
    stack_top := pop(&g_profiler.call_stack)
    if stack_top != name {
        fmt.eprintln("Warning: block mismatch -", "expected:", stack_top, "got:", name)
    }
    
    // Update anchor
    anchor := &g_profiler.anchors[name]
    elapsed := time.tick_diff(anchor.start_tick, end_tick)
    anchor.elapsed_ticks += elapsed
    
    // Update parent's children ticks
    if len(g_profiler.call_stack) > 0 {
        parent_name := g_profiler.call_stack[len(g_profiler.call_stack) - 1]
        parent := &g_profiler.anchors[parent_name]
        parent.children_ticks += elapsed
    }
}

// Report profiling results
report :: proc() {
    if !g_profiler.initialized {
        fmt.println("Profiler not initialized")
        return
    }
    
    total_duration := time.tick_since(g_profiler.start_tick)
    total_seconds := time.duration_seconds(total_duration)
    total_ms := time.duration_milliseconds(total_duration)
    
    fmt.println("=== Profiler Report ===")
    fmt.printf("Total Time: %.6f s (%.2f ms)\n", total_seconds, total_ms)
    fmt.println("\n%-30s %10s %15s %15s %12s %12s", 
        "Function", "Calls", "Total (ms)", "Excl. (ms)", "Total %", "Excl. %")
    fmt.println("---------------------------------------------------------------------------------------------------")
    
    // Print all anchors
    for name, anchor in g_profiler.anchors {
        exclusive_ticks := anchor.elapsed_ticks - anchor.children_ticks
        exclusive_ms := time.duration_milliseconds(exclusive_ticks)
        total_anchor_ms := time.duration_milliseconds(anchor.elapsed_ticks)
        
        total_percent := (time.duration_seconds(anchor.elapsed_ticks) / total_seconds) * 100
        exclusive_percent := (time.duration_seconds(exclusive_ticks) / total_seconds) * 100
        
        fmt.printf("%-30s %10d %15.3f %15.3f %11.2f%% %11.2f%%",
            name,
            anchor.hit_count,
            total_anchor_ms,
            exclusive_ms,
            total_percent,
            exclusive_percent)
        
        if anchor.children_ticks > 0 {
            children_ms := time.duration_milliseconds(anchor.children_ticks)
            fmt.printf(" (%.3f ms + %.3f ms nested)\n", exclusive_ms, children_ms)
        } else {
            fmt.printf("\n")
        }
    }
    
    fmt.println("---------------------------------------------------------------------------------------------------")
}

// Reset profiling data (keeps profiler initialized)
reset :: proc() {
    if !g_profiler.initialized {
        return
    }
    
    clear(&g_profiler.anchors)
    clear(&g_profiler.call_stack)
    g_profiler.start_tick = time.tick_now()
}
