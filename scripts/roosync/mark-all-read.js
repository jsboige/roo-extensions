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
      console.log(`Marquage comme lu : ${msg.id} - ${msg.subject}`);
      await messageManager.markAsRead(msg.id);
    }
    
    console.log('Terminé.');
  } catch (error) {
    console.error('Erreur:', error);
  }
}

main();