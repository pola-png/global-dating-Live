class LiveKitConfig {
  // LiveKit WebSocket URL (safe to ship in the app).
  static const String wsUrl =
      'wss://global-dating-d3im4k9p.livekit.cloud';

  // Appwrite function endpoint that returns a short‑lived LiveKit token.
  // Deploy this as an Appwrite function:
  // POST { roomName, identity, isHost } -> { token: "..." }
  static const String tokenEndpoint =
      'https://nyc.cloud.appwrite.io/v1/functions/livekit-token/executions';
}

