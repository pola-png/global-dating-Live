// Free News API with Google Trends Integration
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
        const articles = [];
        
        // 1. Get trending topics from Google Trends (free)
        const trendingTopics = await getTrendingTopics();
        
        // 2. Fetch RSS news for trending topics
        for (const topic of trendingTopics.slice(0, 10)) {
            const topicNews = await fetchNewsForTopic(topic);
            articles.push(...topicNews);
        }
        
        // 3. Fetch from regular RSS sources
        const regularNews = await fetchRegularNews();
        articles.push(...regularNews);
        
        // 4. Enhance articles with AI
        const enhancedArticles = await enhanceArticlesWithAI(articles.slice(0, 50));
        
        // 5. Save to Appwrite database
        await saveArticlesToDatabase(enhancedArticles);
        
        res.status(200).json({ 
            articles: articles.slice(0, 50),
            count: articles.length,
            trending: trendingTopics
        });
        
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch news' });
    }
}

async function getTrendingTopics() {
    try {
        // Get multiple trending sources for traffic analysis
        const sources = await Promise.all([
            fetchGoogleTrends(),
            fetchRedditHot(),
            fetchTwitterTrending(),
            fetchYouTubeTrending()
        ]);
        
        // Combine and analyze traffic patterns
        const allTopics = sources.flat();
        const trafficAnalysis = analyzeTrafficSpikes(allTopics);
        
        return trafficAnalysis.slice(0, 20);
    } catch (error) {
        return ['AI technology', 'cryptocurrency', 'climate change'];
    }
}

async function fetchGoogleTrends() {
    try {
        // Get Google Trends + Google Search trending keywords
        const [trendsData, searchData] = await Promise.all([
            fetchTrendsRSS(),
            fetchGoogleSearchTrends()
        ]);
        
        return [...trendsData, ...searchData];
    } catch (error) {
        return [];
    }
}

async function fetchTrendsRSS() {
    try {
        const response = await fetch('https://trends.google.com/trends/trendingsearches/daily/rss?geo=US');
        const xmlText = await response.text();
        
        const trends = [];
        const matches = xmlText.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/g);
        
        if (matches) {
            matches.forEach(match => {
                const title = match.replace(/<title><!\[CDATA\[/, '').replace(/\]\]><\/title>/, '');
                if (title && title !== 'Daily Search Trends') {
                    trends.push({ topic: title.trim(), source: 'google_trends', traffic: 100 });
                }
            });
        }
        
        return trends;
    } catch (error) {
        return [];
    }
}

async function fetchGoogleSearchTrends() {
    try {
        // Use Google Custom Search API for trending keywords
        const keywords = ['breaking news', 'trending now', 'viral', 'latest news'];
        const trends = [];
        
        for (const keyword of keywords) {
            const searchUrl = `https://www.googleapis.com/customsearch/v1?key=${process.env.GOOGLE_SEARCH_API_KEY}&cx=${process.env.GOOGLE_SEARCH_ENGINE_ID}&q=${encodeURIComponent(keyword + ' today')}&num=5&sort=date`;
            
            const response = await fetch(searchUrl);
            const data = await response.json();
            
            if (data.items) {
                data.items.forEach(item => {
                    trends.push({
                        topic: item.title,
                        source: 'google_search',
                        traffic: 95,
                        url: item.link
                    });
                });
            }
        }
        
        return trends;
    } catch (error) {
        return [];
    }
}

async function fetchRedditHot() {
    try {
        const subreddits = ['worldnews', 'technology', 'news', 'todayilearned'];
        const topics = [];
        
        for (const sub of subreddits) {
            const response = await fetch(`https://www.reddit.com/r/${sub}/hot.json?limit=5`);
            const data = await response.json();
            
            data.data?.children?.forEach(post => {
                if (post.data.score > 1000) { // High traffic posts
                    topics.push({
                        topic: post.data.title,
                        source: 'reddit',
                        traffic: Math.min(post.data.score / 100, 100),
                        timePosted: post.data.created_utc
                    });
                }
            });
        }
        
        return topics;
    } catch (error) {
        return [];
    }
}

async function fetchTwitterTrending() {
    try {
        // Twitter trending topics via RSS (free)
        const response = await fetch('https://trends24.in/rss/united-states');
        const xmlText = await response.text();
        
        const topics = [];
        const matches = xmlText.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/g);
        
        if (matches) {
            matches.slice(0, 10).forEach(match => {
                const title = match.replace(/<title><!\[CDATA\[/, '').replace(/\]\]><\/title>/, '');
                if (title && !title.includes('Trends24')) {
                    topics.push({ topic: title.trim(), source: 'twitter', traffic: 90 });
                }
            });
        }
        
        return topics;
    } catch (error) {
        return [];
    }
}

