/**
 * Standalone GraphQL Mock Server for WEC Live Timing
 * Run with: node server.mjs
 */

import { createServer } from 'node:http';
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/use/ws';
import { createYoga } from 'graphql-yoga';
import { makeExecutableSchema } from '@graphql-tools/schema';

// Mock data
const mockDrivers = [
  { id: 'd1', firstName: 'Antonio', lastName: 'Fuoco', shortName: 'FUO', countryCode: 'IT', category: 'PLATINUM' },
  { id: 'd2', firstName: 'Miguel', lastName: 'Molina', shortName: 'MOL', countryCode: 'ES', category: 'GOLD' },
  { id: 'd3', firstName: 'Nicklas', lastName: 'Nielsen', shortName: 'NIE', countryCode: 'DK', category: 'GOLD' },
  { id: 'd4', firstName: 'Kamui', lastName: 'Kobayashi', shortName: 'KOB', countryCode: 'JP', category: 'PLATINUM' },
  { id: 'd5', firstName: 'Nyck', lastName: 'de Vries', shortName: 'DEV', countryCode: 'NL', category: 'PLATINUM' },
  { id: 'd6', firstName: 'Jose Maria', lastName: 'Lopez', shortName: 'LOP', countryCode: 'AR', category: 'PLATINUM' },
  { id: 'd7', firstName: 'Kevin', lastName: 'Estre', shortName: 'EST', countryCode: 'FR', category: 'PLATINUM' },
  { id: 'd8', firstName: 'Andre', lastName: 'Lotterer', shortName: 'LOT', countryCode: 'DE', category: 'PLATINUM' },
  { id: 'd9', firstName: 'Laurens', lastName: 'Vanthoor', shortName: 'VAN', countryCode: 'BE', category: 'PLATINUM' },
  { id: 'd10', firstName: 'Paul-Loup', lastName: 'Chatin', shortName: 'CHA', countryCode: 'FR', category: 'GOLD' },
  { id: 'd11', firstName: 'Ferdinand', lastName: 'Habsburg', shortName: 'HAB', countryCode: 'AT', category: 'GOLD' },
  { id: 'd12', firstName: 'Charles', lastName: 'Milesi', shortName: 'MIL', countryCode: 'FR', category: 'PLATINUM' },
];

const basePositions = [
  {
    position: 1,
    entryId: 'e50',
    number: '50',
    class: 'HYPERCAR',
    team: 'Ferrari AF Corse',
    currentDriver: mockDrivers[0],
    lapsCompleted: 58,
    lastLapTime: '1:48.234',
    bestLapTime: '1:47.892',
    sector1: '32.456',
    sector2: '41.234',
    sector3: '34.544',
    gapToLeader: '-',
    gapToAhead: '-',
    intervalToAhead: '-',
    pitStops: 2,
    inPit: false,
    crossing: 'NONE',
    lastPitTime: '1:23:45',
    lastPitDuration: '56.2',
    stintLaps: 18,
    tireCompound: 'SOFT',
  },
  {
    position: 2,
    entryId: 'e7',
    number: '7',
    class: 'HYPERCAR',
    team: 'Toyota Gazoo Racing',
    currentDriver: mockDrivers[3],
    lapsCompleted: 58,
    lastLapTime: '1:48.567',
    bestLapTime: '1:47.945',
    sector1: '32.567',
    sector2: '41.345',
    sector3: '34.655',
    gapToLeader: '+12.345',
    gapToAhead: '+12.345',
    intervalToAhead: '+12.345',
    pitStops: 2,
    inPit: false,
    crossing: 'NONE',
    lastPitTime: '1:25:12',
    lastPitDuration: '54.8',
    stintLaps: 17,
    tireCompound: 'SOFT',
  },
  {
    position: 3,
    entryId: 'e6',
    number: '6',
    class: 'HYPERCAR',
    team: 'Porsche Penske Motorsport',
    currentDriver: mockDrivers[6],
    lapsCompleted: 58,
    lastLapTime: '1:48.891',
    bestLapTime: '1:48.012',
    sector1: '32.678',
    sector2: '41.456',
    sector3: '34.757',
    gapToLeader: '+28.789',
    gapToAhead: '+16.444',
    intervalToAhead: '+16.444',
    pitStops: 2,
    inPit: false,
    crossing: 'NONE',
    lastPitTime: '1:26:34',
    lastPitDuration: '57.1',
    stintLaps: 16,
    tireCompound: 'MEDIUM',
  },
  {
    position: 4,
    entryId: 'e35',
    number: '35',
    class: 'HYPERCAR',
    team: 'Alpine Endurance Team',
    currentDriver: mockDrivers[9],
    lapsCompleted: 57,
    lastLapTime: '1:49.234',
    bestLapTime: '1:48.567',
    sector1: '32.890',
    sector2: '41.678',
    sector3: '34.890',
    gapToLeader: '+1 LAP',
    gapToAhead: '+1 LAP',
    intervalToAhead: '+1 LAP',
    pitStops: 3,
    inPit: false,
    crossing: 'NONE',
    lastPitTime: '0:45:23',
    lastPitDuration: '1:12.4',
    stintLaps: 12,
    tireCompound: 'SOFT',
  },
];

