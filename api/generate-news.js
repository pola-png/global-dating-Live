// News Generation with Google Trends SEO Integration
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
        // Get trending keywords from Google Trends
        const trendingKeywords = await getTrendingKeywords();
        
        // Get RSS headlines
        const rssHeadlines = await getRSSHeadlines();
        
        // Generate AI articles with SEO keywords
        const articles = await generateAIArticles(rssHeadlines, trendingKeywords);
        
        // Save to database
        await saveArticlesToDatabase(articles);
        
        res.status(200).json({ 
            success: true,
            generated: articles.length,
            keywords: trendingKeywords.slice(0, 10)
        });
        
    } catch (error) {
        res.status(500).json({ error: 'Failed to generate news' });
    }
}

async function getTrendingKeywords() {
    try {
        const response = await fetch('https://trends.google.com/trends/trendingsearches/daily/rss?geo=US');
        const xmlText = await response.text();
        
        const keywords = [];
        const matches = xmlText.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/g);
        
        if (matches) {
            matches.forEach(match => {
                const keyword = match.replace(/<title><!\[CDATA\[/, '').replace(/\]\]><\/title>/, '');
                if (keyword && keyword !== 'Daily Search Trends') {
                    keywords.push(keyword.trim());
                }
            });
        }
        
        return keywords;
    } catch (error) {
        return ['AI technology', 'breaking news', 'trending now'];
    }
}

async function getRSSHeadlines() {
    const sources = [
        'https://feeds.bbci.co.uk/news/rss.xml',
        'https://rss.cnn.com/rss/edition.rss',
        'https://techcrunch.com/feed/'
    ];
    
    const headlines = [];
    
    for (const source of sources) {
        try {
            const response = await fetch(source);
            const xmlText = await response.text();
            const items = xmlText.match(/<item[^>]*>[\s\S]*?<\/item>/g);
            
            if (items) {
                items.slice(0, 5).forEach(item => {
                    const title = item.match(/<title[^>]*>([\s\S]*?)<\/title>/)?.[1]?.replace(/<[^>]*>/g, '') || '';
                    if (title) headlines.push(title.trim());
                });
            }
        } catch (error) {
            continue;
        }
    }
    
    return headlines;
}

async function generateAIArticles(headlines, keywords) {
    const articles = [];
    
    for (let i = 0; i < Math.min(headlines.length, 10); i++) {
        const headline = headlines[i];
        const seoKeywords = keywords.slice(0, 5).join(', ');
        
        const prompt = `Write a news article based on this headline: "${headline}". 
        Include these trending SEO keywords naturally: ${seoKeywords}.
        Make it 300-500 words, engaging, and SEO-optimized.
        Return JSON with: title, content, category, seoKeywords`;
        
        try {
            const aiResponse = await callGeminiAPI(prompt);
            const article = JSON.parse(aiResponse);
            
            articles.push({
                title: article.title || headline,
                content: article.content || '',
                category: article.category || 'News',
                seoKeywords: article.seoKeywords || seoKeywords,
                publishedDate: new Date().toISOString(),
                trafficScore: Math.floor(Math.random() * 100),
                imageUrl: `https://images.unsplash.com/800x400/?${article.category}`,
                slug: generateSlug(article.title || headline)
            });
        } catch (error) {
            // Fallback if AI fails
            articles.push({
                title: headline,
                content: `Breaking news about ${headline}. Stay tuned for more updates.`,
                category: 'News',
                seoKeywords: seoKeywords,
                publishedDate: new Date().toISOString(),
                trafficScore: 50,
                imageUrl: 'https://images.unsplash.com/800x400/?news',
                slug: generateSlug(headline)
            });
        }
    }
    
    return articles;
}

async function callGeminiAPI(prompt) {
    const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=' + process.env.GEMINI_API_KEY, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
                temperature: 0.7,
                maxOutputTokens: 1000
            }
        })
    });
    
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
}

async function saveArticlesToDatabase(articles) {
    for (const article of articles) {
        try {
            await databases.createDocument(
                DATABASE_ID,
                COLLECTION_ID,
                'unique()',
                article
            );
        } catch (error) {
            console.error('Error saving article:', error);
        }
    }
}

function generateSlug(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .substring(0, 100);
}