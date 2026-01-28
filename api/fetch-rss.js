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

        const { articles, errors } = await fetchRSSNews();
        
        if (articles.length > 0) {
            await saveHeadlinesToDatabase(articles);
        }
        
        res.status(200).json({
            success: true,
            headlinesFetched: articles.length,
            errors: errors,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('RSS fetch failed:', error);
        res.status(500).json({ 
            error: 'RSS fetch failed',
            details: error.message,
            stack: error.stack
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
    const errors = [];
    
    for (const source of sources) {
        try {
            const response = await fetch(source.url, {
                headers: { 'User-Agent': 'Mozilla/5.0 (compatible; NewsBot/1.0)' },
                signal: AbortSignal.timeout(10000)
            });
            
            if (!response.ok) {
                errors.push(`${source.name}: HTTP ${response.status}`);
                continue;
            }
            
            const xmlText = await response.text();
            const items = xmlText.match(/<item[^>]*>[\s\S]*?<\/item>/g) || [];
            
            if (items.length === 0) {
                errors.push(`${source.name}: No articles found`);
                continue;
            }
            
            items.slice(0, 3).forEach((item, index) => {
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
                            source: source.name.substring(0, 128),
                            processed: false
                        });
                    }
                } catch (itemError) {
                    console.error(`Error processing item from ${source.name}:`, itemError);
                }
            });
        } catch (error) {
            errors.push(`${source.name}: ${error.message}`);
            continue;
        }
    }
    
    return { articles, errors };
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