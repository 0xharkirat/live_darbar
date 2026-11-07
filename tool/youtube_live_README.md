# YouTube live

This branch says which of SGPC's YouTube streams are live now.
The Live Darbar app reads it, and opens the live kirtan video.

Do not edit it by hand.
A GitHub Actions job writes it every 5 minutes.
The job is `.github/workflows/youtube-live.yml` on the `main` branch, and it runs `tool/youtube_live_check.dart`.

## Files

- `live.json`: the last check.
  - `checkedAt`: when the check ran, in UTC.
  - `channelId`: SGPC's channel, "SGPC, Sri Amritsar" (`UCYn6UEtQ771a_OWSiNBoG8w`).
  - `live`: the streams that are live, kirtan first, then katha, then audio.
    Each has `videoId`, `kind`, `title`, `url`, and `startedAt` when YouTube gives it.
    The list is empty when nothing is live.
- `events.jsonl`: 1 line each time a stream starts or ends, with the time of the check that saw it.
  It is the record of what SGPC streamed, and when.

## Kinds

- `kirtan`: kirtan from Sri Harmandir Sahib, with video.
- `katha`: the Hukamnama Katha from Gurdwara Sri Manji Sahib, with video.
- `audio`: audio only, with a still picture.
  SGPC runs it between the video streams.

The kind comes from the title. SGPC writes "(Audio)" in the audio stream's title, and "Katha" in the katha's.

## How a stream is believed

1. The channel's streams page marks the stream LIVE, or the channel's `/live` page shows it.
2. The stream's own page says that it plays, that it is on SGPC's channel, and that it is live now.

When the job cannot read a page, it writes nothing.
It never writes "nothing is live" when it could not check.
The branch then keeps the last good answer, and `checkedAt` grows old.
The app trusts `live.json` for 20 minutes after `checkedAt`, and then falls back to its timetable.

The branch holds 1 commit, which each run replaces.
