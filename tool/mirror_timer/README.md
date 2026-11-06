# Hukamnama mirror timer

A Cloudflare Worker that starts the GitHub job `.github/workflows/hukamnama-mirror.yml` soon after SGPC posts the day's Hukamnama.
The web app reads the Hukamnama from that job's copy, so the copy must be on time.

GitHub's own schedule starts runs late and skips many of them.
On 6 November 2026 it ran 1 of the 40 runs that the schedule asked for.
A Cloudflare cron trigger runs on time.

## How it works

The Worker runs every 5 minutes from 04:30 to 08:25 IST.
Each run does these checks in order, and stops at the first that holds:

1. The mirror has today's file: nothing to do.
2. SGPC says that today is not posted: wait for the next run.
3. A mirror job runs now, or one started less than 15 minutes ago: let it finish.
4. Start the job.

So the job starts about once a day, within about 5 minutes of SGPC.
The GitHub schedule stays as a fallback of 6 runs a day.

The Worker asks SGPC, not STTM (BaniDB).
SGPC posts the Hukamnama, and the job copies SGPC's answer.
Other feeds copy SGPC, so they are never earlier.

`src/timer.js` has the full notes.

## Cost

The Cloudflare free plan covers it.
The Worker makes 48 runs a day, and each run sends 1 to 4 small requests.
The free plan allows 100,000 requests a day and 5 cron triggers for each account.
The Worker uses 1 cron trigger.

## Set it up

This guide shows you how to put the timer on Cloudflare.
You need admin access to `0xharkirat/live_darbar` on GitHub, and a Cloudflare account.
A free Cloudflare account is enough.

Run each command in this folder, `tool/mirror_timer`.

1. Sign in to Cloudflare:

   ```sh
   npx wrangler@4.152.0 login
   ```

   The browser opens a Cloudflare page.
   Sign in, or make a free account, and then click **Allow**.
   Wrangler keeps the sign-in on this Mac.

2. Put the Worker on Cloudflare:

   ```sh
   npx wrangler@4.152.0 deploy
   ```

   The output lists the schedule `*/5 23,0-2 * * *`.
   The Worker has no web address, so nobody can start it from outside.

3. Make the GitHub token.
   The token lets the Worker start the job, and nothing else.
   1. Open <https://github.com/settings/personal-access-tokens/new>.
   2. In **Token name**, type `live-darbar-mirror-timer`.
   3. In **Expiration**, select **Custom**, and select the date 1 year from today.
      GitHub sends an email before the token ends.
   4. In **Repository access**, select **Only select repositories**, and then select `0xharkirat/live_darbar`.
   5. In **Permissions**, open **Repository permissions**, and set **Actions** to **Read and write**.
      GitHub adds **Metadata: Read-only** itself.
   6. Click **Generate token**, and then click the copy button beside the token.

   WARNING: Keep the token only on the clipboard. A token in a chat, a file, or a commit lets other people start and stop the jobs of this repository.

4. Give the token to the Worker, from the clipboard, and then clear the clipboard:

   ```sh
   pbpaste | npx wrangler@4.152.0 secret put GITHUB_TOKEN && pbcopy < /dev/null
   ```

   Cloudflare keeps the token encrypted.
   Nobody can read it back, not even you.

## Check that it works

The first check is on the next morning, after SGPC posts.
SGPC posts between about 05:00 and 08:00 IST.
That is 10:30 to 13:30 in Sydney during daylight saving time.

1. Open the Cloudflare dashboard, and go to **Workers & Pages** > **live-darbar-mirror-timer** > **Logs**.
   Each run writes 1 line.
   A good morning shows these lines, in this order, here for 7 November 2026:
   - `Waiting: SGPC has not posted 2026-11-07.`
   - `Started the mirror job: SGPC posted 2026-11-07.`
   - `Done: the mirror has 2026-11-07.`
2. On GitHub, open **Actions** > **Hukamnama mirror**.
   A green run with the event **workflow_dispatch** shows about 5 minutes after SGPC posted.
   You can also run `gh run list --workflow hukamnama-mirror.yml --event workflow_dispatch --limit 3`.

## When a run fails

The log line says why.

- `HTTP 401` or `HTTP 403`, with "The token is wrong, expired": make a new token (step 3), and then do step 4 again.
- `Started the mirror job: SGPC's answer ... was not clear`: SGPC sent an error page or blocked Cloudflare.
  The job still asks SGPC itself, at most 4 times an hour.
  When this shows every day, read the line before it, which says what SGPC sent.

While the Worker fails, the GitHub schedule still starts the job a few times a day.
The web app then gets the new day late, but it gets it.

## Change the code

1. Run the tests. They need Node and no packages:

   ```sh
   npm test
   ```

2. Run the Worker on this Mac, in Cloudflare's runtime.
   Use a fake token, so the run cannot start a real job:

   ```sh
   npx wrangler@4.152.0 dev --test-scheduled --var GITHUB_TOKEN:not-a-real-token
   ```

   Then, in a second terminal, start 1 run:

   ```sh
   curl "http://localhost:8787/__scheduled?cron=*/5+23,0-2+*+*+*"
   ```

   The first terminal shows the run's log line.

3. Put the new code on Cloudflare with step 2 of the setup.

`src/index.js` exports only the Worker's handler.
The Workers runtime reads every export of the main file as an entry point.
It refuses to start when one is a constant or a plain function.
Put new code in `src/timer.js`.
