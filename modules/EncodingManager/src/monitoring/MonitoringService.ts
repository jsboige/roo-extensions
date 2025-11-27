import { EventEmitter } from 'events';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface EncodingStatus {
    systemLevel: {
        codePage: number;
        utf8Beta: boolean;
    };
    processLevel: {
        inputEncoding: string;
        outputEncoding: string;
    };
    timestamp: Date;
}

export interface MonitoringOptions {
    interval: number; // ms
    enabled: boolean;
}

export class MonitoringService extends EventEmitter {
    private intervalId: NodeJS.Timeout | null = null;
    private options: MonitoringOptions;

    constructor(options: MonitoringOptions = { interval: 60000, enabled: true }) {
        super();
        this.options = options;
    }

    public start(): void {
        if (this.options.enabled && !this.intervalId) {
            this.checkStatus(); // Initial check
            this.intervalId = setInterval(() => this.checkStatus(), this.options.interval);
            console.log('Encoding Monitoring Service started.');
        }
    }

    public stop(): void {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
            console.log('Encoding Monitoring Service stopped.');
        }
    }

    public async getEncodingStatus(): Promise<EncodingStatus> {
        try {
            const [codePage, utf8Beta] = await Promise.all([
                this.getSystemCodePage(),
                this.getUtf8BetaStatus()
            ]);

            return {
                systemLevel: {
                    codePage: codePage,
                    utf8Beta: utf8Beta
                },
                processLevel: {
                    inputEncoding: process.env.PYTHONIOENCODING || 'unknown', // Exemple de variable pertinente
                    outputEncoding: 'utf-8' // Node.js est généralement en UTF-8 interne
                },
                timestamp: new Date()
            };
        } catch (error) {
            console.error('Error retrieving encoding status:', error);
            // Fallback en cas d'erreur pour ne pas crasher le service
            return {
                systemLevel: {
                    codePage: 0,
                    utf8Beta: false
                },
                processLevel: {
                    inputEncoding: 'error',
                    outputEncoding: 'error'
                },
                timestamp: new Date()
            };
        }
    }

    private async getSystemCodePage(): Promise<number> {
        try {
            // Utilisation de chcp pour obtenir la page de code active
            const { stdout } = await execAsync('chcp');
            // Sortie typique: "Active code page: 65001" (dépend de la langue système)
            const match = stdout.match(/\d+/);
            return match ? parseInt(match[0], 10) : 0;
        } catch (e) {
            return 0;
        }
    }

    private async getUtf8BetaStatus(): Promise<boolean> {
        try {
            // Vérification de la clé de registre pour la fonctionnalité Beta UTF-8
            const cmd = 'reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Nls\\CodePage" /v ACP';
            const { stdout } = await execAsync(cmd);
            // Si ACP est 65001, alors la fonctionnalité est active (ou équivalent)
            // Note: La vraie clé "Beta: Use Unicode UTF-8 for worldwide language support" modifie l'ACP système
            return stdout.includes('65001');
        } catch (e) {
            return false;
        }
    }

    private async checkStatus(): Promise<void> {
        try {
            const status = await this.getEncodingStatus();
            this.emit('statusUpdate', status);
            
            // Détection d'anomalies basique
            if (status.systemLevel.codePage !== 65001) {
                this.emit('anomaly', {
                    type: 'SystemCodePageMismatch',
                    expected: 65001,
                    actual: status.systemLevel.codePage,
                    timestamp: new Date()
                });
            }
        } catch (error) {
            this.emit('error', error);
        }
    }
}