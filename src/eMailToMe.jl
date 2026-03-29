module eMailToMe

using TOML
using Dates
using Printf
using SMTPClient

include("types.jl")
include("config.jl")
include("mailer.jl")
include("notifier.jl")
include("runner.jl")
include("scheduler.jl")
include("repl.jl")

function main(args::Vector{String} = ARGS)
    config_path = length(args) >= 1 ? args[1] : "config.toml"
    jobs_path   = length(args) >= 2 ? args[2] : "jobs.toml"

    @info "eMailToMe startet …"
    @info "  Konfiguration : $config_path"
    @info "  Jobs          : $jobs_path"

    cfg  = load_config(config_path)
    jobs = load_jobs(jobs_path)

    @info "  $(length(jobs)) Job(s) geladen."
    @info "  Threads verfügbar: $(Threads.nthreads())"
    Threads.nthreads() < 2 && @warn "Nur 1 Thread verfügbar. Starte Julia mit: julia --threads auto"

    jobs_lock    = ReentrantLock()
    notif_channel = Channel{Notification}(100)

    # Scheduler und Notifier laufen in eigenen Threads
    Threads.@spawn scheduler_loop(jobs, jobs_lock, notif_channel)
    Threads.@spawn notifier_loop(notif_channel, cfg)

    # REPL blockiert den Haupt-Thread
    repl_loop(jobs, jobs_lock, notif_channel)
end

end # module eMailToMe

# Einstiegspunkt wenn direkt als Script aufgerufen
if abspath(PROGRAM_FILE) == @__FILE__
    eMailToMe.main()
end
