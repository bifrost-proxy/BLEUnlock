#!/usr/bin/env bash

set -euo pipefail

PID="${1:-}"
DURATION_SECONDS="${2:-60}"
INTERVAL_SECONDS=2
CPU_LIMIT=10
RSS_LIMIT_MB=80

if [[ -z "${PID}" ]]; then
  PID="$(pgrep -x BLEUnlock | head -1 || true)"
fi

if [[ -z "${PID}" ]] || ! kill -0 "${PID}" 2>/dev/null; then
  echo "Usage: $0 [pid] [duration-seconds]" >&2
  echo "A running BLEUnlock process is required." >&2
  exit 2
fi

if ! [[ "${DURATION_SECONDS}" =~ ^[0-9]+$ ]] || [[ "${DURATION_SECONDS}" -lt 2 ]]; then
  echo "Duration must be an integer of at least 2 seconds." >&2
  exit 2
fi

samples_file="$(mktemp "${TMPDIR:-/tmp}/bleunlock-profile.XXXXXX")"
trap 'rm -f "${samples_file}"' EXIT

sample_count=$((DURATION_SECONDS / INTERVAL_SECONDS))
for ((i = 0; i < sample_count; i++)); do
  if ! ps -p "${PID}" -o %cpu=,rss= | awk 'NF == 2 { print $1, $2 }' >> "${samples_file}"; then
    echo "BLEUnlock exited during profiling." >&2
    exit 1
  fi
  sleep "${INTERVAL_SECONDS}"
done

awk -v cpu_limit="${CPU_LIMIT}" -v rss_limit_mb="${RSS_LIMIT_MB}" '
  {
    cpu_sum += $1
    rss_sum += $2
    if ($1 > cpu_max) cpu_max = $1
    if ($2 > rss_max) rss_max = $2
    count++
  }
  END {
    if (count == 0) {
      print "No samples collected." > "/dev/stderr"
      exit 2
    }

    cpu_avg = cpu_sum / count
    rss_avg_mb = rss_sum / count / 1024
    rss_max_mb = rss_max / 1024
    printf "samples=%d avg_cpu=%.2f%% max_cpu=%.2f%% avg_rss=%.2fMB max_rss=%.2fMB\n", \
      count, cpu_avg, cpu_max, rss_avg_mb, rss_max_mb

    if (cpu_avg >= cpu_limit || rss_max_mb >= rss_limit_mb) {
      printf "FAIL: requires avg CPU < %.0f%% and max RSS < %.0fMB\n", cpu_limit, rss_limit_mb > "/dev/stderr"
      exit 1
    }
    printf "PASS: avg CPU < %.0f%% and max RSS < %.0fMB\n", cpu_limit, rss_limit_mb
  }
' "${samples_file}"
