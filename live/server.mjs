/**
 * Standalone GraphQL Mock Server for WEC Live Timing
 * FULLY MATCHED TO OFFICIAL WEC API STRUCTURE
 * Run with: node server.mjs
 */

import { createServer } from 'node:http';
import { WebSocketServer } from 'ws';
import { useServer } from 'graphql-ws/use/ws';
import { createYoga } from 'graphql-yoga';
import { makeExecutableSchema } from '@graphql-tools/schema';

// Mock data - Drivers
const mockDrivers = [
  { firstName: 'Antonio', lastName: 'Fuoco' },
  { firstName: 'Miguel', lastName: 'Molina' },
  { firstName: 'Nicklas', lastName: 'Nielsen' },
  { firstName: 'Kamui', lastName: 'Kobayashi' },
  { firstName: 'Nyck', lastName: 'de Vries' },
  { firstName: 'Jose Maria', lastName: 'Lopez' },
  { firstName: 'Kevin', lastName: 'Estre' },
  { firstName: 'Andre', lastName: 'Lotterer' },
  { firstName: 'Laurens', lastName: 'Vanthoor' },
  { firstName: 'Paul-Loup', lastName: 'Chatin' },
  { firstName: 'Ferdinand', lastName: 'Habsburg' },
  { firstName: 'Charles', lastName: 'Milesi' },
  { firstName: 'James', lastName: 'Calado' },
  { firstName: 'Ross', lastName: 'Gunn' },
];

// Mock data - Categories
const hypercarCategory = { id: '4167', color: '#e21e19', __typename: 'Category' };
const lmgt3Category = { id: '4183', color: '#009639', __typename: 'Category' };

// Helper: Convert MM:SS.mmm to milliseconds
const timeToMs = (timeStr) => {
  const [mins, secs] = timeStr.split(':');
  return parseInt(mins) * 60000 + parseFloat(secs) * 1000;
};

// Helper: Convert milliseconds to MM:SS.mmm
const msToTime = (ms) => {
  const mins = Math.floor(ms / 60000);
  const secs = ((ms % 60000) / 1000).toFixed(3);
  return `${mins}:${secs.padStart(6, '0')}`;
};

// Base participants data
const baseParticipants = [
  {
    id: '105427',
    number: '7',
    position: 1,
    positionInCategory: 1,
    completeLapsCount: 152,
    pitStopCount: 5,
    bestTopSpeedKMH: 282.92,
    driver: mockDrivers[3],
    category: hypercarCategory,
    status: 'OnTrack',
    isOut: false,
    hasSeenCheckeredFlag: false,
    bestLapMs: timeToMs('1:51.517'),
    lastLapMs: timeToMs('1:54.225'),
    sector1Ms: timeToMs('0:36.156'),
    sector2Ms: timeToMs('0:42.475'),
    sector3Ms: timeToMs('0:35.594'),
  },
  {
    id: '105443',
    number: '51',
    position: 2,
    positionInCategory: 2,
    completeLapsCount: 152,
    pitStopCount: 5,
    bestTopSpeedKMH: 282.19,
    driver: mockDrivers[12],
    category: hypercarCategory,
    status: 'OnTrack',
    isOut: false,
    hasSeenCheckeredFlag: false,
    bestLapMs: timeToMs('1:52.612'),
    lastLapMs: timeToMs('1:52.783'),
    sector1Ms: timeToMs('0:35.748'),
    sector2Ms: timeToMs('0:41.866'),
    sector3Ms: timeToMs('0:35.169'),
  },
  {
    id: '105426',
    number: '007',
    position: 3,
    positionInCategory: 3,
    completeLapsCount: 152,
    pitStopCount: 4,
    bestTopSpeedKMH: 279.28,
    driver: mockDrivers[13],
    category: hypercarCategory,
    status: 'OnTrack',
    isOut: false,
    hasSeenCheckeredFlag: false,
    bestLapMs: timeToMs('1:52.176'),
    lastLapMs: timeToMs('1:54.407'),
    sector1Ms: timeToMs('0:35.958'),
    sector2Ms: timeToMs('0:42.621'),
    sector3Ms: timeToMs('0:35.828'),
  },
  {
    id: '105442',
    number: '50',
    position: 4,
    positionInCategory: 4,
    completeLapsCount: 151,
    pitStopCount: 6,
    bestTopSpeedKMH: 280.00,
    driver: mockDrivers[0],
    category: hypercarCategory,
    status: 'OnTrack',
    isOut: false,
    hasSeenCheckeredFlag: false,
    bestLapMs: timeToMs('1:52.164'),
    lastLapMs: timeToMs('1:54.312'),
    sector1Ms: timeToMs('0:35.650'),
    sector2Ms: timeToMs('0:42.150'),
    sector3Ms: timeToMs('0:34.512'),
  },
];

