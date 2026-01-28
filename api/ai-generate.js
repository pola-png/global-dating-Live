// AI News Generation Cron - Processes unprocessed headlines with Gemini AI
import { Client, Databases } from 'node-appwrite';

const client = new Client()
  .setEndpoint('https://nyc.cloud.appwrite.io/v1')
  .setProject('69384bc2002e7f635849')
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);
const DATABASE_ID = '69384d3300376e805bf8';
const HEADLINES_COLLECTION = 'rss_headlines';
const NEWS_COLLECTION = 'news_articles';

export default async function handler(req, res) {
    try {
        const unprocessedHeadlines = await getUnprocessedHeadlines();
        const aiArticles = await generateAIArticles(unprocessedHeadlines);
        await saveArticlesToDatabase(aiArticles);
        await markHeadlinesAsProcessed(unprocessedHeadlines);
        
        res.status(200).json({ 
            success: true,
            generated: aiArticles.length,
            processed: unprocessedHeadlines.length,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('AI generation failed:', error);
        res.status(500).json({ 
            error: 'AI generation failed',
            details: error.message 
        });
    }
}

async function getUnprocessedHeadlines() {
    try {
        const result = await databases.listDocuments(
            DATABASE_ID,
            HEADLINES_COLLECTION,
            [
                { method: 'equal', attribute: 'processed', value: false },
                { method: 'limit', value: 5 }
            ]
        );
        return result.documents;
    } catch (error) {
        console.error('Error fetching headlines:', error);
        return [];
    }
}

async function generateAIArticles(headlines) {
    const aiArticles = [];
    
    for (const headline of headlines) {
        try {
            const prompt = `Write a comprehensive news article based on this headline: "${headline.title}"\nDescription: ${headline.description}\nOriginal source: ${headline.source}\nWrite a detailed, engaging article of 500-1000+ words. Include background context, analysis, and implications. Make it professional and informative. Return JSON with: {"title": "enhanced title", "content": "full detailed article", "summary": "brief summary"}`;
            
            const aiResponse = await callGeminiAPI(prompt);
            const aiContent = JSON.parse(aiResponse);
            
            aiArticles.push({
                title: (aiContent.title || headline.title).substring(0, 255),
                content: (aiContent.content || headline.description).substring(0, 1000),
                url: headline.link.substring(0, 500),
                source: headline.source.substring(0, 100),
                category: (headline.source || 'general').substring(0, 50),
                publishedDate: headline.pubDate,
                trafficScore: Math.floor(Math.random() * 100),
                imageUrl: `https://images.unsplash.com/800x400/?news`.substring(0, 500),
                slug: generateSlug(aiContent.title || headline.title)
            });
        } catch (error) {
            console.error('AI generation failed for headline:', headline.title, error);
        }
    }
    
    return aiArticles;
}

async function callGeminiAPI(prompt) {
    if (!process.env.GEMINI_API_KEY) {
        throw new Error('GEMINI_API_KEY not set');
    }
    
    const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=' + process.env.GEMINI_API_KEY, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
                temperature: 0.7,
                maxOutputTokens: 2000
            }
        })
    });
    
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
}

function generateSlug(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .substring(0, 100);
}

async function saveArticlesToDatabase(articles) {
    for (const article of articles) {
        try {
            await databases.createDocument(
                DATABASE_ID,
                NEWS_COLLECTION,
                'unique()',
                article
            );
        } catch (error) {
            console.error('Error saving article:', error);
        }
    }
}

async function markHeadlinesAsProcessed(headlines) {
    for (const headline of headlines) {
        try {
            await databases.updateDocument(
                DATABASE_ID,
                HEADLINES_COLLECTION,
                headline.$id,
                { processed: true }
            );
        } catch (error) {
            console.error('Error marking headline as processed:', error);
        }
    }
}