'use client';

import { useSubscription } from '@apollo/client/react';
import { gql } from '@apollo/client';
import { useState, useEffect } from 'react';

// GraphQL Subscription - MATCHED TO OFFICIAL WEC API
const SESSION_SUBSCRIPTION = gql`
  subscription SessionUpdated($sessionId: ID!) {
    sessionUpdated(sessionId: $sessionId) {
      id
      chronoType
      closed
      startsAt
      duration
      weather {
        ambientTemperatureEx {
          celsiusDegrees
        }
        trackTemperatureEx {
          celsiusDegrees
        }
        humidityPercent
      }
      liveStatus {
        currentFlag {
          type
        }
        isSessionRunning
        stoppedSeconds
        sessionStartTime
        finalDurationSeconds
      }
      sectorFlags {
        sector
        type
      }
      participants {
        id
        number
        position
        positionInCategory
        completeLapsCount
        pitStopCount
        bestTopSpeedKMH
        driver {
          firstName
          lastName
        }
        category {
          id
          color
        }
        status
        isOut
        hasSeenCheckeredFlag
        bestLap {
          timeMilliseconds
          state
        }
        lastLap {
          timeMilliseconds
          state
        }
        lastCompletedSectors {
          lapTime
          state
        }
        previousParticipantGap {
          type
          lapDifference
          timeMilliseconds
        }
      }
    }
  }
`;

interface TimingTableProps {
  sessionId: string;
}

// Helper: Convert milliseconds to MM:SS.mmm
const msToTime = (ms: number): string => {
  const mins = Math.floor(ms / 60000);
  const secs = ((ms % 60000) / 1000).toFixed(3);
  return `${mins}:${secs.padStart(6, '0')}`;
};

// Helper: Format gap display
const formatGap = (gap: any): string => {
  if (gap.type === 'Laps') {
    return gap.lapDifference === 1 ? '+1 LAP' : `+${gap.lapDifference} LAPS`;
  } else if (gap.type === 'InLapTiming') {
    if (gap.timeMilliseconds === 0) return '-';
    return `+${msToTime(gap.timeMilliseconds)}`;
  }
  return '-';
};

// Helper: Format elapsed time from timestamp
const formatElapsedTime = (startTime: number): string => {
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const hours = Math.floor(elapsed / 3600);
  const mins = Math.floor((elapsed % 3600) / 60);
  const secs = elapsed % 60;
  return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
};

// Helper: Format remaining time
const formatRemainingTime = (startTime: number, duration: number): string => {
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const remaining = Math.max(0, duration - elapsed);
  const hours = Math.floor(remaining / 3600);
  const mins = Math.floor((remaining % 3600) / 60);
  const secs = remaining % 60;
  return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
};

// Helper: Get timing state color class
const getTimingStateClass = (state: string): string => {
  switch (state) {
    case 'OverallBest':
      return 'text-purple-400 font-bold';
    case 'PersonalBest':
      return 'text-green-400 font-bold';
    case 'Invalid':
      return 'text-gray-600';
    default:
      return 'text-gray-300';
  }
};