let currentLap = 152;
let sessionStartTime = Date.now() - (152 * 115000); // Approx 152 laps at ~115s each
const sessionDuration = 28800; // 8 hours in seconds

// GraphQL Type Definitions - MATCHED TO OFFICIAL WEC API
const typeDefs = `
  type Query {
    session(id: ID!): Session
  }

  type Subscription {
    session(sessionId: ID!): Session!
  }

  type Session {
    id: ID!
    chronoType: String!
    participants: [SessionParticipant!]!
    weather: Weather!
    closed: Boolean!
    liveStatus: SessionStatus!
    sectorFlags: [SectorFlagDetail!]!
    startsAt: String!
    duration: Int!
  }

  type SessionParticipant {
    id: ID!
    number: String!
    position: Int!
    positionInCategory: Int!
    completeLapsCount: Int!
    pitStopCount: Int!
    bestTopSpeedKMH: Float!
    driver: Driver!
    category: Category!
    status: ParticipantStatus!
    isOut: Boolean!
    hasSeenCheckeredFlag: Boolean!
    bestLap: Timing!
    lastLap: Timing!
    lastCompletedSectors: [CompleteSector!]!
    previousParticipantGap: DiffGap!
  }

  type Driver {
    firstName: String!
    lastName: String!
  }

  type Category {
    id: ID!
    color: String!
  }

  enum ParticipantStatus {
    OnTrack
    InBox
    StoppedOnTrack
  }

  type Timing {
    timeMilliseconds: Int!
    state: TimingState!
  }

  enum TimingState {
    Neutral
    PersonalBest
    OverallBest
    Invalid
  }

  type CompleteSector {
    lapTime: Int!
    state: TimingState!
  }

  type DiffGap {
    type: GapType!
    lapDifference: Int
    timeMilliseconds: Int
  }

  enum GapType {
    InLapTiming
    Laps
  }

  type Weather {
    ambientTemperatureEx: Temperature!
    trackTemperatureEx: Temperature!
    humidityPercent: Int!
  }

  type Temperature {
    celsiusDegrees: Float!
  }

  type SessionStatus {
    currentFlag: Flag!
    isSessionRunning: Boolean!
    stoppedSeconds: Int!
    sessionStartTime: Float!
    finalDurationSeconds: Int!
  }

  type Flag {
    type: FlagType!
  }

  enum FlagType {
    Green
    Yellow
    Red
    SafetyCar
    VirtualSafetyCar
  }

  type SectorFlagDetail {
    sector: Int!
    type: FlagType!
  }
`;

