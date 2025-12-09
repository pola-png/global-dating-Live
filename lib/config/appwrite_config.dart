class AppwriteConfig {
  // These can be overridden at build time using --dart-define for web/mobile.
  // Example:
  // flutter build web --release
  //   --dart-define=APPWRITE_ENDPOINT=https://nyc.cloud.appwrite.io/v1
  //   --dart-define=APPWRITE_PROJECT_ID=69384bc2002e7f635849
  static const String endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://nyc.cloud.appwrite.io/v1',
  );

  static const String projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '69384bc2002e7f635849',
  );
  static const String databaseId = '69384d3300376e805bf8';

  static const String profilesCollectionId = 'profiles';
  static const String postsCollectionId = 'posts';
  static const String messagesCollectionId = 'messages';
  static const String chatRoomsCollectionId = 'chatrooms';
  static const String liveStreamsCollectionId = 'livestreams';
  static const String groupMetadataCollectionId = 'groupmetadata';
  static const String blockedUsersCollectionId = 'blockedusers';
  static const String reportsCollectionId = 'reports';
  static const String supportSessionsCollectionId = 'supportsessions';

  static const String mediaBucketId = '6938589a0029a096b861';
}
