#!/usr/bin/env bash
set -e

# Run migrations once, synchronously, before anything starts. Loading the app
# triggers Sequel::Migrator via config/initializers/db.rb; doing it here (rather
# than letting the server and scheduler each migrate on boot) avoids two
# processes racing to migrate the same SQLite file.
bundle exec ruby -e 'require "./config/application"'

# Rage API (behind nginx) + standalone scheduler + nginx serving the static SPA.
bundle exec rage s -b 127.0.0.1 -p 3000 &
bundle exec ruby bin/scheduler &
nginx -g 'daemon off;' &

# If either process exits, stop the container so Docker's restart policy kicks in.
wait -n
exit 1
