'use client';

import { useSubscription } from '@apollo/client/react';
import { gql } from '@apollo/client';
import { useState, useEffect } from 'react';

const TIMING_SUBSCRIPTION = gql`
  subscription TimingUpdated($raceId: ID!) {
    timingUpdated(raceId: $raceId) {
      raceId
      laps
      timeElapsed
      timeRemaining
      flagStatus
      positions {
        position
        entryId
        number
        class
        team
        currentDriver {
          firstName
          lastName
          shortName
          countryCode
        }
        lapsCompleted
        lastLapTime
        bestLapTime
        sector1
        sector2
        sector3
        gapToLeader
        gapToAhead
        intervalToAhead
        pitStops
        inPit
        crossing
        lastPitTime
        lastPitDuration
        stintLaps
        tireCompound
      }
    }
  }
`;

interface TimingTableProps {
  raceId: string;
}

export default function TimingTable({ raceId }: TimingTableProps) {
  const { data, loading, error } = useSubscription(TIMING_SUBSCRIPTION, {
    variables: { raceId },
  });

  const [highlightedRows, setHighlightedRows] = useState<Set<string>>(new Set());

  // Highlight rows when position changes
  useEffect(() => {
    if (data?.timingUpdated?.positions) {
      const newHighlights = new Set<string>();
      data.timingUpdated.positions.forEach((pos: any) => {
        if (pos.crossing !== 'NONE') {
          newHighlights.add(pos.entryId);
        }
      });
      setHighlightedRows(newHighlights);

      // Clear highlights after 2 seconds
      if (newHighlights.size > 0) {
        setTimeout(() => setHighlightedRows(new Set()), 2000);
      }
    }
  }, [data]);

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

  const timingData = data?.timingUpdated;

  return (
    <div className="timing-table">
      {/* Race Header */}
      <div className="bg-gray-900 border-b border-gray-800 p-4 flex justify-between items-center sticky top-0 z-10">
        <div className="flex items-center space-x-6">
          <div className="flex items-center space-x-2">
            <span className="live-indicator w-3 h-3 bg-red-600 rounded-full"></span>
            <span className="text-red-600 font-bold uppercase text-sm">Live</span>
          </div>
          <div className="text-sm text-gray-400">
            Lap <span className="text-white font-bold">{timingData?.laps || 0}</span>
          </div>
          <div className="text-sm text-gray-400">
            Elapsed: <span className="text-white font-mono">{timingData?.timeElapsed || '0:00:00'}</span>
          </div>
          <div className="text-sm text-gray-400">
            Remaining: <span className="text-white font-mono">{timingData?.timeRemaining || '0:00:00'}</span>
          </div>
        </div>
        <div className="flex items-center space-x-2">
          <div className={`px-3 py-1 rounded text-sm font-bold ${
            timingData?.flagStatus === 'RACING' ? 'bg-green-600' :
            timingData?.flagStatus === 'YELLOW_FLAG' ? 'bg-yellow-500 text-black' :
            timingData?.flagStatus === 'RED_FLAG' ? 'bg-red-600' :
            'bg-gray-600'
          }`}>
            {timingData?.flagStatus?.replace(/_/g, ' ') || 'UNKNOWN'}
          </div>
        </div>
      </div>

      {/* Timing Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-900 border-b border-gray-800 sticky top-16 z-10">
            <tr className="text-left text-gray-400 uppercase text-xs">
              <th className="p-3 font-semibold">Pos</th>
              <th className="p-3 font-semibold">No</th>
              <th className="p-3 font-semibold">Class</th>
              <th className="p-3 font-semibold">Team</th>
              <th className="p-3 font-semibold">Driver</th>
              <th className="p-3 font-semibold text-right">Laps</th>
              <th className="p-3 font-semibold text-right">Last Lap</th>
              <th className="p-3 font-semibold text-right">Best Lap</th>
              <th className="p-3 font-semibold text-right">S1</th>
              <th className="p-3 font-semibold text-right">S2</th>
              <th className="p-3 font-semibold text-right">S3</th>
              <th className="p-3 font-semibold text-right">Gap</th>
              <th className="p-3 font-semibold text-right">Int</th>
              <th className="p-3 font-semibold text-center">Pits</th>
              <th className="p-3 font-semibold text-center">Status</th>
            </tr>
          </thead>
          <tbody>
            {timingData?.positions?.map((position: any) => (
              <tr
                key={position.entryId}
                className={`timing-row border-b border-gray-800 ${
                  highlightedRows.has(position.entryId) ? 'bg-blue-900/30' : ''
                } ${position.inPit ? 'bg-yellow-900/20' : ''}`}
              >
                <td className="p-3 font-bold text-lg">{position.position}</td>
                <td className="p-3">
                  <div className="flex items-center space-x-2">
                    <span className={`font-bold text-lg ${
                      position.class === 'HYPERCAR' ? 'text-red-500' :
                      position.class === 'LMP2' ? 'text-blue-500' :
                      position.class === 'LMGT3' ? 'text-green-500' :
                      'text-gray-400'
                    }`}>
                      {position.number}
                    </span>
                  </div>
                </td>
                <td className="p-3">
                  <span className={`px-2 py-1 rounded text-xs font-bold ${
                    position.class === 'HYPERCAR' ? 'bg-red-900 text-red-200' :
                    position.class === 'LMP2' ? 'bg-blue-900 text-blue-200' :
                    position.class === 'LMGT3' ? 'bg-green-900 text-green-200' :
                    'bg-gray-700 text-gray-300'
                  }`}>
                    {position.class}
                  </span>
                </td>
                <td className="p-3 text-gray-300">{position.team}</td>
                <td className="p-3">
                  <div className="flex items-center space-x-2">
                    <img
                      src={`https://flagsapi.com/${position.currentDriver.countryCode}/flat/24.png`}
                      alt={position.currentDriver.countryCode}
                      className="w-6 h-4 object-cover rounded"
                    />
                    <span className="font-medium">
                      {position.currentDriver.shortName ||
                       `${position.currentDriver.firstName[0]}. ${position.currentDriver.lastName}`}
                    </span>
                  </div>
                </td>
                <td className="p-3 text-right font-mono">{position.lapsCompleted}</td>
                <td className="p-3 text-right font-mono text-gray-300">{position.lastLapTime || '-'}</td>
                <td className="p-3 text-right font-mono text-purple-400 font-bold">
                  {position.bestLapTime || '-'}
                </td>
                <td className="p-3 text-right font-mono text-sm text-gray-400">{position.sector1 || '-'}</td>
                <td className="p-3 text-right font-mono text-sm text-gray-400">{position.sector2 || '-'}</td>
                <td className="p-3 text-right font-mono text-sm text-gray-400">{position.sector3 || '-'}</td>
                <td className="p-3 text-right font-mono text-gray-300">{position.gapToLeader || '-'}</td>
                <td className="p-3 text-right font-mono text-gray-400">{position.intervalToAhead || '-'}</td>
                <td className="p-3 text-center font-mono">{position.pitStops}</td>
                <td className="p-3 text-center">
                  {position.inPit && (
                    <span className="px-2 py-1 bg-yellow-600 text-black rounded text-xs font-bold">
                      PIT
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
