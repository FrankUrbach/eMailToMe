function send_email(cfg::AppConfig, notif::Notification)
    level_str = get(Dict(:info => "INFO", :warn => "WARNUNG", :error => "FEHLER"), notif.level, "INFO")
    ts = Dates.format(notif.timestamp, "yyyy-mm-dd HH:MM:SS")

    # RFC 2822-konformer E-Mail-Body
    body = join([
        "From: $(cfg.mail.from)",
        "To: $(cfg.mail.to)",
        "Subject: [eMailToMe] $(notif.subject)",
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=UTF-8",
        "",
        "Job:   $(notif.job_name)",
        "Zeit:  $ts",
        "Level: $level_str",
        "",
        notif.body,
    ], "\r\n")

    opts = SMTPClient.SendOptions(
        isSSL    = false,          # STARTTLS auf Port 587
        username = cfg.smtp.user,
        passwd   = cfg.smtp.password
    )

    SMTPClient.send(
        "smtp://$(cfg.smtp.host):$(cfg.smtp.port)",
        [cfg.mail.to],
        cfg.mail.from,
        IOBuffer(body),
        opts
    )

    @info "[Mailer] Gesendet: $(notif.subject)"
end
