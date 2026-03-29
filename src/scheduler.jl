# Hauptschleife des Schedulers – läuft in eigenem Thread.
function scheduler_loop(
    jobs::Vector{Job},
    jobs_lock::ReentrantLock,
    notif_channel::Channel{Notification}
)
    while true
        t = now()
        lock(jobs_lock) do
            for job in jobs
                if job.status == :active && t >= job.next_run
                    job.status   = :running
                    job.next_run = t + job.interval
                    dispatch_job(job, jobs_lock, notif_channel)
                end
            end
        end
        sleep(1)
    end
end

# Startet einen Job-Lauf als eigenen Task (gleicher Prozess, eigener Thread).
function dispatch_job(
    job::Job,
    jobs_lock::ReentrantLock,
    notif_channel::Channel{Notification}
)
    Threads.@spawn begin
        try
            run_script(job, notif_channel)
            lock(jobs_lock) do
                job.failure_count = 0
                job.notified      = false
                job.status        = :active
            end
            @info "[$(job.name)] Erfolgreich abgeschlossen."
        catch e
            on_job_failure(job, jobs_lock, notif_channel, e)
        end
    end
end

function on_job_failure(
    job::Job,
    jobs_lock::ReentrantLock,
    notif_channel::Channel{Notification},
    e
)
    lock(jobs_lock) do
        job.failure_count += 1
        should_report = job.max_failures == 0 || job.failure_count >= job.max_failures

        if should_report && !job.notified
            tb  = sprint(showerror, e, catch_backtrace())
            msg = """Job fehlgeschlagen nach $(job.failure_count) Versuch(en).

Fehler:
$tb

Der Job wurde deaktiviert.
Zum Reaktivieren im Manager: enable "$(job.name)"
"""
            put!(notif_channel, Notification(
                job.name, msg,
                "Fehler: $(job.name)",
                :error,
                now()
            ))
            job.notified = true
            job.status   = :disabled
            @warn "[$(job.name)] Deaktiviert nach $(job.failure_count) Fehlern."
        else
            # Noch innerhalb der Toleranz → still weitermachen
            job.status = :active
            remaining  = job.max_failures - job.failure_count
            @warn "[$(job.name)] Fehler $(job.failure_count)/$(job.max_failures) – noch $remaining Versuch(e) bis Meldung."
        end
    end
end
