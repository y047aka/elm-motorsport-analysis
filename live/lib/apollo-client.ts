/**
 * Apollo Client Configuration for WEC Live Timing
 * Supports both client-side and server-side rendering
 */

import { ApolloClient, InMemoryCache, HttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';
import { createClient } from 'graphql-ws';

const isServer = typeof window === 'undefined';

// HTTP connection to the API
const httpLink = new HttpLink({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_ENDPOINT || 'http://localhost:4000/graphql',
  // Use fetch from global scope for server-side
  fetch: isServer ? fetch : undefined,
});

// WebSocket link for subscriptions (client-side only)
const wsLink = !isServer
  ? new GraphQLWsLink(
      createClient({
        url: process.env.NEXT_PUBLIC_GRAPHQL_WS_ENDPOINT || 'ws://localhost:4000/graphql',
        webSocketImpl: typeof window !== 'undefined' ? WebSocket : undefined,
      })
    )
  : null;

// Split link: use WS for subscriptions, HTTP for queries/mutations
const splitLink = !isServer && wsLink
  ? split(
      ({ query }) => {
        const definition = getMainDefinition(query);
        return (
          definition.kind === 'OperationDefinition' &&
          definition.operation === 'subscription'
        );
      },
      wsLink,
      httpLink
    )
  : httpLink;

// Create Apollo Client
export function createApolloClient() {
  return new ApolloClient({
    link: splitLink,
    cache: new InMemoryCache({
      typePolicies: {
        Query: {
          fields: {
            session: {
              merge: true,
            },
          },
        },
        Session: {
          merge: true,
        },
        SessionParticipant: {
          keyFields: ['id'],
        },
      },
    }),
    ssrMode: isServer,
    // Cache configuration matching WEC official (3600s revalidation)
    defaultOptions: {
      watchQuery: {
        fetchPolicy: 'cache-first',
        nextFetchPolicy: 'cache-first',
      },
      query: {
        fetchPolicy: 'cache-first',
      },
    },
  });
}

// Singleton client for client-side
let apolloClient: ApolloClient<any> | null = null;

export function getApolloClient() {
  if (isServer) {
    // Always create a new client for SSR
    return createApolloClient();
  }

  // Reuse client on the client-side
  if (!apolloClient) {
    apolloClient = createApolloClient();
  }

  return apolloClient;
}
