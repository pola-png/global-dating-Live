// RSS Fetch Cron - Fetches raw headlines every hour
import { Client, Databases } from 'node-appwrite';
import Parser from 'rss-parser';

const client = new Client()
  .setEndpoint('https://nyc.cloud.appwrite.io/v1')
  .setProject('69384bc2002e7f635849')
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = '69384d3300376e805bf8';
const COLLECTION_ID = 'rss_headlines';
const parser = new Parser();

export default async function handler(req, res) {
    try {
        if (!process.env.APPWRITE_API_KEY) {
            return res.status(500).json({ error: 'APPWRITE_API_KEY not configured' });
        }

        const articles = await fetchRSSNews();
        
        if (articles.length > 0) {
            await saveHeadlinesToDatabase(articles);
        }
        
        res.status(200).json({
            success: true,
            headlinesFetched: articles.length,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('RSS fetch failed:', error);
        res.status(500).json({ 
            error: 'RSS fetch failed',
            details: error.message
        });
    }
}

async function fetchRSSNews() {
    const sources = [
        { url: 'https://www.aljazeera.com/xml/rss/all.xml', name: 'Al Jazeera' },
        { url: 'https://feeds.bbci.co.uk/news/rss.xml', name: 'BBC News' },
        { url: 'https://feeds.bbci.co.uk/news/world/rss.xml', name: 'BBC World' },
        { url: 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB?hl=en-US&gl=US&ceid=US:en', name: 'Google News' }
    ];
    
    const articles = [];
    
    for (const source of sources) {
        try {
            const feed = await parser.parseURL(source.url);
            
            feed.items.slice(0, 3).forEach((item) => {
                try {
                    const title = cleanText(item.title || '');
                    const description = cleanText(item.contentSnippet || item.content || '');
                    const link = item.link || '';
                    const pubDate = item.pubDate || item.isoDate || new Date().toISOString();
                    
                    if (title && link && description) {
                        articles.push({
                            title: title.substring(0, 255),
                            link: link.substring(0, 500),
                            description: description.substring(0, 102),
                            pubDate: new Date(pubDate).toISOString(),
                            source: source.name,
                            processed: false
                        });
                    }
                } catch (itemError) {
                    console.error(`Error processing item from ${source.name}:`, itemError);
                }
            });
        } catch (error) {
            console.error(`Error fetching ${source.name}:`, error);
        }
    }
    
    return articles;
}

function cleanText(text) {
    if (!text) return '';
    return text
        .replace(/<[^>]*>/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

async function saveHeadlinesToDatabase(articles) {
    for (const article of articles) {
        try {
            // Check if headline already exists
            const existing = await databases.listDocuments(
                DATABASE_ID,
                COLLECTION_ID,
                [Query.equal('link', article.link)]
            );
            
            if (existing.documents.length === 0) {
                await databases.createDocument(
                    DATABASE_ID,
                    COLLECTION_ID,
                    'unique()',
                    article
                );
            }
        } catch (error) {
            console.error('Error saving headline:', error.message);
        }
    }
}