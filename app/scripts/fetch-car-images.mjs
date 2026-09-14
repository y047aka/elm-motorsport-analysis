// Fills a season's half of `static/car-images.json`, and the directory it
// names, from two sources of the one publisher.
//
// A round's entry list comes from `api-he.lemans.org`, which states a car's
// number and where its photograph is rather than leaving either to be read out
// of a page. It is the only one of the two that has Le Mans's LMP2 field: that
// class is the organiser's and not the championship's, so fiawec.com, whose
// categories are Hypercar and LMGT3, does not carry it.
//
// What that API has no list of is which races a season ran, so the season's
// page at fiawec.com is still what says that -- and it is also the one photograph
// per car that a round is compared against.
//
// Every round has an upload of its own for every car, most of them the season's
// picture again under another name, so what a round is registered for is the
// picture differing and not the file: they are compared by what they hold.
//
// The photographs are taken from the bucket both sites are served out of, which
// holds them at the size they were uploaded, and are kept as WebP. The app draws
// a car 260px wide at most, so what is kept is the width they arrive at and a
// quality well under lossless: measured against the original as the card draws
// it, spending bytes on resolution beats spending them on quality, and past
// about q75 neither buys anything the page can show.
//
// What a picture is compared against is the original that was downloaded, not
// the WebP written from it, so `origins` remembers each original's digest. A
// run that has it asks for no image it already holds.
//
// Every request waits behind the one before it -- see `politely` -- so a run
// asks no faster than a reader would.
//
//     node scripts/fetch-car-images.mjs [--season 2026] [--dry-run]

import { mkdir, readFile, writeFile, readdir, rm } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const tablePath = join(appDir, "static/car-images.json");
const calendarPath = join(appDir, "static/wec/index.json");
const originsPath = join(appDir, "scripts/car-image-origins.json");

const origin = "https://www.fiawec.com";
const api = "https://api-he.lemans.org/evo/1";
const uploads = "https://storage.googleapis.com/editorial-prod/uploads";

// Named so the site's operators can see what is asking.
const userAgent = "elm-motorsport-analysis/1.0 (car photograph fetcher)";

// The least this leaves between one request and the next. A run is a few
// hundred of them and none is urgent, so they are spaced rather than spent as
// fast as they can be answered.
const restBetweenRequests = 1000;

// The API answers only a caller the site would have. Sent because it is asked
// for, not to look like something this is not: the agent above still says what
// is running.
const asThePageAsks = {
  Origin: "https://www.24h-lemans.com",
  Referer: "https://www.24h-lemans.com/",
};

// `-sharp_yuv` is the one flag here worth its bytes: WebP's lossy mode is YUV
// 4:2:0 whatever the quality, and the sharper conversion recovers a tenth of
// the error it costs for a twenty-fifth of the size.
const encoding = ["-q", "75", "-sharp_yuv"];

const run = promisify(execFile);

async function main() {
  const { season, dryRun } = readArgs(process.argv.slice(2));

  // The grid page shows one season, and is asked to show another the way its
  // own filter does. `/en/car/<season>` reaches a past season too, but without
  // the race filter, which is the half of the page this needs most.
  const grid = await page("/en/page/grid");
  const source = seasonOn(grid.html) === season ? grid : await showing(grid, season);
  if (seasonOn(source.html) !== season) {
    throw new Error(`the grid page cannot be made to show ${season}.`);
  }

  // A season still being run is a photograph per car here; one the site keeps
  // only in its archive lists the cars and not their pictures, and then the
  // rounds are the whole of where a car's photographs come from.
  const allSeason = new Map(carsOn(source.html).map((car) => [car.carNumber, car.file]));

  const skipped = [];
  const rounds = new Map();
  for (const race of await racesOn(source, season, skipped)) {
    rounds.set(race.round, await entered(race));
  }
  if (allSeason.size === 0 && rounds.size === 0) {
    throw new Error(
      `nothing of ${season} was found: neither ${origin}${source.path} nor a round of it` +
        ` named a car. It is no longer the shape this reads.`,
    );
  }

  const imageDir = join(appDir, "static/images/wec", String(season));
  const origins = JSON.parse(await readFile(originsPath, "utf8"));
  const images = imageStore(imageDir, (origins[String(season)] ??= {}));
  const { liveries, sameAgain } = await collect(allSeason, rounds, images);

  const downloaded = [];
  const held = [];
  for (const source of filesIn(liveries)) {
    if (images.onDisk(source)) {
      held.push(source);
      continue;
    }
    if (!dryRun) {
      await mkdir(imageDir, { recursive: true });
      await images.write(source);
    }
    downloaded.push(source);
  }
  if (!dryRun) await writeFile(originsPath, JSON.stringify(origins, null, 2) + "\n");

  const table = JSON.parse(await readFile(tablePath, "utf8"));
  const entry = (table.seasons[String(season)] ??= {
    basePath: `/static/images/wec/${season}`,
    cars: {},
  });
  const changed = register(entry, liveries);
  if (!dryRun) await writeFile(tablePath, render(table));

  await report({
    season, source, liveries, downloaded, held, changed, skipped, sameAgain, imageDir, dryRun,
  });
}

