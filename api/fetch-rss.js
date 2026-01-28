// RSS Fetch Cron - Fetches raw headlines every hour
import { Client, Databases } from 'node-appwrite';

const client = new Client()
  .setEndpoint('https://nyc.cloud.appwrite.io/v1')
  .setProject('69384bc2002e7f635849')
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = '69384d3300376e805bf8';
const COLLECTION_ID = 'rss_headlines';

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
    const articles = [];
    
    try {
        const response = await fetch('https://feeds.bbci.co.uk/news/rss.xml', {
            headers: { 'User-Agent': 'Mozilla/5.0 (compatible; NewsBot/1.0)' }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const xmlText = await response.text();
        const items = xmlText.match(/<item[^>]*>[\s\S]*?<\/item>/g) || [];
        
        items.slice(0, 3).forEach((item) => {
            try {
                const title = extractText(item, 'title');
                const description = extractText(item, 'description');
                const link = extractText(item, 'link');
                const pubDate = extractText(item, 'pubDate');
                
                if (title && link && description) {
                    articles.push({
                        title: cleanText(title).substring(0, 255),
                        link: link.substring(0, 500),
                        description: cleanText(description).substring(0, 102),
                        pubDate: pubDate ? new Date(pubDate).toISOString() : new Date().toISOString(),
                        source: 'BBC News',
                        processed: false
                    });
                }
            } catch (itemError) {
                console.error('Error processing item:', itemError);
            }
        });
    } catch (error) {
        console.error('Error fetching RSS:', error);
    }
    
    return articles;
}

function extractText(xml, tag) {
    try {
        const cdataPattern = `<${tag}[^>]*><!\[CDATA\[([\s\S]*?)\]\]><\/${tag}>`;
        const cdataMatch = xml.match(new RegExp(cdataPattern, 'i'));
        if (cdataMatch) return cdataMatch[1].trim();
        
        const regularPattern = `<${tag}[^>]*>([\s\S]*?)<\/${tag}>`;
        const match = xml.match(new RegExp(regularPattern, 'i'));
        return match ? match[1].replace(/<[^>]*>/g, '').trim() : '';
    } catch (error) {
        return '';
    }
}

function cleanText(text) {
    if (!text) return '';
    return text
        .replace(/<[^>]*>/g, '')
        .replace(/&[^;]+;/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

async function saveHeadlinesToDatabase(articles) {
    for (const article of articles) {
        try {
            await databases.createDocument(
                DATABASE_ID,
                COLLECTION_ID,
                'unique()',
                article
            );
        } catch (error) {
            console.error('Error saving headline:', error.message);
        }
    }
}