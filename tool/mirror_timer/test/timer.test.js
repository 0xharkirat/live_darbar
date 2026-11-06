// Tests for the mirror timer. Run them with Node, no packages needed, from
// tool/mirror_timer:
//
//   npm test
//
// Each test gives the Worker a fake `fetch` that answers like the mirror,
// SGPC, and GitHub, and records what the Worker asked.

import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { RECENT_MS, SGPC_URL, sgpcDay, tick } from '../src/timer.js';

const env = {
  REPO: '0xharkirat/live_darbar',
  WORKFLOW: 'hukamnama-mirror.yml',
  REF: 'main',
  GITHUB_TOKEN: 'test-token',
};

// 06:00 IST on 6 November 2026.
const now = new Date('2026-11-06T00:30:00Z');
const day = '2026-11-06';

const mirrorUrl = `https://raw.githubusercontent.com/0xharkirat/live_darbar/hukamnama-data/hukamnama/${day}.json`;
const runsUrl =
  'https://api.github.com/repos/0xharkirat/live_darbar/actions/workflows/hukamnama-mirror.yml/runs?per_page=1';
const dispatchUrl =
  'https://api.github.com/repos/0xharkirat/live_darbar/actions/workflows/hukamnama-mirror.yml/dispatches';

const posted = {
  supported: true,
  hukamnama: { date: day, ang: 864, ghukamnama: 'ਗੋਂਡ ਮਹਲਾ ੫ ॥' },
};
const notPosted = {
  supported: false,
  hukamnama: { date: day, message: 'No Hukamnama Available for this date.' },
};

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

/** A run that started [minutesAgo] before [now]. */
const runs = (status, minutesAgo) => ({
  total_count: 1,
  workflow_runs: [
    { status, created_at: new Date(now.getTime() - minutesAgo * 60 * 1000).toISOString() },
  ],
});

/**
 * A fake fetch. [answers] maps each URL to a Response, or to a function that
 * returns one. A URL with no answer fails the test.
 */
function fakeFetch(answers) {
  const calls = [];
  const fetch = async (url, init = {}) => {
    calls.push({ url, init });
    const answer = answers[url];
    if (answer === undefined) throw new Error(`Unexpected request: ${url}`);
    return typeof answer === 'function' ? answer(init) : answer.clone();
  };
  return { fetch, calls, urls: () => calls.map((c) => c.url) };
}

const run = (fake, logs = []) =>
  tick({ now, env, fetch: fake.fetch, log: (line) => logs.push(line) });

describe('sgpcDay', () => {
  test('starts the day at midnight IST', () => {
    assert.equal(sgpcDay(new Date('2026-11-05T18:29:59Z')), '2026-11-05');
    assert.equal(sgpcDay(new Date('2026-11-05T18:30:00Z')), '2026-11-06');
  });

  test('is the next day in UTC terms for the whole morning window', () => {
    // The timer's first run, 23:00 UTC, is 04:30 IST on the next day.
    assert.equal(sgpcDay(new Date('2026-11-05T23:00:00Z')), '2026-11-06');
    assert.equal(sgpcDay(new Date('2026-11-06T02:55:00Z')), '2026-11-06');
  });
});

