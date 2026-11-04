# The release manifest

`web/release.json` tells installed apps about the newest release.
The site serves it at `https://darbar.live/release.json`.
Each app reads it once per launch.

This page is the reference for its optional fields.
The required fields and the deploy steps are in the file's own `_comment`.

## Optional fields

A file with neither field does what the app did before they existed.
The values in the file today have neither.

| Field | Where | Type | Effect |
| --- | --- | --- | --- |
| `minBuild` | Inside `android`, `ios` or `macos` | Whole number, 1 or more, and not above that entry's `build` | A build below it must update. See Forced update. |
| `maintenance` | At the top | Text, or an object with `en` and `pa` | A banner on every screen. See Maintenance banner. |

### Forced update

Set `minBuild` for a platform to the oldest build that still works.
The app compares build numbers, not version strings.

```json
"android": { "version": "3.1.0", "build": 11, "minBuild": 10 }
```

- A build below `minBuild` gets a sheet that cannot be closed. A tap on the dim, a swipe down, and the back button do nothing.
- The sheet has 1 button, "Update now". It opens the store page that is fixed in the app, whatever `stores` says. It stays open after the store opens, so a listener who comes back without updating meets it again.
- The sheet comes at each launch. A "Not now" from an earlier release does not hide it.
- Audio keeps playing. Only the screen is held.
- A build at or above `minBuild` gets the normal, soft offer if `build` is newer.
- Each platform has its own `minBuild`. A platform with none has no minimum.
- The app ignores a `minBuild` that is not a whole number from 1 up, or that is above `build`. A minimum above the newest build would force an update that is not in the store, and lock every listener out. `dart tool/build_site.dart` also refuses to deploy such a file.

WARNING: Publish the new build in the store before you raise `minBuild`. Raise `build` and `minBuild` in the same deploy, and only after the store shows the build.

### Maintenance banner

Add `maintenance` when the backend is down or changing and you want listeners to know.
The app keeps working: it plays what it can.

```json
"maintenance": {
  "en": "Live kirtan may stop for a few minutes while we fix the stream.",
  "pa": "ਅਸੀਂ ਸਟ੍ਰੀਮ ਠੀਕ ਕਰ ਰਹੇ ਹਾਂ। ਲਾਈਵ ਕੀਰਤਨ ਕੁਝ ਮਿੰਟਾਂ ਲਈ ਰੁਕ ਸਕਦਾ ਹੈ।"
}
```

- The banner sits at the top of every screen, under the offline banner. Nothing is blocked or covered.
- The text shows in the listener's language. A language with no text shows the other one. A plain string shows in both.
- Keep it to 1 or 2 sentences, in plain words. Say what the listener sees and, if you know, when it ends.
- Remove the key when the work ends. The banner leaves on the next launch, or when the app comes back to the front.
- Empty text, `null` and the word "null" mean no banner.
- The web app shows it too.

## Tests

`test/models/release_policy_test.dart` reads the fixtures in `test/fixtures/release_*.json`: a forced update, a minimum above the newest build, a maintenance message, and wrong values.
It also checks that today's `web/release.json` has neither field.