export default function TimingTable({ sessionId }: TimingTableProps) {
  const { data, loading, error } = useSubscription(SESSION_SUBSCRIPTION, {
    variables: { sessionId },
  });

  const [elapsedTime, setElapsedTime] = useState('0:00:00');
  const [remainingTime, setRemainingTime] = useState('0:00:00');
  const [currentLap, setCurrentLap] = useState(0);

  // Update time displays every second
  useEffect(() => {
    if (data?.sessionUpdated?.liveStatus) {
      const { sessionStartTime, finalDurationSeconds } = data.sessionUpdated.liveStatus;
      const interval = setInterval(() => {
        setElapsedTime(formatElapsedTime(sessionStartTime));
        setRemainingTime(formatRemainingTime(sessionStartTime, finalDurationSeconds));
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [data?.sessionUpdated?.liveStatus]);

  // Calculate current lap from participants
  useEffect(() => {
    if (data?.sessionUpdated?.participants && data.sessionUpdated.participants.length > 0) {
      const maxLaps = Math.max(...data.sessionUpdated.participants.map((p: any) => p.completeLapsCount || 0));
      setCurrentLap(maxLaps);
    }
  }, [data?.sessionUpdated?.participants]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl text-gray-400">Loading timing data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl text-red-500">Error: {error.message}</div>
      </div>
    );
  }

  const session = data?.sessionUpdated;
  const weather = session?.weather;
  const liveStatus = session?.liveStatus;

  return (
    <div className="timing-table">
      {/* Race Header */}
      <div className="bg-gray-900 border-b border-gray-800 p-4 flex justify-between items-center sticky top-0 z-10">
        <div className="flex items-center space-x-6">
          <div className="flex items-center space-x-2">
            {liveStatus?.isSessionRunning && (
              <>
                <span className="live-indicator w-3 h-3 bg-red-600 rounded-full"></span>
                <span className="text-red-600 font-bold uppercase text-sm">Live</span>
              </>
            )}
          </div>
          <div className="text-sm text-gray-400">
            Lap <span className="text-white font-bold">{currentLap}</span>
          </div>
          <div className="text-sm text-gray-400">
            Elapsed: <span className="text-white font-mono">{elapsedTime}</span>
          </div>
          <div className="text-sm text-gray-400">
            Remaining: <span className="text-white font-mono">{remainingTime}</span>
          </div>
          {weather && (
            <>
              <div className="text-sm text-gray-400">
                Air: <span className="text-white">{weather.ambientTemperatureEx.celsiusDegrees.toFixed(1)}°C</span>
              </div>
              <div className="text-sm text-gray-400">
                Track: <span className="text-white">{weather.trackTemperatureEx.celsiusDegrees.toFixed(1)}°C</span>
              </div>
            </>
          )}
        </div>
        <div className="flex items-center space-x-2">
          {liveStatus?.currentFlag && (
            <div className={`px-3 py-1 rounded text-sm font-bold ${
              liveStatus.currentFlag.type === 'Green' ? 'bg-green-600' :
              liveStatus.currentFlag.type === 'Yellow' ? 'bg-yellow-500 text-black' :
              liveStatus.currentFlag.type === 'Red' ? 'bg-red-600' :
              'bg-gray-600'
            }`}>
              {liveStatus.currentFlag.type.replace(/_/g, ' ')}
            </div>
          )}
        </div>
      </div>

      {/* Timing Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-900 border-b border-gray-800 sticky top-16 z-10">
            <tr className="text-left text-gray-400 uppercase text-xs">
              <th className="p-3 font-semibold">Pos</th>
              <th className="p-3 font-semibold">PiC</th>
              <th className="p-3 font-semibold">No</th>
              <th className="p-3 font-semibold">Driver</th>
              <th className="p-3 font-semibold text-right">Laps</th>
              <th className="p-3 font-semibold text-right">Last Lap</th>
              <th className="p-3 font-semibold text-right">Best Lap</th>
              <th className="p-3 font-semibold text-right">S1</th>
              <th className="p-3 font-semibold text-right">S2</th>
              <th className="p-3 font-semibold text-right">S3</th>
              <th className="p-3 font-semibold text-right">Gap</th>
              <th className="p-3 font-semibold text-center">Pits</th>
              <th className="p-3 font-semibold text-right">Top Speed</th>
              <th className="p-3 font-semibold text-center">Status</th>
            </tr>
          </thead>
          <tbody>
            {session?.participants?.map((participant: any) => (
              <tr
                key={participant.id}
                className={`timing-row border-b border-gray-800 ${
                  participant.status === 'InBox' ? 'bg-yellow-900/20' : ''
                } ${participant.isOut ? 'opacity-60' : ''}`}
              >
                <td className="p-3 font-bold text-lg">{participant.position}</td>
                <td className="p-3 text-gray-400">{participant.positionInCategory}</td>
                <td className="p-3">
                  <span
                    className="font-bold text-lg"
                    style={{ color: participant.category.color }}
                  >
                    {participant.number}
                  </span>
                </td>
                <td className="p-3">
                  <div className="font-medium">
                    {participant.driver.firstName} {participant.driver.lastName}
                  </div>
                </td>
                <td className="p-3 text-right font-mono">{participant.completeLapsCount}</td>
                <td className={`p-3 text-right font-mono ${getTimingStateClass(participant.lastLap.state)}`}>
                  {msToTime(participant.lastLap.timeMilliseconds)}
                </td>
                <td className={`p-3 text-right font-mono ${getTimingStateClass(participant.bestLap.state)}`}>
                  {msToTime(participant.bestLap.timeMilliseconds)}
                </td>
                <td className={`p-3 text-right font-mono text-sm ${
                  participant.lastCompletedSectors[0] ? getTimingStateClass(participant.lastCompletedSectors[0].state) : 'text-gray-400'
                }`}>
                  {participant.lastCompletedSectors[0] ? msToTime(participant.lastCompletedSectors[0].lapTime) : '-'}
                </td>
                <td className={`p-3 text-right font-mono text-sm ${
                  participant.lastCompletedSectors[1] ? getTimingStateClass(participant.lastCompletedSectors[1].state) : 'text-gray-400'
                }`}>
                  {participant.lastCompletedSectors[1] ? msToTime(participant.lastCompletedSectors[1].lapTime) : '-'}
                </td>
                <td className={`p-3 text-right font-mono text-sm ${
                  participant.lastCompletedSectors[2] ? getTimingStateClass(participant.lastCompletedSectors[2].state) : 'text-gray-400'
                }`}>
                  {participant.lastCompletedSectors[2] ? msToTime(participant.lastCompletedSectors[2].lapTime) : '-'}
                </td>
                <td className="p-3 text-right font-mono text-gray-300">
                  {formatGap(participant.previousParticipantGap)}
                </td>
                <td className="p-3 text-center font-mono">{participant.pitStopCount}</td>
                <td className="p-3 text-right font-mono text-sm text-gray-400">
                  {participant.bestTopSpeedKMH.toFixed(1)}
                </td>
                <td className="p-3 text-center">
                  {participant.status === 'InBox' && (
                    <span className="px-2 py-1 bg-yellow-600 text-black rounded text-xs font-bold">
                      PIT
                    </span>
                  )}
                  {participant.status === 'StoppedOnTrack' && (
                    <span className="px-2 py-1 bg-red-600 text-white rounded text-xs font-bold">
                      OUT
                    </span>
                  )}
                  {participant.isOut && (
                    <span className="px-2 py-1 bg-gray-700 text-gray-300 rounded text-xs font-bold">
                      DNF
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
