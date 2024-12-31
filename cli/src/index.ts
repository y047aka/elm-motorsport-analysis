// @ts-ignore
global.XMLHttpRequest = require('xhr2');

import { Elm } from './Elm/Main.elm';
import prompts from 'prompts';
import fs from 'fs';

const args = process.argv.slice(2).join();

const app = Elm.Main.init({ flags: args });

app.ports.output.subscribe(async opts => {
  try {
    const { value } = await prompts(opts);
    if (value === undefined) {
      process.exit(0);
    } else {
      app.ports.input.send(value);
    }
  } catch (e) {
    process.exit(1);
  }
});

app.ports.exitWithMsg.subscribe(([code, msg, data]) => {
  fs.writeFileSync(`../static/wec_2024/${msg}.json`, JSON.stringify(data, null, 2));
  console.log(`${msg}.json`);
  process.exit(code);
});
