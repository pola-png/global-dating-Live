import { Client, Databases } from 'node-appwrite';

// Appwrite setup
const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = 'news_db';
const COLLECTION_ID = 'news_articles';

export default async function handler(req, res) {
    try {
        // Fetch published articles from Appwrite database
        const response = await databases.listDocuments(
            DATABASE_ID,
            COLLECTION_ID,
            [
                'publishedDate:desc',
                'limit(50)'
            ]
        );
        
        const articles = response.documents.map(doc => ({
            title: doc.title,
            description: doc.content,
            link: `/news/${doc.slug}`,
            publishedAt: doc.publishedDate,
            category: doc.category,
            source: 'Global Dating Chat News',
            image: doc.imageUrl,
            trafficScore: doc.trafficScore || 50
        }));
        
        res.status(200).json({ 
            articles: articles,
            count: articles.length
        });
        
    } catch (error) {
        res.status(500).json({ 
            error: 'Failed to fetch news',
            articles: [],
            count: 0
        });
    }
}