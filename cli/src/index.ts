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
  // Get the mode from the command line arguments
  const mode = args.split('/')[0];

  // Determine the output path based on the mode
  let outputPath = '';
  if (mode === 'fe') {
    outputPath = `../app/static/formurla_e/2025/${msg}.json`;
  } else {
    // Default to WEC path
    outputPath = `../app/static/wec/2025/${msg}.json`;
  }

  fs.writeFileSync(outputPath, JSON.stringify(data, null, 2));
  console.log(`${msg}.json`);
  process.exit(code);
});
