# Führt ein Script in einem eigenen anonymen Modul aus.
# Das Script erhält `notify()` als einzige Schnittstelle zum Manager.
#
# Verwendung im Script:
#   notify("Nachricht")
#   notify("Nachricht", subject="Mein Betreff", level=:warn)
#
function run_script(job::Job, notif_channel::Channel{Notification})
    # Closure, die das Script aufrufen kann
    notify_fn = function (msg::String;
                          subject::String = job.name,
                          level::Symbol   = :info)
        put!(notif_channel, Notification(job.name, msg, subject, level, now()))
    end

    # Jeder Lauf bekommt ein frisches Modul → kein globaler Namespace-Konflikt
    mod_name = Symbol("Job_" * replace(job.name, r"[^\w]" => "_"))
    m = Module(mod_name)

    # notify in das Modul injizieren
    Core.eval(m, :(const notify = $notify_fn))

    # Script ausführen – Exceptions propagieren zum Aufrufer (Scheduler)
    Base.include(m, abspath(job.script))
end