describe('tick', () => {
  test('does nothing more when the mirror has today', async () => {
    const fake = fakeFetch({ [mirrorUrl]: json(200, posted) });
    assert.equal(await run(fake), `Done: the mirror has ${day}.`);
    assert.deepEqual(fake.urls(), [mirrorUrl]);
  });

  test('waits while SGPC has not posted today', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('404: Not Found', { status: 404 }),
      [SGPC_URL]: json(200, notPosted),
    });
    assert.equal(await run(fake), `Waiting: SGPC has not posted ${day}.`);
    assert.deepEqual(fake.urls(), [mirrorUrl, SGPC_URL]);
  });

  test('asks SGPC the way SGPC needs', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, notPosted),
    });
    await run(fake);
    const sgpc = fake.calls[1].init;
    assert.equal(sgpc.method, 'POST');
    assert.equal(sgpc.headers['X-Requested-With'], 'XMLHttpRequest');
    assert.match(sgpc.headers['Content-Type'], /^application\/x-www-form-urlencoded/);
    assert.equal(sgpc.body, `selected_date=${day}`);
  });

  test('starts the job once SGPC has posted today', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, posted),
      [runsUrl]: json(200, runs('completed', 18 * 60)),
      [dispatchUrl]: new Response(null, { status: 204 }),
    });
    assert.equal(await run(fake), `Started the mirror job: SGPC posted ${day}.`);
    assert.deepEqual(fake.urls(), [mirrorUrl, SGPC_URL, runsUrl, dispatchUrl]);

    const dispatch = fake.calls[3].init;
    assert.equal(dispatch.method, 'POST');
    assert.deepEqual(JSON.parse(dispatch.body), { ref: 'main' });
    assert.equal(dispatch.headers.Authorization, 'Bearer test-token');
    assert.equal(fake.calls[2].init.headers.Authorization, 'Bearer test-token');
    // GitHub refuses a request with no User-Agent.
    assert.ok(dispatch.headers['User-Agent']);
  });

  test('starts the job when the workflow has never run', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, posted),
      [runsUrl]: json(200, { total_count: 0, workflow_runs: [] }),
      [dispatchUrl]: new Response(null, { status: 204 }),
    });
    assert.equal(await run(fake), `Started the mirror job: SGPC posted ${day}.`);
  });

  for (const [name, status, minutesAgo] of [
    ['a job runs now', 'in_progress', 2],
    ['a job waits in the queue', 'queued', 1],
    // GitHub can hold a run in the queue, or a slow download can run long.
    ['a job has waited or run for 20 minutes', 'in_progress', 20],
    ['a job finished a short time ago', 'completed', 6],
  ]) {
    test(`does not start a second job when ${name}`, async () => {
      // The new file can take some minutes to show on raw.githubusercontent.com.
      const fake = fakeFetch({
        [mirrorUrl]: new Response('', { status: 404 }),
        [SGPC_URL]: json(200, posted),
        [runsUrl]: json(200, runs(status, minutesAgo)),
      });
      assert.match(await run(fake), /^Waiting: a mirror job/);
      assert.ok(!fake.urls().includes(dispatchUrl));
    });
  }

  test('starts a job again when the last one is more than 15 minutes old', async () => {
    // For example, the last job failed because SGPC sent a bad answer.
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, posted),
      [runsUrl]: json(200, runs('completed', RECENT_MS / 60000 + 1)),
      [dispatchUrl]: new Response(null, { status: 204 }),
    });
    assert.match(await run(fake), /^Started/);
  });

  for (const [name, answer] of [
    ['an error page', () => new Response('<html>Forbidden</html>', { status: 403 })],
    ['an empty body', () => new Response('', { status: 200 })],
    ['another day', () => json(200, { ...posted, hukamnama: { ...posted.hukamnama, date: '2026-11-05' } })],
    ['no text', () => json(200, { ...posted, hukamnama: { date: day, ghukamnama: ' ' } })],
    ['a network fault', () => { throw new TypeError('fetch failed'); }],
  ]) {
    test(`lets the job ask SGPC itself when SGPC sends ${name}`, async () => {
      const logs = [];
      const fake = fakeFetch({
        [mirrorUrl]: new Response('', { status: 404 }),
        [SGPC_URL]: answer,
        [runsUrl]: json(200, runs('completed', 60)),
        [dispatchUrl]: new Response(null, { status: 204 }),
      });
      assert.match(await run(fake, logs), /^Started the mirror job: SGPC's answer .* was not clear/);
      assert.equal(logs.length, 1, 'the log says what SGPC sent');
    });
  }

  test('goes on to SGPC when the mirror cannot be read', async () => {
    const logs = [];
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 503 }),
      [SGPC_URL]: json(200, notPosted),
    });
    assert.equal(await run(fake, logs), `Waiting: SGPC has not posted ${day}.`);
    assert.deepEqual(logs, ['The mirror answered HTTP 503.']);
  });

  test('fails the run and names the token when GitHub refuses it', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, posted),
      [runsUrl]: json(200, runs('completed', 60)),
      [dispatchUrl]: json(401, { message: 'Bad credentials' }),
    });
    await assert.rejects(run(fake), /HTTP 401\. The token is wrong, expired/);
  });

  test('fails the run when GitHub cannot list the runs', async () => {
    const fake = fakeFetch({
      [mirrorUrl]: new Response('', { status: 404 }),
      [SGPC_URL]: json(200, posted),
      [runsUrl]: json(500, { message: 'Server Error' }),
    });
    await assert.rejects(run(fake), /could not list the mirror runs: HTTP 500/);
  });

  test('fails the run, and asks nobody, when the token is missing', async () => {
    const fake = fakeFetch({});
    await assert.rejects(
      tick({ now, env: { ...env, GITHUB_TOKEN: undefined }, fetch: fake.fetch }),
      /GITHUB_TOKEN is not set/,
    );
    assert.deepEqual(fake.calls, []);
  });
});