/** What each car carries, and how many of a round's photographs turned out to
 * be the season's again. A car the season's page does not have -- entered for
 * one round, which is most of Le Mans's field -- takes its first round's
 * photograph as the one it carries. */
async function collect(allSeason, rounds, images) {
  const carNumbers = new Set([...allSeason.keys(), ...[...rounds.values()].flatMap((r) => [...r.keys()])]);

  const liveries = new Map();
  let sameAgain = 0;
  for (const carNumber of carNumbers) {
    const still =
      allSeason.get(carNumber) ??
      [...rounds.values()].map((cars) => cars.get(carNumber)).find((file) => file !== undefined);
    const livery = { default: still };

    for (const [round, cars] of rounds) {
      const file = cars.get(carNumber);
      if (file === undefined || file === still) continue;
      if (await images.alike(file, still)) {
        sameAgain += 1;
        continue;
      }
      (livery.rounds ??= {})[round] = file;
    }
    liveries.set(carNumber, livery);
  }
  return { liveries, sameAgain };
}

/** What a photograph is written as. The name the publisher gave it is kept --
 * it carries the upload it came from -- and only what it holds changes. */
function kept(source) {
  return source.replace(/\.[^.]+$/, "") + ".webp";
}

/** The originals, and what is written from them.
 *
 * `origins` is each original's digest, remembered because the WebP written from
 * it cannot be compared against another original. A season whose originals are
 * all remembered downloads no image at all. */
function imageStore(dir, origins) {
  const bytes = new Map();

  const original = async (source) => {
    if (!bytes.has(source)) {
      bytes.set(source, Buffer.from(await (await get(`${uploads}/${source}`)).arrayBuffer()));
    }
    return bytes.get(source);
  };

  const onDisk = (source) => existsSync(join(dir, kept(source)));

  const digest = async (source) => {
    if (origins[source] === undefined) {
      // The WebP here was written from this original and cannot stand in for
      // it, and asking the site for a picture already held is the one thing
      // this must not do. So the digest is restored rather than re-fetched.
      if (onDisk(source)) {
        throw new Error(
          `${kept(source)} is here and its original's digest is not in` +
            ` ${originsPath}. Put it back there, or take the file away.`,
        );
      }
      origins[source] = createHash("sha256").update(await original(source)).digest("hex");
    }
    return origins[source];
  };

  return {
    onDisk,
    alike: async (a, b) => (await digest(a)) === (await digest(b)),
    // `cwebp` reads and writes files rather than pipes, so the original is put
    // beside what is written from it and taken away again.
    write: async (source) => {
      const from = join(dir, `.${source}.original`);
      await writeFile(from, await original(source));
      try {
        await run("cwebp", ["-quiet", ...encoding, from, "-o", join(dir, kept(source))]);
      } finally {
        await rm(from, { force: true });
      }
    },
  };
}

