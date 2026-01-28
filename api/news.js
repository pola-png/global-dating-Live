// Serve AI-generated news articles from Appwrite
import { Client, Databases } from 'node-appwrite';

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = 'news_db';
const COLLECTION_ID = 'news_articles';

export default async function handler(req, res) {
    try {
        const articles = await databases.listDocuments(
            DATABASE_ID,
            COLLECTION_ID,
            [
                // Get latest 20 articles, sorted by date
                { method: 'orderDesc', attribute: 'publishedDate' },
                { method: 'limit', value: 20 }
            ]
        );
        
        res.status(200).json({
            success: true,
            articles: articles.documents
        });
        
    } catch (error) {
        console.error('Error fetching articles:', error);
        res.status(500).json({ 
            error: 'Failed to fetch articles',
            articles: []
        });
    }
}