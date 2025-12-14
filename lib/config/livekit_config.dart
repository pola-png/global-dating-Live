class LiveKitConfig {
  // LiveKit WebSocket URL (safe to ship in the app).
  static const String wsUrl =
      'wss://global-dating-d3im4k9p.livekit.cloud';

  // Backend endpoint that returns a short‑lived LiveKit token.
  // Implement this as a Netlify function or API:
  // POST { roomName, identity, isHost } -> { token: "..." }
  static const String tokenEndpoint =
      'https://www.globaldatingchat.online/.netlify/functions/livekit-token';
}