/** The season a page is of, which its cars are the ones linked to of. */
function seasonOn(html) {
  const seasons = new Set(
    [...html.matchAll(/href="\/en\/car\/(\d{4})\/[^"]+"/g)].map(([, year]) => Number(year)),
  );
  return seasons.size === 1 ? [...seasons][0] : null;
}

/** The photographs of cars, which are the images whose `alt` is the number of a
 * car the page links to. The manufacturer's badge beside each carries its name
 * there instead. */
function carsOn(html) {
  const numbers = new Set(
    [...html.matchAll(/href="\/en\/car\/\d{4}\/([^"]+)"/g)].map(([, number]) => number),
  );
  const images = html.matchAll(/<img[^>]*\bsrc="\/uploads\/([^"]+?)"[^>]*\balt="([^"]*)"/g);

  const cars = new Map();
  for (const [, file, alt] of images) {
    if (numbers.has(alt)) cars.set(alt, { carNumber: alt, file });
  }
  return [...cars.values()];
}

/** The races the season ran, as the calendar names them. A race the calendar
 * has no round for is one this application cannot show and does not collect.
 *
 * The race filter is the one select the component acts on: the other changes
 * the season, and does it by going to another page. */
async function racesOn(source, season, skipped) {
  const select = [...source.html.matchAll(/<select\b[^>]*>[\s\S]*?<\/select>/g)]
    .map((match) => match[0])
    .find((block) => block.includes("data-live-action-param="));
  if (select === undefined) return [];

  const rounds = await calendarRounds(season);
  const races = [];
  for (const [, id, name] of select.matchAll(/<option[^>]*value="(\d+)"[^>]*>\s*([^<]*?)\s*<\/option>/g)) {
    const found = rounds.filter((round) => plainly(name).includes(plainly(round.name)));
    if (found.length === 1) races.push({ id, name, round: found[0].id });
    else skipped.push({ name, why: found.length === 0 ? "no round of the calendar" : "more than one" });
  }
  return races;
}

async function calendarRounds(season) {
  const calendar = JSON.parse(await readFile(calendarPath, "utf8"));
  return calendar.seasons.find((s) => Number(s.season) === season)?.rounds ?? [];
}

const plainly = (name) => name.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();

/** The grid page showing a season other than the one it opened on. The
 * component is given back the props it was rendered with -- they carry a
 * checksum this cannot compute -- and the season as the one value changed. */
async function showing(grid, season) {
  const seasons = await json(`${api}/seasons`, asThePageAsks);
  const found = seasons.member.filter((s) => String(s.year) === String(season));
  if (found.length !== 1) throw new Error(`${api}/seasons names no one season ${season}.`);

  const html = await live(grid, "changeSeason", { seasonId: String(found[0].id) });
  const props = html.match(/data-live-props-value="([^"]*)"/);
  return {
    path: grid.path,
    html,
    props: props === null ? null : JSON.parse(unescaped(props[1])),
    liveUrl: grid.liveUrl,
  };
}

/** One value changed on a live component, and the markup it renders as. */
async function live(source, action, updated) {
  const body = new FormData();
  body.set("data", JSON.stringify({ props: source.props, updated, args: {} }));

  const answer = await politely(() =>
    fetch(`${origin}${source.liveUrl}/${action}`, {
      method: "POST",
      body,
      headers: {
        "User-Agent": userAgent,
        Accept: "application/vnd.live-component+html",
        "X-Requested-With": "XMLHttpRequest",
        "X-Live-Url": source.path,
      },
    }),
  );
  if (!answer.ok) {
    throw new Error(`${action} answered ${answer.status} ${answer.statusText}`);
  }
  return answer.text();
}

/** The cars of a round, as the organiser's own list of them. `participant_number`
 * is the number itself rather than something a number has to be read out of,
 * and `large_picture_url` names the photograph at the size it was uploaded. */
async function entered(race) {
  const answer = await json(`${api}/entries?race=${race.id}`, asThePageAsks);
  const entries = Object.values(answer).find(Array.isArray);
  if (entries === undefined) throw new Error(`${race.name} came back with no entry list.`);

  const cars = new Map();
  for (const entry of entries) {
    const file = entry.large_picture_url?.split("/uploads/").at(-1);
    if (file !== undefined) cars.set(String(entry.participant_number), file);
  }
  return cars;
}

async function json(url, headers) {
  const answer = await get(url, headers).then((r) => r.json());
  // The API answers a caller it will not serve with a string holding the
  // refusal, which parses and would otherwise be read as an empty result.
  return typeof answer === "string" ? JSON.parse(answer) : answer;
}

async function page(path) {
  const html = await get(origin + path).then((r) => r.text());
  const props = html.match(/data-live-props-value="([^"]*)"/);
  const liveUrl = html.match(/data-live-url-value="([^"]*)"/);
  return {
    path,
    html,
    props: props === null ? null : JSON.parse(unescaped(props[1])),
    liveUrl: liveUrl === null ? null : unescaped(liveUrl[1]),
  };
}

const unescaped = (attribute) =>
  attribute
    .replaceAll("&quot;", '"')
    .replaceAll("&#039;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&amp;", "&");

function filesIn(liveries) {
  const files = new Set();
  for (const { default: still, rounds } of liveries.values()) {
    files.add(still);
    for (const file of Object.values(rounds ?? {})) files.add(file);
  }
  return files;
}

/** Writes each car's liveries into the season, and says which of them the table
 * did not already say. A car carrying one photograph all season is written as
 * the file alone, which is most of them.
 *
 * The table names what is on the disk, so the publisher's name for a photograph
 * is carried over to it and only the suffix differs. */
function register(entry, liveries) {
  const changed = [];
  for (const [carNumber, livery] of liveries) {
    const still = kept(livery.default);
    const written =
      livery.rounds === undefined
        ? still
        : {
            default: still,
            rounds: Object.fromEntries(
              Object.entries(livery.rounds).map(([round, file]) => [round, kept(file)]),
            ),
          };
    const held = entry.cars[carNumber];
    if (JSON.stringify(held) === JSON.stringify(written)) continue;

    entry.cars[carNumber] = written;
    changed.push({ carNumber, was: held, now: written });
  }
  return changed;
}

