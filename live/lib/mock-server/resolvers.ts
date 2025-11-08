/**
 * GraphQL Resolvers for Mock WEC API
 */

import { mockChampionships, mockRaces, mockEntries } from './mock-data';

// Simulate real-time updates
let currentLap = 58;
let raceTime = 12255; // seconds

export const resolvers = {
  Query: {
    championships: () => {
      return mockChampionships.map(champ => ({
        ...champ,
        races: champ.races.map(raceId => mockRaces[raceId as keyof typeof mockRaces]),
      }));
    },

    championship: (_: any, { id }: { id: string }) => {
      const champ = mockChampionships.find(c => c.id === id);
      if (!champ) return null;
      return {
        ...champ,
        races: champ.races.map(raceId => mockRaces[raceId as keyof typeof mockRaces]),
      };
    },

    race: (_: any, { id }: { id: string }) => {
      return mockRaces[id as keyof typeof mockRaces] || null;
    },

    liveRace: () => {
      return mockRaces['qatar-2025'];
    },
  },

  Subscription: {
    timingUpdated: {
      subscribe: async function* (_: any, { raceId }: { raceId: string }) {
        // Simulate real-time updates every 1 second
        while (true) {
          await new Promise(resolve => setTimeout(resolve, 1000));

          const race = mockRaces[raceId as keyof typeof mockRaces];
          if (!race) continue;

          // Update timing data
          raceTime += 1;
          const positions = race.timingData.positions.map((pos, idx) => {
            // Simulate lap time variations
            const baseTime = 108.5 + (idx * 0.3); // Base lap time in seconds
            const variation = (Math.random() - 0.5) * 0.5; // Random variation
            const newLapTime = baseTime + variation;

            const formatTime = (seconds: number) => {
              const mins = Math.floor(seconds / 60);
              const secs = (seconds % 60).toFixed(3);
              return `${mins}:${secs.padStart(6, '0')}`;
            };

            // Randomly simulate pit stops (1% chance per update)
            const enteringPit = Math.random() < 0.01;
            const isCurrentlyInPit = pos.inPit;

            return {
              ...pos,
              lastLapTime: formatTime(newLapTime),
              sector1: formatTime(newLapTime * 0.3),
              sector2: formatTime(newLapTime * 0.38),
              sector3: formatTime(newLapTime * 0.32),
              inPit: isCurrentlyInPit ? Math.random() > 0.3 : enteringPit, // Exit pit with 70% chance
              crossing: isCurrentlyInPit ? 'CROSSING_FINISH_LINE_IN_PIT' as const : 'NONE' as const,
              stintLaps: isCurrentlyInPit ? 0 : (pos.stintLaps || 0) + 1,
            };
          });

          yield {
            timingUpdated: {
              raceId,
              laps: currentLap,
              timeElapsed: formatRaceTime(raceTime),
              timeRemaining: formatRaceTime(21600 - raceTime), // 6 hours race
              flagStatus: 'RACING',
              positions,
            },
          };

          // Increment lap every ~110 seconds (average lap time)
          if (raceTime % 110 === 0) {
            currentLap++;
          }
        }
      },
    },

    raceUpdated: {
      subscribe: async function* (_: any, { raceId }: { raceId: string }) {
        while (true) {
          await new Promise(resolve => setTimeout(resolve, 5000));
          const race = mockRaces[raceId as keyof typeof mockRaces];
          if (race) {
            yield { raceUpdated: race };
          }
        }
      },
    },
  },
};

function formatRaceTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}
