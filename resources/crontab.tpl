{{ .Env.Get "INTERVAL_MINUTES" }} * * * *     /send-mail-after-changed-password.sh >> /tmp/logs/scheduled_jobs.log
