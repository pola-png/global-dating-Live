// Real-time RSS News Generation
export default async function handler(req, res) {
    try {
        const { articles, errors } = await fetchRSSNews();
        
        res.status(200).json({ 
            success: true,
            generated: articles.length,
            keywords: ['breaking', 'news', 'latest', 'update'],
            articles: articles,
            errors: errors
        });
        
    } catch (error) {
        console.error('Generate news error:', error);
        res.status(500).json({ 
            error: 'Failed to generate news',
            details: error.message 
        });
    }
}

async function fetchRSSNews() {
    const sources = [
        { url: 'https://www.reuters.com/arc/outboundfeeds/news-rss/', category: 'World', name: 'Reuters' },
        { url: 'https://rss.cnn.com/rss/cnn_topstories.rss', category: 'Breaking', name: 'CNN' },
        { url: 'https://feeds.bbci.co.uk/news/rss.xml', category: 'World', name: 'BBC' },
        { url: 'https://www.aljazeera.com/xml/rss/all.xml', category: 'International', name: 'Al Jazeera' },
        { url: 'https://www.reuters.com/arc/outboundfeeds/world-news-rss/', category: 'World', name: 'Reuters World' }
    ];
    
    const articles = [];
    const errors = [];
    
    for (const source of sources) {
        try {
            const response = await fetch(source.url, {
                headers: { 'User-Agent': 'Mozilla/5.0' },
                timeout: 10000
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
                const title = extractText(item, 'title');
                const description = extractText(item, 'description');
                const pubDate = extractText(item, 'pubDate');
                
                if (title) {
                    articles.push({
                        id: `${source.category.toLowerCase()}_${Date.now()}_${index}`,
                        title: cleanText(title),
                        content: cleanText(description) || `Breaking news: ${title}`,
                        category: source.category,
                        publishedDate: pubDate ? new Date(pubDate).toISOString() : new Date().toISOString(),
                        imageUrl: `https://images.unsplash.com/800x400/?${source.category.toLowerCase()}`,
                        slug: generateSlug(title)
                    });
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
    const match = xml.match(new RegExp(`<${tag}[^>]*>([\s\S]*?)<\/${tag}>`, 'i'));
    return match ? match[1].replace(/<[^>]*>/g, '').trim() : '';
}

function cleanText(text) {
    return text
        .replace(/<[^>]*>/g, '')
        .replace(/&[^;]+;/g, '')
        .replace(/\s+/g, ' ')
        .trim()
        .substring(0, 500);
}

function generateSlug(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .substring(0, 100);
}
