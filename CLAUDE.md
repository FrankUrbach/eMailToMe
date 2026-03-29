# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

```bash
# Abhängigkeiten installieren (einmalig)
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Manager starten

```bash
julia --threads auto --project src/eMailToMe.jl
# Mit alternativen Config-Pfaden:
julia --threads auto --project src/eMailToMe.jl meine_config.toml meine_jobs.toml
```

`--threads auto` ist Pflicht – Scheduler und Notifier laufen in eigenen Threads.

## Interaktive Befehle (laufender Manager)

| Befehl | Wirkung |
|---|---|
| `list` | Alle Jobs mit Status, nächster Ausführung, Fehlerstand |
| `enable <name>` | Deaktivierten Job reaktivieren (setzt failure_count zurück) |
| `disable <name>` | Job manuell deaktivieren |
| `run <name>` | Job sofort manuell auslösen |
| `quit` | Manager beenden |

## Architektur

Alle Komponenten leben im Modul `eMailToMe` (`src/eMailToMe.jl`). Die anderen Dateien werden per `include()` eingebunden – keine eigenen Module.

```
src/
├── eMailToMe.jl   main(), Modul-Einstiegspunkt, startet Threads
├── types.jl       AppConfig, Job (mutable), Notification structs
├── config.jl      load_config(), load_jobs(), parse_interval()
├── mailer.jl      send_email() via SMTPClient.jl → Office365 SMTP (Port 587, STARTTLS)
├── notifier.jl    notifier_loop(): Channel{Notification} → send_email()
├── runner.jl      run_script(): Script in isoliertem Module ausführen, notify() injizieren
├── scheduler.jl   scheduler_loop(), dispatch_job(), on_job_failure()
└── repl.jl        repl_loop(), cmd_list/enable/disable/run/quit
```

**Thread-Modell:** Scheduler und Notifier laufen via `Threads.@spawn`. Die REPL blockiert den Haupt-Thread (stdin). Jobs werden ebenfalls per `Threads.@spawn` gestartet. Gemeinsamer Zustand (`Vector{Job}`) ist mit einem `ReentrantLock` geschützt.

**Script-Isolation:** Jeder Job-Lauf bekommt ein frisches anonymes `Module`. `notify()` wird per `Core.eval` injiziert, bevor `Base.include(m, script_path)` aufgerufen wird. Scripts brauchen keinen Import – `notify()` steht direkt zur Verfügung.

## Job-Zustandsautomat

```
:active → run → Erfolg  → failure_count=0, :active
               → Absturz → failure_count++
                            < max_failures  → :active (still)
                            >= max_failures → Mail senden → :disabled
:disabled ──── enable <name> im REPL ────→ :active (failure_count=0)
```

`max_failures = 0` bedeutet: sofort bei erstem Absturz melden und deaktivieren.
Nach einer Fehlerserie kommt genau eine Mail. Anschließend muss der Job manuell reaktiviert werden.

## Konfiguration

**`config.toml`** – SMTP und Empfänger-Adresse.
Das Passwort kann als Klartext oder als Umgebungsvariable angegeben werden:
```toml
password = "ENV:SMTP_PASSWORD"   # liest os.environ["SMTP_PASSWORD"]
```

**`jobs.toml`** – Job-Definitionen:
```toml
[[jobs]]
name         = "Mein Job"
script       = "scripts/mein_script.jl"
interval     = "1h"          # s, m, h, d
max_failures = 3
```

## Script-API

Scripts haben automatisch Zugriff auf:
```julia
notify(message::String; subject::String=job_name, level::Symbol=:info)
# level: :info | :warn | :error
```
