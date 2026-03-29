function repl_loop(
    jobs::Vector{Job},
    jobs_lock::ReentrantLock,
    notif_channel::Channel{Notification}
)
    println("\n  eMailToMe Manager läuft.")
    println("  Befehle: list | enable <name> | disable <name> | run <name> | quit\n")

    while true
        print("> ")
        line = strip(readline())
        isempty(line) && continue

        parts = split(line, r"\s+", limit = 2)
        cmd   = lowercase(String(parts[1]))
        arg   = length(parts) > 1 ? strip(String(parts[2]), [' ', '"', '\'']) : ""

        if     cmd == "list"                    ; cmd_list(jobs, jobs_lock)
        elseif cmd == "enable"                  ; cmd_enable(jobs, jobs_lock, arg)
        elseif cmd == "disable"                 ; cmd_disable(jobs, jobs_lock, arg)
        elseif cmd == "run"                     ; cmd_run(jobs, jobs_lock, notif_channel, arg)
        elseif cmd in ("quit", "exit", "q")     ; cmd_quit(notif_channel)
        else
            println("  Unbekannter Befehl: \"$cmd\"")
            println("  Verfügbar: list | enable <name> | disable <name> | run <name> | quit")
        end
    end
end

# ── Befehle ───────────────────────────────────────────────────────────────────

function cmd_list(jobs::Vector{Job}, jobs_lock::ReentrantLock)
    lock(jobs_lock) do
        println()
        @printf("  %-28s %-12s %-22s %s\n", "Name", "Status", "Nächste Ausführung", "Fehler")
        println("  " * "─"^72)
        for job in jobs
            next_str = job.status == :disabled ?
                "deaktiviert" :
                Dates.format(job.next_run, "yyyy-mm-dd HH:MM:SS")
            status_str = Dict(
                :active   => "aktiv",
                :running  => "läuft",
                :disabled => "deaktiviert"
            )[job.status]
            fails = job.max_failures == 0 ?
                "$(job.failure_count) (sofort)" :
                "$(job.failure_count)/$(job.max_failures)"
            @printf("  %-28s %-12s %-22s %s\n", job.name, status_str, next_str, fails)
        end
        println()
    end
end

function cmd_enable(jobs::Vector{Job}, jobs_lock::ReentrantLock, name::String)
    isempty(name) && (println("  Verwendung: enable <job-name>"); return)
    found = false
    lock(jobs_lock) do
        idx = findfirst(j -> j.name == name, jobs)
        if idx !== nothing
            j = jobs[idx]
            j.status        = :active
            j.failure_count = 0
            j.notified      = false
            j.next_run      = now()
            found = true
        end
    end
    found ? println("  Job \"$name\" reaktiviert.") :
            println("  Job nicht gefunden: \"$name\"")
end

function cmd_disable(jobs::Vector{Job}, jobs_lock::ReentrantLock, name::String)
    isempty(name) && (println("  Verwendung: disable <job-name>"); return)
    found = false
    lock(jobs_lock) do
        idx = findfirst(j -> j.name == name, jobs)
        if idx !== nothing
            jobs[idx].status = :disabled
            found = true
        end
    end
    found ? println("  Job \"$name\" deaktiviert.") :
            println("  Job nicht gefunden: \"$name\"")
end

function cmd_run(
    jobs::Vector{Job},
    jobs_lock::ReentrantLock,
    notif_channel::Channel{Notification},
    name::String
)
    isempty(name) && (println("  Verwendung: run <job-name>"); return)
    job_ref = nothing
    lock(jobs_lock) do
        idx = findfirst(j -> j.name == name, jobs)
        if idx === nothing
            println("  Job nicht gefunden: \"$name\"")
        elseif jobs[idx].status == :running
            println("  Job \"$name\" läuft bereits.")
        else
            job_ref             = jobs[idx]
            job_ref.status      = :running
            job_ref.next_run    = now() + job_ref.interval
        end
    end
    if job_ref !== nothing
        println("  Starte Job \"$name\" manuell …")
        dispatch_job(job_ref, jobs_lock, notif_channel)
    end
end

function cmd_quit(notif_channel::Channel{Notification})
    println("  Manager wird beendet.")
    close(notif_channel)
    exit(0)
end
