# Beispiel-Script für eMailToMe
#
# `notify()` steht automatisch zur Verfügung – kein Import nötig.
#
#   notify(message::String)
#   notify(message::String; subject="Betreff", level=:info)
#
# level: :info (Standard) | :warn | :error

using Dates

notify("Script gestartet: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")

# --- Deine Arbeit hier ---
result = sum(1:100)
# -------------------------

notify("Ergebnis: $result", subject="Beispiel-Job abgeschlossen", level=:info)
