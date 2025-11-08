#!/usr/bin/env node

/**
 * Mock Live Timing WebSocket Server
 *
 * This server reads existing JSON race data and streams it in real-time
 * to simulate live timing updates for development and testing.
 *
 * Usage:
 *   node tools/mock-live-timing-server.js [options]
 *
 * Options:
 *   --port <number>      WebSocket server port (default: 8080)
 *   --speed <number>     Playback speed multiplier (default: 10)
 *   --file <path>        Path to race JSON file (required)
 *   --laps-file <path>   Path to laps JSON file (optional)
 */

const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  port: 8080,
  speed: 10,
  file: null,
  lapsFile: null,
};

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--port':
      options.port = parseInt(args[++i], 10);
      break;
    case '--speed':
      options.speed = parseFloat(args[++i]);
      break;
    case '--file':
      options.file = args[++i];
      break;
    case '--laps-file':
      options.lapsFile = args[++i];
      break;
    case '--help':
    case '-h':
      console.log(`
Mock Live Timing WebSocket Server

Usage: node tools/mock-live-timing-server.js [options]

Options:
  --port <number>      WebSocket server port (default: 8080)
  --speed <number>     Playback speed multiplier (default: 10)
  --file <path>        Path to race JSON file (required)
  --laps-file <path>   Path to laps JSON file (optional)
  --help, -h           Show this help message

Examples:
  node tools/mock-live-timing-server.js \\
    --file app/static/wec/2025/qatar.json \\
    --laps-file app/static/wec/2025/qatar_laps.json \\
    --speed 20
      `);
      process.exit(0);
  }
}

if (!options.file) {
  console.error('Error: --file option is required');
  console.error('Use --help for usage information');
  process.exit(1);
}

// Load race data
console.log(`Loading race data from: ${options.file}`);
const raceData = JSON.parse(fs.readFileSync(options.file, 'utf8'));

let lapsData = null;
if (options.lapsFile && fs.existsSync(options.lapsFile)) {
  console.log(`Loading laps data from: ${options.lapsFile}`);
  lapsData = JSON.parse(fs.readFileSync(options.lapsFile, 'utf8'));
}

console.log(`Race: ${raceData.name}`);
console.log(`Starting grid: ${raceData.startingGrid.length} cars`);
console.log(`Timeline events: ${raceData.timelineEvents.length} events`);

// Create WebSocket server
const wss = new WebSocket.Server({ port: options.port });

console.log(`\n🏁 Mock Live Timing Server started on ws://localhost:${options.port}`);
console.log(`Playback speed: ${options.speed}x`);
console.log(`Waiting for connections...\n`);

wss.on('connection', (ws) => {
  console.log('✅ Client connected');

  let currentEventIndex = 0;
  let intervalId = null;
  let lastEventTime = 0;

  // Send initial starting grid
  const initialMessage = {
    timestamp: Date.now(),
    raceTime: "00:00:00.000",
    updatedCars: raceData.startingGrid.map((item, index) => ({
      carNumber: item.car.carNumber,
      position: index + 1,
      gap: index === 0 ? null : "Gap",
      interval: index === 0 ? null : "Interval",
      inPit: false,
    })),
    newEvents: [raceData.timelineEvents[0]], // RaceStart event
  };

  ws.send(JSON.stringify(initialMessage));
  console.log('📤 Sent initial data (starting grid)');

  currentEventIndex = 1;

  // Stream timeline events
  const streamEvents = () => {
    if (currentEventIndex >= raceData.timelineEvents.length) {
      console.log('🏁 Race finished, all events sent');
      if (intervalId) {
        clearInterval(intervalId);
      }
      return;
    }

    const event = raceData.timelineEvents[currentEventIndex];
    const eventTime = parseDuration(event.event_time);

    // Calculate delay based on time difference and speed multiplier
    const timeDiff = eventTime - lastEventTime;
    const delay = timeDiff / options.speed;

    setTimeout(() => {
      if (ws.readyState === WebSocket.OPEN) {
        const message = {
          timestamp: Date.now(),
          raceTime: event.event_time,
          updatedCars: extractCarUpdates(event),
          newEvents: [event],
        };

        ws.send(JSON.stringify(message));
        console.log(`📤 Event ${currentEventIndex}/${raceData.timelineEvents.length}: ${event.event_time} - ${JSON.stringify(event.event_type).substring(0, 50)}...`);

        lastEventTime = eventTime;
        currentEventIndex++;
        streamEvents();
      }
    }, Math.max(delay, 100)); // Minimum 100ms between events
  };

  // Start streaming
  streamEvents();

  ws.on('close', () => {
    console.log('❌ Client disconnected');
    if (intervalId) {
      clearInterval(intervalId);
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Helper: Parse duration string "HH:MM:SS.mmm" to milliseconds
function parseDuration(duration) {
  const parts = duration.split(':');
  const hours = parseInt(parts[0], 10);
  const minutes = parseInt(parts[1], 10);
  const seconds = parseFloat(parts[2]);
  return (hours * 3600 + minutes * 60 + seconds) * 1000;
}

// Helper: Extract car updates from timeline event
function extractCarUpdates(event) {
  const updates = [];

  // Check if this is a CarEvent
  if (event.event_type.CarEvent) {
    const [carNumber, carEventType] = event.event_type.CarEvent;

    const update = {
      carNumber: carNumber,
    };

    // Extract lap information based on event type
    if (carEventType.Start && carEventType.Start.currentLap) {
      update.currentLap = carEventType.Start.currentLap;
    } else if (carEventType.LapCompleted) {
      const [lapNumber, lapData] = carEventType.LapCompleted;
      if (lapData.nextLap) {
        update.currentLap = lapData.nextLap;
        update.lastCompletedLap = lapData.nextLap; // Simplified
      }
    }

    updates.push(update);
  }

  return updates;
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n\n🛑 Shutting down server...');
  wss.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
