import 'package:appwrite/appwrite.dart';
import '../config/app_config.dart';

class NewsService {
  late Client client;
  late Databases databases;
  final String databaseId = 'news_db';
  final String collectionId = 'news_articles';

  NewsService() {
    client = Client()
      .setEndpoint(AppConfig.appwriteEndpoint)
      .setProject(AppConfig.appwriteProjectId);
    
    databases = Databases(client);
  }

  Future<dynamic> createArticle(Map<String, dynamic> article) async {
    return await databases.createDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: ID.unique(),
      data: article,
    );
  }

  Future<dynamic> getArticles({int limit = 20, int offset = 0}) async {
    return await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [
        Query.orderDesc('publishedDate'),
        Query.limit(limit),
        Query.offset(offset)
      ],
    );
  }

  Future<dynamic> getArticlesByCategory(String category, {int limit = 20}) async {
    return await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [
        Query.equal('category', category),
        Query.orderDesc('publishedDate'),
        Query.limit(limit)
      ],
    );
  }

  Future<dynamic> getTrendingArticles({int limit = 10}) async {
    return await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [
        Query.orderDesc('trafficScore'),
        Query.limit(limit)
      ],
    );
  }

  Future<dynamic> getArticleBySlug(String slug) async {
    final result = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [Query.equal('slug', slug)],
    );
    return result.documents.isNotEmpty ? result.documents[0] : null;
  }
}