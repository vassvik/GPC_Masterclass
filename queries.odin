package masterclass

import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"
import gl "vendor:OpenGL";

Query_Type :: enum u8 {
    Simulation,
    Render,
}

Query :: struct {
    start_query: u32,
    end_query:   u32,

    name: string,
    timestep: int,
    memory: int,
    type: Query_Type,

    completed: bool,
}

Summed_Query_Sample :: struct {sum: int, count: int, memory: int}

query_pool: [dynamic]u32
active_queries: [dynamic]Query

finished_sim_queries:    map[string][dynamic]Summed_Query_Sample
finished_render_queries: map[string][dynamic]Summed_Query_Sample



init_query_pool :: proc() {
    query_pool = make([dynamic]u32, 1000)
    gl.CreateQueries(gl.TIMESTAMP, 1000, &query_pool[0])
}

@(deferred_out=query_end)
block_query :: proc(name: string, timestep, memory: int, type: Query_Type) -> (q: Query) {
    when STRIP_MOST_QUERIES do if type == .Simulation && name != "simulation" do return {name = name}

    q.start_query = pop(&query_pool)
    gl.QueryCounter(q.start_query, gl.TIMESTAMP)
    q.name = strings.clone(name)
    q.timestep = timestep
    q.memory = memory
    q.type = type
    return
}

query_end :: proc(q: Query) {
    when STRIP_MOST_QUERIES do if q.type == .Simulation && q.name != "simulation" do return
    q := q
    q.end_query = pop(&query_pool)
    gl.QueryCounter(q.end_query, gl.TIMESTAMP)
    append(&active_queries, q)
}

process_active_queries :: proc(timestep: int) {
    for &query, i in active_queries {
        if query.completed do continue
        
        finished_queries := &finished_sim_queries if query.type == .Simulation else &finished_render_queries

        ready1, ready2: u64;
        gl.GetQueryObjectui64v(query.start_query, gl.QUERY_RESULT_AVAILABLE, &ready1);
        gl.GetQueryObjectui64v(query.end_query, gl.QUERY_RESULT_AVAILABLE, &ready2);

        if ready1 == 1 && ready2 == 1 {
            gl.GetQueryObjectui64v(query.start_query, gl.QUERY_RESULT_NO_WAIT, &ready1);
            gl.GetQueryObjectui64v(query.end_query, gl.QUERY_RESULT_NO_WAIT, &ready2);

            //if query.name == "jacobi vertex 1" do fmt.println(ready1, ready2)
            if q, ok := &finished_queries[query.name]; ok {
                for len(q) <= int(query.timestep) {
                    append(q, Summed_Query_Sample{})
                }
                s := Summed_Query_Sample{q[query.timestep].sum + int(ready2-ready1), q[query.timestep].count+1, query.memory}
                q[query.timestep] = s
                //if query.name == "jacobi vertex 1" do fmt.println("b", s, q[query.timestep], query)
            } else {
                finished_queries[query.name] = make([dynamic]Summed_Query_Sample)
                s := Summed_Query_Sample{int(ready2-ready1), 1, query.memory}
                append(&finished_queries[query.name], s)
                //if query.name == "jacobi vertex 1" do fmt.println("a", s, query)
            }

            append(&query_pool, query.start_query)
            append(&query_pool, query.end_query)
            query.completed = true
        }
    }

    num_to_delete := 0
    for query, i in &active_queries {
        if !query.completed do break
        num_to_delete += 1
    }
    if num_to_delete > 0 do remove_range(&active_queries, 0, num_to_delete)
}

process_finished_query :: proc(name: string, num: int) -> (f64, f64) {
    if qs, ok := finished_sim_queries[name]; ok {
        N := len(qs)
        start := max(0, N - num)

        time := 0.0
        memory := 0.0
        count := 0
        for i in start..<N {
            if qs[i].count == 0 do continue
            time += f64(qs[i].sum) / f64(qs[i].count)
            memory += f64(qs[i].memory)
            count += 1
        }
        time /= f64(count)
        memory /= f64(count)

        return time*1.0e-6, memory / time

    } else if qs, ok := finished_render_queries[name]; ok {
        N := len(qs)
        start := max(0, N - num)

        time := 0.0
        memory := 0.0
        count := 0
        for i in start..<N {
            if qs[i].count == 0 do continue
            time += f64(qs[i].sum) / f64(qs[i].count)
            memory += f64(qs[i].memory)
            count += 1
        }
        time /= f64(count)
        memory /= f64(count)

        return time*1.0e-6, memory / time

    } else {
        return 0.0, 0.0
    }
}

print_finished_queries :: proc() {
    for name, query in finished_sim_queries {
        when STRIP_MOST_QUERIES {
            if name != "simulation" do continue
        }
        sb := strings.builder_make()
        for s, timestep in query {
            time := f64(s.sum) / f64(s.count)
            //fmt.printf("%d %.6f %.6f %v\n", timestep,  time * 1.0e-6, bandwidth, s)
            fmt.sbprintf(&sb, "%d %.6f %d\n", timestep,  time*1.0e-9, s.memory)
        }
        os.write_entire_file(fmt.tprintf("plot/series_%s.txt", name), sb.buf[:])
    }

    p, ok := os2.process_start({
        working_dir = "plot",
        command = {"python", "plot_series.py"}
    }) // let it leak
} 

