# Hukamnama data

This branch holds a copy of SGPC's Hukamnama text for the Live Darbar web app.
Do not edit it by hand.
A GitHub Actions job writes it.
The job is `.github/workflows/hukamnama-mirror.yml` on the `main` branch.
The text belongs to SGPC (sgpc.net).

## Why this branch exists

SGPC's feed sends no CORS header, so a browser cannot read it.
raw.githubusercontent.com sends `access-control-allow-origin: *`, so the web app reads the copy from here.
The native apps read SGPC directly and do not use this branch.

## Files

- `hukamnama/YYYY-MM-DD.json`: SGPC's answer for that day, byte for byte.
  The app reads it with the same parser that it uses for SGPC.
- `hukamnama/latest.json`: a copy of the newest day.
- The last 31 days stay. The job deletes older files.

The day is the SGPC day, which is the date in India (UTC+5:30).
A file exists only after the job checks the answer.
A bad answer never replaces a good file.

Example:
`https://raw.githubusercontent.com/0xharkirat/live_darbar/hukamnama-data/hukamnama/2026-11-02.json`

## When it runs

- Every 10 minutes from 23:30 to 02:30 UTC (05:00 to 08:00 in India), when SGPC posts.
- Once an hour at other times.

GitHub's schedule has 2 limits:

- GitHub runs a schedule late, often by 5 to 15 minutes.
  raw.githubusercontent.com also keeps a file for 5 minutes.
  So the text can appear up to about 30 minutes after SGPC posts it.
- GitHub turns off scheduled workflows after 60 days with no repository activity.
  If the web app stops showing new text, open the Actions tab and enable the workflow again.
  You can also run it by hand with "Run workflow".
