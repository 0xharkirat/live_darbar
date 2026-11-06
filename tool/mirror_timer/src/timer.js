// The Hukamnama mirror timer: the logic of the Cloudflare Worker that starts
// the GitHub job .github/workflows/hukamnama-mirror.yml soon after SGPC posts
// the day's Hukamnama. src/index.js is the Worker's entry point.
//
// Why: the web app reads the Hukamnama from the mirror, so the mirror must
// copy it soon after SGPC posts it. SGPC posts at a different time each
// morning, between about 05:00 and 08:00 IST, and sends no alert. GitHub's own
// schedule starts runs late and skips many: on 6 November 2026 it ran 1 of the
// 40 runs asked for. A Cloudflare cron trigger fires on time.
//
// The Worker runs every 5 minutes from 04:30 to 08:25 IST (wrangler.jsonc).
// Each run does these checks in order, and stops at the first that holds:
// 1. The mirror has today's file: nothing to do.
// 2. SGPC says today is not posted: wait for the next run.
// 3. A mirror job runs now, or one started in the last 15 minutes: let it
//    finish. The new file can take some minutes to show on
//    raw.githubusercontent.com, so this stops a second start.
// 4. Start the job.
// So the job starts about once a day, within about 5 minutes of SGPC.
//
// It asks SGPC, not STTM (BaniDB), because SGPC posts the Hukamnama and the
// mirror copies SGPC's answer. Any other feed copies SGPC, so it is never
// earlier.
//
// When SGPC's answer cannot be read (an error page, a block), the Worker goes
// on to step 3 and lets the job ask SGPC itself. The 15-minute rule keeps that
// to at most 4 starts an hour, and the log says why.
//
// Secrets: GITHUB_TOKEN, a fine-grained token for this repository only, with
// "Actions: Read and write". See README.md.

/** SGPC's archive endpoint. The same URL as `kSgpcArchiveUrl` in
 *  tool/hukamnama_mirror.dart and `kHukamnamaArchiveUrl` in the app. */
export const SGPC_URL = 'https://hs.sgpc.net/hssearchhukmanamaTestCalender.php';

/** A mirror job that started less than this long ago is let finish. */
export const RECENT_MS = 15 * 60 * 1000;

const INDIA_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;
const USER_AGENT = 'live-darbar-mirror-timer';

/** The SGPC day of [now], as `YYYY-MM-DD`. SGPC's day starts at midnight IST. */
export function sgpcDay(now) {
  return new Date(now.getTime() + INDIA_OFFSET_MS).toISOString().slice(0, 10);
}

/** Whether the mirror has [day]'s file. A fault counts as "no": the next
 *  checks then decide, and step 3 stops a second start. */
async function mirrorHas(day, env, fetch, log) {
  const url = `https://raw.githubusercontent.com/${env.REPO}/hukamnama-data/hukamnama/${day}.json`;
  try {
    const response = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
    if (response.status === 200) return true;
    if (response.status !== 404) log(`The mirror answered HTTP ${response.status}.`);
  } catch (e) {
    log(`The mirror could not be read (${e}).`);
  }
  return false;
}

/**
 * What SGPC says about [day]: `posted`, `not-posted`, or `unknown`.
 *
 * The rules are the ones of `checkSgpcReply` in tool/hukamnama_mirror.dart.
 * SGPC needs the `X-Requested-With` header. Without it, SGPC answers 200 with
 * an empty body.
 */
export async function askSgpc(day, fetch, log) {
  let response;
  try {
    response = await fetch(SGPC_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent': USER_AGENT,
      },
      body: `selected_date=${day}`,
    });
  } catch (e) {
    log(`SGPC could not be reached (${e}).`);
    return 'unknown';
  }
  if (response.status !== 200) {
    log(`SGPC answered HTTP ${response.status}.`);
    return 'unknown';
  }
  let json;
  try {
    json = JSON.parse(await response.text());
  } catch {
    log('SGPC sent a body that is not JSON.');
    return 'unknown';
  }
  if (json?.supported === false) return 'not-posted';
  const hukamnama = json?.hukamnama;
  if (
    json?.supported === true &&
    hukamnama?.date === day &&
    typeof hukamnama.ghukamnama === 'string' &&
    hukamnama.ghukamnama.trim() !== ''
  ) {
    return 'posted';
  }
  log('SGPC sent JSON that is not a Hukamnama for today.');
  return 'unknown';
}

function github(env, path, init = {}) {
  return {
    url: `https://api.github.com/repos/${env.REPO}/actions/workflows/${env.WORKFLOW}${path}`,
    init: {
      ...init,
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': USER_AGENT,
        ...init.headers,
      },
    },
  };
}

/** Throws an error that says what to do about a GitHub failure. */
async function githubFailure(what, response) {
  const hint =
    response.status === 401 || response.status === 403
      ? ' The token is wrong, expired, or lacks "Actions: Read and write". Make a new one (README.md).'
      : '';
  const body = (await response.text()).slice(0, 300);
  return new Error(`GitHub ${what}: HTTP ${response.status}.${hint} ${body}`.trim());
}

/** Whether a mirror job runs now, or started less than [RECENT_MS] ago. */
async function jobBusy(now, env, fetch) {
  const { url, init } = github(env, '/runs?per_page=1');
  const response = await fetch(url, init);
  if (!response.ok) throw await githubFailure('could not list the mirror runs', response);
  const run = (await response.json()).workflow_runs?.[0];
  if (!run) return false;
  if (run.status !== 'completed') return true;
  return now.getTime() - Date.parse(run.created_at) < RECENT_MS;
}

async function startJob(env, fetch) {
  const { url, init } = github(env, '/dispatches', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ref: env.REF }),
  });
  const response = await fetch(url, init);
  if (!response.ok) throw await githubFailure('did not start the mirror job', response);
}

/**
 * One run of the timer at [now]. Returns 1 line for the log. Throws when
 * GitHub refuses, so Cloudflare marks the run as failed.
 */
export async function tick({ now, env, fetch, log = console.log }) {
  if (!env.GITHUB_TOKEN) {
    throw new Error('GITHUB_TOKEN is not set. Add it with `wrangler secret put` (README.md).');
  }
  const day = sgpcDay(now);
  if (await mirrorHas(day, env, fetch, log)) return `Done: the mirror has ${day}.`;

  const sgpc = await askSgpc(day, fetch, log);
  if (sgpc === 'not-posted') return `Waiting: SGPC has not posted ${day}.`;

  if (await jobBusy(now, env, fetch)) {
    return `Waiting: a mirror job for ${day} runs now or started less than 15 minutes ago.`;
  }
  await startJob(env, fetch);
  return sgpc === 'posted'
    ? `Started the mirror job: SGPC posted ${day}.`
    : `Started the mirror job: SGPC's answer for ${day} was not clear, so the job asks SGPC itself.`;
}