async function fetchYouTubeTrending() {
    try {
        // YouTube trending via RSS
        const response = await fetch('https://www.youtube.com/feeds/videos.xml?chart=trending');
        const xmlText = await response.text();
        
        const topics = [];
        const matches = xmlText.match(/<title>(.*?)<\/title>/g);
        
        if (matches) {
            matches.slice(0, 10).forEach(match => {
                const title = match.replace(/<title>/, '').replace(/<\/title>/, '');
                if (title && !title.includes('YouTube')) {
                    topics.push({ topic: title.trim(), source: 'youtube', traffic: 85 });
                }
            });
        }
        
        return topics;
    } catch (error) {
        return [];
    }
}

function analyzeTrafficSpikes(topics) {
    // Score topics based on multiple factors
    const scoredTopics = topics.map(item => {
        let score = item.traffic || 50;
        
        // Boost score for recent posts (Reddit)
        if (item.timePosted) {
            const hoursAgo = (Date.now() / 1000 - item.timePosted) / 3600;
            if (hoursAgo < 2) score += 30; // Very recent
            else if (hoursAgo < 6) score += 20; // Recent
            else if (hoursAgo < 12) score += 10; // Somewhat recent
        }
        
        // Boost score for multiple source mentions
        const mentions = topics.filter(t => 
            t.topic.toLowerCase().includes(item.topic.toLowerCase().split(' ')[0])
        ).length;
        score += mentions * 15;
        
        // Boost score for breaking news keywords
        const breakingKeywords = ['breaking', 'urgent', 'alert', 'developing', 'just in'];
        if (breakingKeywords.some(keyword => 
            item.topic.toLowerCase().includes(keyword)
        )) {
            score += 25;
        }
        
        return { ...item, finalScore: score };
    });
    
    // Sort by final score and remove duplicates
    const uniqueTopics = [];
    const seen = new Set();
    
    scoredTopics
        .sort((a, b) => b.finalScore - a.finalScore)
        .forEach(item => {
            const key = item.topic.toLowerCase().substring(0, 20);
            if (!seen.has(key)) {
                seen.add(key);
                uniqueTopics.push(item.topic);
            }
        });
    
    return uniqueTopics;
}

async function fetchNewsForTopic(topic) {
    const url = `https://news.google.com/rss/search?q=${encodeURIComponent(topic)}`;
    
    try {
        const response = await fetch(url);
        const xmlText = await response.text();
        return parseRSS(xmlText, 'trending');
    } catch (error) {
        return [];
    }
}

async function fetchRegularNews() {
    const sources = [
        'https://feeds.bbci.co.uk/news/rss.xml',
        'https://rss.cnn.com/rss/edition.rss',
        'https://techcrunch.com/feed/',
        'https://www.theverge.com/rss/index.xml',
        'https://feeds.reuters.com/reuters/topNews',
        'https://www.wired.com/feed/rss',
        'https://feeds.mashable.com/Mashable',
        'https://www.engadget.com/rss.xml'
    ];
    
    const articles = [];
    
    for (const source of sources) {
        try {
            const response = await fetch(source);
            const xmlText = await response.text();
            const parsed = parseRSS(xmlText, 'news');
            articles.push(...parsed.slice(0, 3));
        } catch (error) {
            continue;
        }
    }
    
    return articles;
}

function parseRSS(xmlText, category) {
    const items = [];
    const itemMatches = xmlText.match(/<item[^>]*>[\s\S]*?<\/item>/g);
    
    if (itemMatches) {
        itemMatches.forEach(item => {
            const title = item.match(/<title[^>]*>([\s\S]*?)<\/title>/)?.[1]?.replace(/<[^>]*>/g, '') || '';
            const link = item.match(/<link[^>]*>([\s\S]*?)<\/link>/)?.[1] || '';
            const description = item.match(/<description[^>]*>([\s\S]*?)<\/description>/)?.[1]?.replace(/<[^>]*>/g, '') || '';
            
            if (title && title.length > 10) {
                items.push({
                    title: title.trim(),
                    link: link.trim(),
                    description: description.trim().substring(0, 200),
                    publishedAt: new Date().toISOString(),
                    category: category,
                    image: `https://source.unsplash.com/800x400/?${category}`,
                    slug: title.toLowerCase().replace(/[^a-z0-9]+/g, '-').substring(0, 50)
                });
            }
        });
    }
    
    return items;
}

