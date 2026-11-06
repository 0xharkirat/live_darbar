// The Cloudflare Worker entry point. The logic and its notes are in timer.js.
//
// This file exports only the handler: the Workers runtime reads every named
// export of the main module as an entry point, and refuses to start when one
// is a constant or a plain function.

import { tick } from './timer.js';

export default {
  async scheduled(controller, env) {
    const now = new Date(controller.scheduledTime);
    // A plain call keeps the runtime's `this` for fetch.
    console.log(await tick({ now, env, fetch: (url, init) => fetch(url, init) }));
  },
};