let currentLap = 58;
let raceTime = 12255;

const typeDefs = `
  type Query {
    liveRace: Race
  }

  type Subscription {
    timingUpdated(raceId: ID!): TimingData!
  }

  type Race {
    id: ID!
    name: String!
    status: String!
  }

  type TimingData {
    raceId: ID!
    laps: Int!
    timeElapsed: String
    timeRemaining: String
    flagStatus: String!
    positions: [Position!]!
  }

  type Position {
    position: Int!
    entryId: ID!
    number: String!
    class: String!
    team: String!
    currentDriver: Driver!
    lapsCompleted: Int!
    lastLapTime: String
    bestLapTime: String
    sector1: String
    sector2: String
    sector3: String
    gapToLeader: String
    gapToAhead: String
    intervalToAhead: String
    pitStops: Int!
    inPit: Boolean!
    crossing: String
    lastPitTime: String
    lastPitDuration: String
    stintLaps: Int
    tireCompound: String
  }

  type Driver {
    id: ID!
    firstName: String!
    lastName: String!
    shortName: String
    countryCode: String!
    category: String!
  }
`;

const formatTime = (seconds) => {
  const mins = Math.floor(seconds / 60);
  const secs = (seconds % 60).toFixed(3);
  return `${mins}:${secs.padStart(6, '0')}`;
};

const formatRaceTime = (seconds) => {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
};

const resolvers = {
  Query: {
    liveRace: () => ({
      id: 'qatar-2025',
      name: '1812km of Qatar',
      status: 'RACING',
    }),
  },
  Subscription: {
    timingUpdated: {
      subscribe: async function* (_, { raceId }) {
        while (true) {
          await new Promise(resolve => setTimeout(resolve, 1000));

          raceTime += 1;

          const positions = basePositions.map((pos, idx) => {
            const baseTime = 108.5 + (idx * 0.3);
            const variation = (Math.random() - 0.5) * 0.5;
            const newLapTime = baseTime + variation;

            const enteringPit = Math.random() < 0.01;
            const isCurrentlyInPit = pos.inPit;
            const newInPit = isCurrentlyInPit ? Math.random() > 0.3 : enteringPit;

            return {
              ...pos,
              lastLapTime: formatTime(newLapTime),
              sector1: formatTime(newLapTime * 0.3),
              sector2: formatTime(newLapTime * 0.38),
              sector3: formatTime(newLapTime * 0.32),
              inPit: newInPit,
              crossing: newInPit ? 'CROSSING_FINISH_LINE_IN_PIT' : 'NONE',
              stintLaps: newInPit ? 0 : (pos.stintLaps || 0) + 1,
            };
          });

          if (raceTime % 110 === 0) {
            currentLap++;
          }

          yield {
            timingUpdated: {
              raceId,
              laps: currentLap,
              timeElapsed: formatRaceTime(raceTime),
              timeRemaining: formatRaceTime(21600 - raceTime),
              flagStatus: 'RACING',
              positions,
            },
          };
        }
      },
    },
  },
};

const schema = makeExecutableSchema({
  typeDefs,
  resolvers,
});

const yoga = createYoga({
  schema,
  graphiql: true,
});

const httpServer = createServer(yoga);

// WebSocket server for subscriptions
const wsServer = new WebSocketServer({
  server: httpServer,
  path: '/graphql',
});

// Use graphql-ws for WebSocket subscriptions
useServer({ schema }, wsServer);

const port = 4000;
httpServer.listen(port, () => {
  console.log(`🏁 WEC Mock GraphQL Server running on http://localhost:${port}/graphql`);
  console.log(`🔴 Live timing updates available via WebSocket subscriptions`);
  console.log(`   WebSocket endpoint: ws://localhost:${port}/graphql`);
});
