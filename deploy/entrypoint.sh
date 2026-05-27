#!/usr/bin/env bash
set -e

# Rage API (behind nginx) + standalone scheduler + nginx serving the static SPA.
bundle exec rage s -b 127.0.0.1 -p 3000 &
bundle exec ruby bin/scheduler &
nginx -g 'daemon off;' &

# If either process exits, stop the container so Docker's restart policy kicks in.
wait -n
exit 1