async function saveArticlesToDatabase(articles) {
    for (const article of articles) {
        try {
            const slug = article.slug || generateSlug(article.title);
            
            // Check if article already exists
            const existing = await databases.listDocuments(
                DATABASE_ID,
                COLLECTION_ID,
                [`slug:${slug}`]
            );
            
            if (existing.documents.length === 0) {
                await databases.createDocument(
                    DATABASE_ID,
                    COLLECTION_ID,
                    'unique()',
                    {
                        title: article.title,
                        content: article.description || '',
                        url: article.link,
                        source: article.category,
                        category: article.category,
                        publishedDate: article.publishedAt,
                        trafficScore: 50,
                        imageUrl: article.image || '',
                        slug: slug
                    }
                );
            }
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

async function enhanceArticlesWithAI(articles) {
    const enhanced = [];
    
    for (const article of articles) {
        try {
            // Generate better title and summary using Gemini
            const [improvedTitle, summary] = await Promise.all([
                callGeminiAPI(`Create a catchy, SEO-friendly news title for: ${article.title}`),
                callGeminiAPI(`Create a brief, engaging summary (max 150 words) for: ${article.description}`)
            ]);
            
            enhanced.push({
                ...article,
                title: improvedTitle || article.title,
                description: summary || article.description,
                image: await generateNewsImage(article.title, article.category)
            });
        } catch (error) {
            enhanced.push({
                ...article,
                image: await generateNewsImage(article.title, article.category)
            }); // Use original if AI fails
        }
    }
    
    return enhanced;
}

async function generateNewsImage(title, category) {
    try {
        // First try AI to find real news images
        const aiImageUrl = await getAIImageUrl(title);
        if (aiImageUrl) return aiImageUrl;
        
        // Fallback to category-based images
        const sources = [
            () => getUnsplashImage(category),
            () => getPexelsImage(category),
            () => getPixabayImage(category),
            () => getFallbackImage(category)
        ];
        
        for (const source of sources) {
            const imageUrl = await source();
            if (imageUrl) return imageUrl;
        }
        
        return getFallbackImage(category);
    } catch (error) {
        return getFallbackImage(category);
    }
}

async function getAIImageUrl(title) {
    try {
        const prompt = `Find a relevant image URL for this news headline: "${title}". Return only a direct image URL (jpg, png, webp) from a reliable news source, stock photo site, or public domain. If no suitable image found, return "NONE".`;
        
        const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=' + process.env.GEMINI_API_KEY, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                    temperature: 0.3,
                    maxOutputTokens: 100
                }
            })
        });
        
        const data = await response.json();
        const aiResponse = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
        
        // Validate if response is a valid image URL
        if (aiResponse && aiResponse !== 'NONE' && isValidImageUrl(aiResponse)) {
            // Test if image URL is accessible
            const testResponse = await fetch(aiResponse, { method: 'HEAD' });
            if (testResponse.ok) {
                return aiResponse;
            }
        }
        
        return null;
    } catch (error) {
        return null;
    }
}

function isValidImageUrl(url) {
    try {
        const urlObj = new URL(url);
        const validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
        const hasValidExtension = validExtensions.some(ext => 
            urlObj.pathname.toLowerCase().includes(ext)
        );
        
        return urlObj.protocol === 'https:' && hasValidExtension;
    } catch (error) {
        return false;
    }
}

async function getUnsplashImage(category) {
    try {
        const keywords = getImageKeywords(category);
        const response = await fetch(`https://source.unsplash.com/800x400/?${keywords}`);
        return response.url;
    } catch (error) {
        return null;
    }
}

async function getPexelsImage(category) {
    try {
        if (!process.env.PEXELS_API_KEY) return null;
        
        const keywords = getImageKeywords(category);
        const response = await fetch(`https://api.pexels.com/v1/search?query=${keywords}&per_page=1`, {
            headers: { 'Authorization': process.env.PEXELS_API_KEY }
        });
        
        const data = await response.json();
        return data.photos?.[0]?.src?.medium || null;
    } catch (error) {
        return null;
    }
}

async function getPixabayImage(category) {
    try {
        if (!process.env.PIXABAY_API_KEY) return null;
        
        const keywords = getImageKeywords(category);
        const response = await fetch(`https://pixabay.com/api/?key=${process.env.PIXABAY_API_KEY}&q=${keywords}&image_type=photo&per_page=3`);
        
        const data = await response.json();
        return data.hits?.[0]?.webformatURL || null;
    } catch (error) {
        return null;
    }
}

function getImageKeywords(category) {
    const categoryMap = {
        'technology': 'technology,computer,innovation',
        'business': 'business,office,meeting',
        'sports': 'sports,athlete,competition',
        'entertainment': 'entertainment,movie,music',
        'health': 'health,medical,wellness',
        'science': 'science,research,laboratory',
        'politics': 'politics,government,news',
        'trending': 'news,breaking,headline',
        'general': 'news,newspaper,information'
    };
    
    return categoryMap[category] || 'news,article,information';
}

function getFallbackImage(category) {
    const fallbacks = {
        'technology': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=800&h=400&fit=crop',
        'business': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=400&fit=crop',
        'sports': 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800&h=400&fit=crop',
        'entertainment': 'https://images.unsplash.com/photo-1489599904472-af35ff2c7c3f?w=800&h=400&fit=crop',
        'health': 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&h=400&fit=crop',
        'science': 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=800&h=400&fit=crop',
        'politics': 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=800&h=400&fit=crop',
        'general': 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800&h=400&fit=crop'
    };
    
    return fallbacks[category] || fallbacks['general'];
}

async function callGeminiAPI(prompt) {
    try {
        const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=' + process.env.GEMINI_API_KEY, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                    temperature: 0.7,
                    maxOutputTokens: 200
                }
            })
        });
        
        const data = await response.json();
        return data.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
    } catch (error) {
        return '';
    }
}