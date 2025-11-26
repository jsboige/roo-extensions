import * as fs from 'fs';
import * as path from 'path';

export interface EncodingConfiguration {
    defaultEncoding: string;
    validationMode: 'strict' | 'lax';
    fallbackEncoding: string;
    monitoringEnabled: boolean;
    logLevel: 'debug' | 'info' | 'warn' | 'error';
}

export class ConfigurationManager {
    private config: EncodingConfiguration;
    private configPath: string;

    private static readonly DEFAULT_CONFIG: EncodingConfiguration = {
        defaultEncoding: 'utf-8',
        validationMode: 'strict',
        fallbackEncoding: 'windows-1252',
        monitoringEnabled: true,
        logLevel: 'info'
    };

    constructor(configPath?: string) {
        this.configPath = configPath || path.join(process.cwd(), 'encoding-config.json');
        this.config = this.loadConfig();
    }

    private loadConfig(): EncodingConfiguration {
        try {
            if (fs.existsSync(this.configPath)) {
                const fileContent = fs.readFileSync(this.configPath, 'utf-8');
                const userConfig = JSON.parse(fileContent);
                return { ...ConfigurationManager.DEFAULT_CONFIG, ...userConfig };
            }
        } catch (error) {
            console.warn(`Failed to load configuration from ${this.configPath}, using defaults. Error: ${error}`);
        }
        return { ...ConfigurationManager.DEFAULT_CONFIG };
    }

    public getConfig(): EncodingConfiguration {
        return { ...this.config };
    }

    public updateConfig(newConfig: Partial<EncodingConfiguration>): void {
        this.config = { ...this.config, ...newConfig };
        this.saveConfig();
    }

    private saveConfig(): void {
        try {
            fs.writeFileSync(this.configPath, JSON.stringify(this.config, null, 4), 'utf-8');
        } catch (error) {
            console.error(`Failed to save configuration to ${this.configPath}. Error: ${error}`);
        }
    }
}