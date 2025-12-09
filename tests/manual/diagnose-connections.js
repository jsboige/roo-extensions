require('dotenv').config({ path: 'mcps/internal/servers/roo-state-manager/.env' });
const { OpenAI } = require('openai');
const { QdrantClient } = require('@qdrant/js-client-rest');

async function testOpenAI() {
    console.log('🔍 Test OpenAI...');
    if (!process.env.OPENAI_API_KEY) {
        console.error('❌ OPENAI_API_KEY manquante');
        return;
    }
    try {
        const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
        const response = await openai.embeddings.create({
            model: 'text-embedding-3-small',
            input: 'test connection',
        });
        console.log('✅ OpenAI OK. Embedding length:', response.data[0].embedding.length);
    } catch (error) {
        console.error('❌ Erreur OpenAI:', error.message);
        if (error.response) console.error('Détails:', error.response.data);
    }
}

async function testQdrant() {
    console.log('🔍 Test Qdrant...');
    if (!process.env.QDRANT_URL) {
        console.error('❌ QDRANT_URL manquante');
        return;
    }
    try {
        const client = new QdrantClient({
            url: process.env.QDRANT_URL,
            apiKey: process.env.QDRANT_API_KEY,
        });
        const collections = await client.getCollections();
        console.log('✅ Qdrant OK. Collections:', collections.collections.map(c => c.name).join(', '));

        const collectionName = process.env.QDRANT_COLLECTION_NAME || 'roo_tasks_semantic_index';
        try {
            const info = await client.getCollection(collectionName);
            console.log(`ℹ️ Collection '${collectionName}' status:`, info.status, 'Points:', info.points_count);
        } catch (e) {
            console.warn(`⚠️ Collection '${collectionName}' non trouvée ou erreur:`, e.message);
        }

    } catch (error) {
        console.error('❌ Erreur Qdrant:', error.message);
    }
}

async function run() {
    await testOpenAI();
    await testQdrant();
}

run();