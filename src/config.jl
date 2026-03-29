function load_config(path::String)::AppConfig
    isfile(path) || error("config.toml nicht gefunden: $path")
    d = TOML.parsefile(path)

    s = d["smtp"]
    m = d["mail"]

    # Passwort kann aus Umgebungsvariable kommen: password = "ENV:SMTP_PASSWORD"
    password = s["password"]
    if startswith(password, "ENV:")
        var = password[5:end]
        password = get(ENV, var, "")
        isempty(password) && error("Umgebungsvariable '$var' nicht gesetzt.")
    end

    AppConfig(
        SMTPConfig(s["host"], s["port"], s["user"], password),
        MailConfig(m["from"], m["to"])
    )
end

function load_jobs(path::String)::Vector{Job}
    isfile(path) || error("jobs.toml nicht gefunden: $path")
    d = TOML.parsefile(path)

    jobs = Job[]
    for j in get(d, "jobs", [])
        push!(jobs, Job(
            j["name"],
            j["script"],
            parse_interval(j["interval"]),
            get(j, "max_failures", 0),
            0,          # failure_count
            :active,    # status
            now(),      # next_run: erster Lauf sofort
            false       # notified
        ))
    end

    isempty(jobs) && @warn "Keine Jobs in $path definiert."
    jobs
end

function parse_interval(s::String)::Second
    m = match(r"^(\d+)([smhd])$", strip(s))
    m === nothing && error(
        "Ungültiges Intervall-Format: '$s'. Erwartet z.B. '30s', '5m', '2h', '1d'."
    )
    n = parse(Int, m.captures[1])
    unit = m.captures[2]
    Second(n * Dict("s" => 1, "m" => 60, "h" => 3_600, "d" => 86_400)[unit])
end
