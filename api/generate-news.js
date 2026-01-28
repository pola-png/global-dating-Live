// Real-time RSS News Generation with AI Enhancement
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
        const { articles, errors } = await fetchRSSNews();
        const aiArticles = await generateAIArticles(articles);
        await saveArticlesToDatabase(aiArticles);
        
        res.status(200).json({ 
            success: true,
            generated: aiArticles.length,
            articles: aiArticles,
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

async function generateAIArticles(rssArticles) {
    const aiArticles = [];
    
    for (const article of rssArticles.slice(0, 5)) {
        try {
            const prompt = `Write a complete news article based on this headline: "${article.title}"
Description: ${article.content}
Make it 300-500 words, engaging, and professional. Return JSON with: {"title": "enhanced title", "content": "full article", "summary": "brief summary"}`;
            
            const aiResponse = await callGeminiAPI(prompt);
            const aiContent = JSON.parse(aiResponse);
            
            aiArticles.push({
                title: aiContent.title || article.title,
                content: aiContent.content || article.content,
                summary: aiContent.summary || article.content.substring(0, 200),
                category: article.category,
                publishedDate: article.publishedDate,
                imageUrl: article.imageUrl,
                slug: generateSlug(aiContent.title || article.title),
                source: 'AI Enhanced'
            });
        } catch (error) {
            // Fallback to original article
            aiArticles.push(article);
        }
    }
    
    return aiArticles;
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

async function fetchRSSNews() {
    const sources = [
        { url: 'https://www.aljazeera.com/xml/rss/all.xml', category: 'International', name: 'Al Jazeera' },
        { url: 'https://feeds.bbci.co.uk/news/rss.xml', category: 'World', name: 'BBC News' },
        { url: 'https://feeds.bbci.co.uk/news/world/rss.xml', category: 'World', name: 'BBC World' },
        { url: 'https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB?hl=en-US&gl=US&ceid=US:en', category: 'Breaking', name: 'Google News' }
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
    // Handle CDATA sections
    const cdataMatch = xml.match(new RegExp(`<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/${tag}>`, 'i'));
    if (cdataMatch) return cdataMatch[1].trim();
    
    // Handle regular tags
    const match = xml.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i'));
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
