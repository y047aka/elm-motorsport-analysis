/**
 * GraphQL Schema for WEC Live Timing
 * Based on the official WEC API structure (Sportall Platform)
 */

export const typeDefs = `
  type Query {
    championships: [Championship!]!
    championship(id: ID!): Championship
    race(id: ID!): Race
    liveRace: Race
  }

  type Subscription {
    raceUpdated(raceId: ID!): Race!
    timingUpdated(raceId: ID!): TimingData!
  }

  type Championship {
    id: ID!
    name: String!
    season: Int!
    logo: String
    races: [Race!]!
  }

  type Race {
    id: ID!
    name: String!
    championshipId: ID!
    circuit: Circuit!
    startTime: String!
    endTime: String
    status: RaceStatus!
    session: SessionType!
    entries: [Entry!]!
    timingData: TimingData!
  }

  type Circuit {
    id: ID!
    name: String!
    country: String!
    countryCode: String!
    length: Float!
  }

  enum RaceStatus {
    SCHEDULED
    PRACTICE
    QUALIFYING
    RACING
    FINISHED
    RED_FLAG
    YELLOW_FLAG
  }

  enum SessionType {
    FREE_PRACTICE_1
    FREE_PRACTICE_2
    FREE_PRACTICE_3
    QUALIFYING
    HYPERPOLE
    RACE
  }

  type Entry {
    id: ID!
    number: String!
    team: String!
    drivers: [Driver!]!
    class: String!
    manufacturer: String!
    car: String!
    currentDriver: Driver
  }

  type Driver {
    id: ID!
    firstName: String!
    lastName: String!
    shortName: String
    countryCode: String!
    category: DriverCategory!
  }

  enum DriverCategory {
    PLATINUM
    GOLD
    SILVER
    BRONZE
  }

  type TimingData {
    raceId: ID!
    positions: [Position!]!
    laps: Int!
    timeElapsed: String
    timeRemaining: String
    flagStatus: RaceStatus!
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
    crossing: CrossingStatus
    lastPitTime: String
    lastPitDuration: String
    stintLaps: Int
    tireCompound: String
  }

  enum CrossingStatus {
    NONE
    CROSSING_FINISH_LINE
    CROSSING_FINISH_LINE_IN_PIT
  }
`;