/** The table as the file holds it.
 *
 * Written out a key at a time rather than by `JSON.stringify`, which orders an
 * object's integer-like keys ahead of the rest however they were set: car 7 and
 * car 007 are two cars, and the one would be carried off to the end of the
 * season away from the other. A season this run never asked about would be
 * rewritten for it.
 */
function render(table) {
  const seasons = Object.keys(table.seasons)
    .sort()
    .map((season) => {
      const { basePath, cars } = table.seasons[season];
      const written = byCarNumber(Object.keys(cars))
        .map((n) => `        ${JSON.stringify(n)}: ${indented(cars[n], 8)}`)
        .join(",\n");
      return (
        `    ${JSON.stringify(season)}: {\n` +
        `      "basePath": ${JSON.stringify(basePath)},\n` +
        `      "cars": {${written === "" ? "" : `\n${written}\n      `}}\n` +
        `    }`
      );
    });
  return `{\n  "seasons": {\n${seasons.join(",\n")}\n  }\n}\n`;
}

/** Numerically, and a number written with leading zeros after the number it
 * would otherwise share a place with. */
function byCarNumber(carNumbers) {
  return carNumbers.sort((a, b) => Number(a) - Number(b) || a.length - b.length);
}

function indented(value, depth) {
  return JSON.stringify(value, null, 2).replaceAll("\n", "\n" + " ".repeat(depth));
}

async function get(url, headers) {
  const answer = await politely(() =>
    fetch(url, { headers: { "User-Agent": userAgent, ...headers } }),
  );
  if (!answer.ok) throw new Error(`${url} answered ${answer.status} ${answer.statusText}`);
  return answer;
}

/** Every request this makes, one at a time and none of them sooner than
 * `restBetweenRequests` after the last. Held as a chain rather than a counter so
 * that it holds however the callers are written -- nothing here can start a
 * second request by forgetting to await the first.
 *
 * A run is a few hundred requests against someone else's site and none of them
 * is urgent, so the run is slow on purpose. Nothing is retried: a refusal is
 * reported and the run stops, rather than being asked again.
 */
let lastRequest = Promise.resolve(0);
function politely(send) {
  const answer = lastRequest.then(async (finished) => {
    const rest = restBetweenRequests - (Date.now() - finished);
    if (rest > 0) await new Promise((wake) => setTimeout(wake, rest));
    return send();
  });
  lastRequest = answer.then(
    () => Date.now(),
    () => Date.now(),
  );
  return answer;
}

function readArgs(argv) {
  let season = 2026;
  let dryRun = false;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--season") season = Number(argv[++i]);
    else if (argv[i] === "--dry-run") dryRun = true;
    else throw new Error(`unknown argument: ${argv[i]}`);
  }
  if (!Number.isInteger(season)) throw new Error("--season takes a year");
  return { season, dryRun };
}

async function report({
  season, source, liveries, downloaded, held, changed, skipped, sameAgain, imageDir, dryRun,
}) {
  const say = (n, one, many) => `${n} ${n === 1 ? one : many}`;
  const apart = [...liveries.values()].filter((livery) => livery.rounds !== undefined).length;
  console.log(
    `${dryRun ? "Would take" : "Took"} ${say(liveries.size, "car", "cars")} off ${source.path}` +
      `${apart === 0 ? "" : `, ${say(apart, "car", "cars")} photographed apart for a round`}: ` +
      `${say(downloaded.length, "photograph", "photographs")} ${dryRun ? "to download" : "downloaded"}, ` +
      `${held.length} already here` +
      `${sameAgain === 0 ? "" : `, and ${sameAgain} of a round's that were the season's again`}.`,
  );
  for (const { carNumber, was, now } of changed) {
    const one = (livery) =>
      livery === undefined
        ? "nothing"
        : typeof livery === "string"
          ? livery
          : `${livery.default} and ${Object.keys(livery.rounds).join(", ")}`;
    console.log(`  #${carNumber}  ${was === undefined ? one(now) : `${one(was)} -> ${one(now)}`}`);
  }
  if (changed.length === 0) console.log("  The table already said all of it.");

  for (const { name, why } of skipped) console.log(`\nNot asked for ${name}: ${why}.`);

  // A photograph the table stopped naming is left where it is: it may be one
  // this run could not see, and throwing it away is not this to do.
  const named = new Set([...filesIn(liveries)].map(kept));
  const onDisk = existsSync(imageDir) ? await readdir(imageDir) : [];
  const spare = onDisk.filter((file) => !named.has(file));
  if (spare.length > 0) {
    console.log(`\n${say(spare.length, "file", "files")} here that ${source.path} does not name:`);
    for (const file of spare) console.log(`  ${file}`);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
