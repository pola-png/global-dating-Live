import 'supabase_service.dart';

class NewsService {
  Future<dynamic> createArticle(Map<String, dynamic> article) async {
    return await SupabaseService.client.from('posts').insert(article).select().single();
  }

  Future<dynamic> getArticles({int limit = 20, int offset = 0}) async {
    final response = await SupabaseService.client
        .from('posts')
        .select('*')
        .order('published_date', ascending: false)
        .range(offset, offset + limit - 1);
    return {'documents': response};
  }

  Future<dynamic> getArticlesByCategory(String category, {int limit = 20}) async {
    final response = await SupabaseService.client
        .from('posts')
        .select('*')
        .eq('category', category)
        .order('published_date', ascending: false)
        .limit(limit);
    return {'documents': response};
  }

  Future<dynamic> getTrendingArticles({int limit = 10}) async {
    final response = await SupabaseService.client
        .from('posts')
        .select('*')
        .order('traffic_score', ascending: false)
        .limit(limit);
    return {'documents': response};
  }

  Future<dynamic> getArticleBySlug(String slug) async {
    final response = await SupabaseService.client
        .from('posts')
        .select('*')
        .eq('slug', slug)
        .maybeSingle();
    return response;
  }
}