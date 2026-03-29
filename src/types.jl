# ── Konfiguration ────────────────────────────────────────────────────────────

struct SMTPConfig
    host::String
    port::Int
    user::String
    password::String
end

struct MailConfig
    from::String
    to::String
end

struct AppConfig
    smtp::SMTPConfig
    mail::MailConfig
end

# ── Job-Zustand ───────────────────────────────────────────────────────────────

# :active    → wartet auf nächste Ausführung
# :running   → wird gerade ausgeführt
# :disabled  → nach Fehlerserie deaktiviert

mutable struct Job
    name::String
    script::String
    interval::Second
    max_failures::Int
    # Laufzeit-Zustand
    failure_count::Int
    status::Symbol
    next_run::DateTime
    notified::Bool        # wurde für aktuelle Fehlerserie bereits eine Mail gesendet?
end

# ── Benachrichtigung ──────────────────────────────────────────────────────────

struct Notification
    job_name::String
    body::String
    subject::String
    level::Symbol         # :info, :warn, :error
    timestamp::DateTime
end