// GraphQL Resolvers
const resolvers = {
  Query: {
    session: (_, { id }) => ({
      id,
      chronoType: 'RACE',
      closed: false,
      startsAt: new Date(sessionStartTime).toISOString(),
      duration: sessionDuration,
    }),
  },
  Subscription: {
    session: {
      subscribe: async function* (_, { sessionId }) {
        while (true) {
          await new Promise(resolve => setTimeout(resolve, 1000));

          // Update participants with small variations
          const participants = baseParticipants.map((p, idx) => {
            const variation = (Math.random() - 0.5) * 2000; // ±2 seconds
            const newLastLapMs = p.lastLapMs + variation;

            // Randomly update sector times
            const s1 = p.sector1Ms + (Math.random() - 0.5) * 500;
            const s2 = p.sector2Ms + (Math.random() - 0.5) * 500;
            const s3 = p.sector3Ms + (Math.random() - 0.5) * 500;

            // Determine timing states
            const lastLapState = newLastLapMs < p.bestLapMs ? 'PersonalBest' : 'Neutral';
            const isOverallBest = idx === 0 && newLastLapMs < 111000;

            // Calculate gap to previous participant
            let previousGap;
            if (idx === 0) {
              previousGap = {
                type: 'InLapTiming',
                lapDifference: null,
                timeMilliseconds: 0,
                __typename: 'DiffGap'
              };
            } else {
              const lapDiff = baseParticipants[0].completeLapsCount - p.completeLapsCount;
              if (lapDiff > 0) {
                previousGap = {
                  type: 'Laps',
                  lapDifference: lapDiff,
                  timeMilliseconds: null,
                  __typename: 'DiffGap'
                };
              } else {
                previousGap = {
                  type: 'InLapTiming',
                  lapDifference: null,
                  timeMilliseconds: Math.floor((idx + 1) * 25000 + Math.random() * 5000),
                  __typename: 'DiffGap'
                };
              }
            }

            return {
              ...p,
              __typename: 'SessionParticipant',
              driver: {
                ...p.driver,
                __typename: 'Driver'
              },
              bestLap: {
                timeMilliseconds: Math.floor(p.bestLapMs),
                state: isOverallBest ? 'OverallBest' : 'Neutral',
                __typename: 'Timing'
              },
              lastLap: {
                timeMilliseconds: Math.floor(newLastLapMs),
                state: lastLapState,
                __typename: 'Timing'
              },
              lastCompletedSectors: [
                { lapTime: Math.floor(s1), state: 'Neutral', __typename: 'CompleteSector' },
                { lapTime: Math.floor(s2), state: 'Neutral', __typename: 'CompleteSector' },
                { lapTime: Math.floor(s3), state: s3 < p.sector3Ms ? 'PersonalBest' : 'Neutral', __typename: 'CompleteSector' },
              ],
              previousParticipantGap: previousGap,
            };
          });

          // Increment lap occasionally
          if (Math.random() < 0.05) {
            currentLap++;
          }

          const elapsedSeconds = Math.floor((Date.now() - sessionStartTime) / 1000);

          yield {
            session: {
              id: sessionId,
              __typename: 'Session',
              chronoType: 'RACE',
              participants,
              weather: {
                ambientTemperatureEx: {
                  celsiusDegrees: 25.9,
                  __typename: 'Temperature'
                },
                trackTemperatureEx: {
                  celsiusDegrees: 27.0,
                  __typename: 'Temperature'
                },
                humidityPercent: 61,
                __typename: 'Weather'
              },
              closed: false,
              liveStatus: {
                currentFlag: {
                  type: 'Green',
                  __typename: 'Flag'
                },
                isSessionRunning: true,
                stoppedSeconds: 0,
                sessionStartTime: sessionStartTime,
                finalDurationSeconds: sessionDuration,
                __typename: 'SessionStatus'
              },
              sectorFlags: [
                { sector: 1, type: 'Green', __typename: 'SectorFlagDetail' },
                { sector: 2, type: 'Green', __typename: 'SectorFlagDetail' },
                { sector: 3, type: 'Green', __typename: 'SectorFlagDetail' },
              ],
              startsAt: new Date(sessionStartTime).toISOString(),
              duration: sessionDuration,
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
  console.log(`🔴 Official API structure - FULLY MATCHED`);
  console.log(`   WebSocket endpoint: ws://localhost:${port}/graphql`);
  console.log(`\n📋 Use this subscription:`);
  console.log(`   subscription { sessionUpdated(sessionId: "7606") { id participants { number position driver { firstName lastName } } } }`);
});
