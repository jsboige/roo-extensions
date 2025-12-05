import { MessageManager } from '../../mcps/internal/servers/roo-state-manager/build/services/MessageManager.js';
import { getSharedStatePath } from '../../mcps/internal/servers/roo-state-manager/build/utils/server-helpers.js';

async function main() {
  try {
    const sharedStatePath = getSharedStatePath();
    const messageManager = new MessageManager(sharedStatePath);
    
    console.log('Lecture de l\'inbox...');
    const messages = await messageManager.listMessages({ status: 'unread' });
    
    console.log(`${messages.length} messages non lus trouvés.`);
    
    for (const msg of messages) {
      console.log('---------------------------------------------------');
      console.log(`ID: ${msg.id}`);
      console.log(`De: ${msg.from}`);
      console.log(`Sujet: ${msg.subject}`);
      console.log(`Date: ${msg.timestamp}`);
      console.log(`Contenu: ${msg.body.substring(0, 200)}...`); // Aperçu
      console.log('---------------------------------------------------');
      
      await messageManager.markAsRead(msg.id);
      console.log(`[MARQUÉ COMME LU]`);
    }
    
  } catch (error) {
    console.error('Erreur:', error);
  }
}

main();