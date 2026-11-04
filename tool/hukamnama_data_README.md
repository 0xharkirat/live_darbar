# Hukamnama data

This branch holds a copy of SGPC's Hukamnama text for the Live Darbar web app.
Each day also has the shabad line by line, from the Shabad OS database.

Do not edit it by hand.
A GitHub Actions job writes it.
The job is `.github/workflows/hukamnama-mirror.yml` on the `main` branch.

The Hukamnama text belongs to SGPC (sgpc.net).
The line data comes from Shabad OS (shabados.com).
See [Credits](#credits).

## Why this branch exists

SGPC's feed sends no CORS header, so a browser cannot read it.
raw.githubusercontent.com sends `access-control-allow-origin: *`, so the web app reads the copy from here.
The native apps read SGPC directly and do not use this branch.

## Files

- `hukamnama/YYYY-MM-DD.json`: SGPC's answer for that day, with the optional keys `shabad` and `lines` after it.
  The app reads it with the same parser that it uses for SGPC.
  The job does not change SGPC's keys.
- `hukamnama/latest.json`: a copy of the newest day.
- The last 31 days stay. The job deletes older files.

The day is the SGPC day, which is the date in India (UTC+5:30).
A file exists only after the job checks the answer.
A bad answer never replaces a good file.

## Lines from Shabad OS

The job adds 2 optional keys to a day: `shabad` and `lines`.
An app that does not know them ignores them.
The Hukamnama in the file is the same without them.

### How the job finds the shabad

1. SGPC gives the Ang (page) where the shabad starts, and its Gurmukhi text.
2. The job reads every line of Sri Guru Granth Sahib Ji from that Ang and the 15 pages after it.
3. It looks for a run of whole lines that has the same letters as the SGPC text.
   Spaces, pause marks, verse numbers and the `॥` sign do not count.
4. The run must start on SGPC's Ang.
   At least 98.5 percent of the letters must be the same.
   Every line of the run must be in the SGPC text.
   No other run may match nearly as well.

If one of these fails, the day has no `lines`, and `shabad.matched` is `false`.
The job never publishes lines that it is not sure about.
The 2 sources print a few words differently.
So the Gurmukhi of a line can differ from SGPC's text by a letter or two.
`shabad.similarity` says how close they are.

The job looks at a day once.
It looks again when SGPC changes the text, or when `shabad.version` or `shabad.matcher` changes.

### `shabad`

| Key | Type | Meaning |
| --- | --- | --- |
| `source` | string | Always `Shabad OS`. |
| `version` | string | The database release, for example `5.0.0-next.0`. |
| `matcher` | number | The version of the matching rules. |
| `matched` | boolean | `true` when `lines` is there. |
| `reason` | string | Only when `matched` is `false`: why not. |
| `similarity` | number | Only when matched: 0.985 to 1. |
| `ids` | list of strings | The Shabad OS ids of the shabad (a Hukamnama can cover more than 1). |
| `ang` | number | The Ang where the shabad starts. |
| `angEnd` | number | The Ang where it ends. |
| `sections` | list | The raag or other section, for example `{"roman": "Raag Dhanaasree"}`. |
| `writers` | list | The writers, for example `{"roman": "Guru Ramdas", "gurmukhi": "ਗੁਰੂ ਰਾਮਦਾਸ"}`. |
| `assets` | object | The Shabad OS asset id of each kind of data. |
| `credits` | object | Who made each kind of data, as short text for a screen. |

### `lines`

An array in reading order.
The title line of the shabad (for example `ਧਨਾਸਰੀ ਮਹਲਾ ੪ ॥`) is not in it, because SGPC gives it apart.

| Key | Type | Meaning |
| --- | --- | --- |
| `id` | string | The Shabad OS line id. |
| `ang` | number | The Ang that the line is on. |
| `gurmukhi` | string | The line, as Shabad OS has it, without the pause marks. |
| `vishraam` | list | The pauses. Left out when the line has none. |
| `english` | string | The English meaning of the line. Left out when there is none. |
| `punjabi` | string | The Punjabi meaning of the line. Left out when there is none. |

A pause is `{"after": 5, "weight": "heavy"}`.
`after` is the index of the word that the pause follows, counting from 0 over the words of `gurmukhi`.
`weight` is `heavy`, `medium` or `light`.
Shabad OS writes them in its text as `;`, `,` and `.`.

There is no `transliteration`.
The Shabad OS release that the job uses has none.

Example (cut short):

```json
{
  "shabad": {
    "source": "Shabad OS",
    "version": "5.0.0-next.0",
    "matcher": 1,
    "matched": true,
    "similarity": 1.0,
    "ids": ["R5B"],
    "ang": 668,
    "angEnd": 668,
    "sections": [{"roman": "Raag Dhanaasree"}],
    "writers": [{"gurmukhi": "ਗੁਰੂ ਰਾਮਦਾਸ", "roman": "Guru Ramdas"}]
  },
  "lines": [
    {
      "id": "015H",
      "ang": 668,
      "gurmukhi": "ਹਰਿ ਹਰਿ ਬੂੰਦ ਭਏ ਹਰਿ ਸੁਆਮੀ ਹਮ ਚਾਤ੍ਰਿਕ ਬਿਲਲ ਬਿਲਲਾਤੀ ॥",
      "vishraam": [{"after": 5, "weight": "heavy"}],
      "english": "The Lord, Har, Har, is the rain-drop; I am the song-bird, crying, crying out for it.",
      "punjabi": "ਹੇ ਹਰੀ! ਹੇ ਸੁਆਮੀ! ਮੈਂ ਪਪੀਹਾ ਤੇਰੇ ਨਾਮ-ਬੂੰਦ ਵਾਸਤੇ ਤੜਫ਼ ਰਿਹਾ ਹਾਂ। …"
    }
  ]
}
```

### How the job gets the database

The job downloads 1 pinned file when a day needs it: `master.sqlite` from the Shabad OS release `v5.0.0-next.0`.
It checks the SHA-256 (`517890c7e7c2f3dcef7f21b51d074a581b8eded4ebe14c504b84ea075ff16aeb`) before it reads the file.
The file is the same as `dist/master.sqlite` in the npm package `@shabados/database@5.0.0-next.0`.
A run that finds the day already done downloads nothing.
If the job cannot read the database, it saves the day without lines and the log has a warning.
The code is in `tool/shabad_os.dart` on the `main` branch.

## Credits

The line data comes from the Shabad OS database, `@shabados/database` 5.0.0-next.0.
Shabad OS is an open source project by volunteers.
Home: https://www.shabados.com.
Code and data: https://github.com/shabados/shabados (Shabad OS archived the older repository, https://github.com/shabados/database).

- The database code is MIT licensed: Copyright (c) Shabad OS Organization and Contributors.
- The Shabad OS README puts the Gurbani texts in the database in the public domain (Creative Commons Public Domain Mark 1.0).
  It forbids any change to the words that distorts the original work.
  So the job copies the Gurmukhi as the database has it.
  It only takes the pause marks out of the text and writes them apart.
- Shabad OS asks that you cite a change to a text.
  The job makes none.
  The sources, in the citation form that Shabad OS uses, are:
  - Gurmukhi (asset `SSA2`): Shabadaarth. Vol. 1-4, SGPC, Sri Amritsar, 2009-2012, www.archive.org/details/ShabdaarthSriGuruGranthSahibJi-Part1.
  - Pauses (the marks in the same text, asset `JSDS`): Dauder, Jaswant S. Sri Guru Granth Sahib Ji Shudh Ucharan, Arth Paath Vishraam Pothi, Sri Damdami Taksaal. Oct 2015, www.gursevak.com/drupal7/sites/default/files/Vishram%20Sri%20Guru%20Granth%20Sahib%20Jee.pdf.
  - English meaning (asset `DSSK`): Khalsa, Sant S. Siri Guru Granth Sahib Ji. 2013.
  - Punjabi meaning (asset `PSST`): Singh, Sahib. Sri Guru Granth Darpan. Vol. 1-10, Raaj Publishers, Hoshiarpur/Jalandhar, 1972, www.archive.org/details/SriGuruGranthSahibDarpan-Volume1.

The English and Punjabi meanings are the same works that SGPC prints as the meaning of the Hukamnama.
We checked 4 days in November 2026.
The English line meanings, joined, equal SGPC's English block to within 1 character.
The Punjabi line meanings equal SGPC's Punjabi block to within 2 characters on 3 days, and 14 on the 4th.

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
