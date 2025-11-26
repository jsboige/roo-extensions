import { EncodingManager } from '../src/core/EncodingManager';
import { ConfigurationManager } from '../src/core/ConfigurationManager';

// Mock ConfigurationManager to avoid file system dependency during tests
jest.mock('../src/core/ConfigurationManager');

describe('EncodingManager', () => {
    let manager: EncodingManager;

    beforeEach(() => {
        // Reset mocks
        (ConfigurationManager as any).mockClear();
        
        // Setup default mock implementation
        const mockConfig = {
            defaultEncoding: 'utf-8',
            validationMode: 'strict',
            fallbackEncoding: 'windows-1252',
            monitoringEnabled: false,
            logLevel: 'info'
        };
        
        (ConfigurationManager as any).mockImplementation(() => {
            return {
                getConfig: jest.fn().mockReturnValue(mockConfig),
                updateConfig: jest.fn()
            };
        });

        manager = new EncodingManager();
    });

    test('should initialize with default configuration', () => {
        const config = manager.getConfig();
        expect(config).toBeDefined();
    });

    test('should convert string successfully (simulation)', () => {
        const input = 'Test String';
        const result = manager.convert(input, 'utf-8');
        
        expect(result.success).toBe(true);
        expect(result.data).toBe(input);
    });

    test('should handle unsupported encoding with fallback', () => {
        const input = 'Test String';
        // Mock config to have fallback
        const mockConfig = {
            defaultEncoding: 'utf-8',
            fallbackEncoding: 'utf-8', // Fallback to supported for test
            validationMode: 'lax',
            monitoringEnabled: false,
            logLevel: 'info'
        };
        
        // Update the mock for this specific test
        const mockConfigManagerInstance = (manager as any).configManager;
        mockConfigManagerInstance.getConfig.mockReturnValue(mockConfig);

        const result = manager.convert(input, 'unsupported-encoding');
        
        // Since we mocked fallback to utf-8, it should succeed via recursion
        expect(result.success).toBe(true);
    });

    test('should validate valid UTF-8 string', () => {
        const input = 'Valid UTF-8 String éàç';
        expect(manager.validate(input)).toBe(true);
    });

    test('should detect invalid UTF-8 sequences', () => {
        const input = 'Invalid \uFFFD Sequence';
        // Depending on implementation of UnicodeValidator (which checks for replacement char)
        expect(manager.validate(input)).toBe(false);
    });
});