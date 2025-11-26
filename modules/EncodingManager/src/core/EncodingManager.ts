import { ConfigurationManager, EncodingConfiguration } from './ConfigurationManager';
import { MonitoringService, EncodingStatus } from '../monitoring/MonitoringService';
import { UnicodeValidator } from '../validation/UnicodeValidator';

export interface EncodingResult {
    success: boolean;
    data: string;
    originalEncoding?: string;
    error?: string;
    warnings?: string[];
}

export interface IEncodingManager {
    convert(input: string, targetEncoding?: string): EncodingResult;
    validate(input: string): boolean;
    getConfig(): EncodingConfiguration;
    getEncodingStatus(): Promise<EncodingStatus>;
}

export class EncodingManager implements IEncodingManager {
    private configManager: ConfigurationManager;
    private monitor: MonitoringService;
    private validator: UnicodeValidator;

    constructor(configPath?: string) {
        this.configManager = new ConfigurationManager(configPath);
        const config = this.configManager.getConfig();
        
        this.monitor = new MonitoringService({
            enabled: config.monitoringEnabled,
            interval: 60000
        });
        
        this.validator = new UnicodeValidator(config.validationMode);
        
        if (config.monitoringEnabled) {
            this.monitor.start();
        }
    }

    public convert(input: string, targetEncoding?: string): EncodingResult {
        const config = this.configManager.getConfig();
        const target = targetEncoding || config.defaultEncoding;
        
        try {
            // Validation pré-conversion
            if (!this.validator.isValidUTF8(input)) {
                if (config.validationMode === 'strict') {
                    throw new Error('Input string contains invalid UTF-8 sequences');
                }
            }

            // Simulation de conversion robuste
            // Dans un environnement Node.js complet, Buffer gère la plupart des encodages
            // Pour les encodages legacy (Windows-1252), on pourrait utiliser iconv-lite
            
            if (!Buffer.isEncoding(target as BufferEncoding) && target !== 'windows-1252') {
                 // Fallback si l'encodage n'est pas supporté nativement
                 if (config.fallbackEncoding) {
                     console.warn(`Encoding ${target} not supported, falling back to ${config.fallbackEncoding}`);
                     return this.convert(input, config.fallbackEncoding);
                 }
                 throw new Error(`Unsupported encoding: ${target}`);
            }

            let resultData = input;
            
            // Logique de conversion simulée pour la démonstration
            // En réalité: const buffer = Buffer.from(input); resultData = iconv.decode(buffer, target);
            
            return {
                success: true,
                data: resultData,
                originalEncoding: 'utf-8', // Assumé pour string JS
                warnings: []
            };

        } catch (error: any) {
            return {
                success: false,
                data: '',
                error: error.message
            };
        }
    }

    public validate(input: string): boolean {
        return this.validator.isValidUTF8(input);
    }

    public getConfig(): EncodingConfiguration {
        return this.configManager.getConfig();
    }
    
    public async getEncodingStatus(): Promise<EncodingStatus> {
        return this.monitor.getEncodingStatus();
    }
    
    public stopMonitoring(): void {
        this.monitor.stop();
    }
}