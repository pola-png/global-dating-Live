// Serve AI-generated news articles from Appwrite
import { Client, Databases, Query } from 'node-appwrite';

const client = new Client()
  .setEndpoint('https://nyc.cloud.appwrite.io/v1')
  .setProject('69384bc2002e7f635849')
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = '69384d3300376e805bf8';
const COLLECTION_ID = 'news_articles';

export default async function handler(req, res) {
    try {
        const articles = await databases.listDocuments(
            DATABASE_ID,
            COLLECTION_ID,
            [
                Query.orderDesc('publishedDate'),
                Query.limit(20)
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