# Läuft dauerhaft in eigenem Thread.
# Liest Notifications vom Channel und versendet sie sofort per E-Mail.
function notifier_loop(notif_channel::Channel{Notification}, cfg::AppConfig)
    for notif in notif_channel          # blockiert bis etwas im Channel liegt
        try
            send_email(cfg, notif)
        catch e
            @error "[Notifier] E-Mail-Versand fehlgeschlagen: $(sprint(showerror, e))"
        end
    end
end
