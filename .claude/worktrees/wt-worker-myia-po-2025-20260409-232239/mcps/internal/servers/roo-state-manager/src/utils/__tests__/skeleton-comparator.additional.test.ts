/**
 * Additional unit tests for SkeletonComparator
 *
 * Focuses on edge cases and private method coverage
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { SkeletonComparator, type SkeletonComparisonResult } from '../skeleton-comparator.js';
import type { ConversationSkeleton } from '../../types/conversation.js';

function createSkeleton(overrides?: Partial<ConversationSkeleton>): ConversationSkeleton {
  return {
    taskId: 'task-001',
    metadata: {
      title: 'Test task',
      lastActivity: '2026-02-10T10:00:00Z',
      createdAt: '2026-02-10T09:00:00Z',
      messageCount: 10,
      actionCount: 5,
      totalSize: 2048,
      workspace: '/workspace/project',
    },
    sequence: [],
    childTaskInstructionPrefixes: ['prefix-1', 'prefix-2'],
    isCompleted: true,
    truncatedInstruction: 'Do something',
    ...overrides,
  };
}

describe('SkeletonComparator - Additional Coverage', () => {
  let comparator: SkeletonComparator;

  beforeEach(() => {
    comparator = new SkeletonComparator();
  });

  // Tests for private method areSetsEqual (currently 0% coverage)
  describe('areSetsEqual (private method)', () => {
    // Access private method for testing
    const areSetsEqual = (set1: Set<any>, set2: Set<any>) => {
      return (comparator as any).areSetsEqual(set1, set2);
    };

    it('should return true for identical empty sets', () => {
      const set1 = new Set();
      const set2 = new Set();
      expect(areSetsEqual(set1, set2)).toBe(true);
    });

    it('should return true for sets with same elements', () => {
      const set1 = new Set(['a', 'b', 'c']);
      const set2 = new Set(['a', 'b', 'c']);
      expect(areSetsEqual(set1, set2)).toBe(true);
    });

    it('should return false for sets with different sizes', () => {
      const set1 = new Set(['a', 'b']);
      const set2 = new Set(['a', 'b', 'c']);
      expect(areSetsEqual(set1, set2)).toBe(false);
    });

    it('should return false for sets with different elements', () => {
      const set1 = new Set(['a', 'b', 'c']);
      const set2 = new Set(['a', 'b', 'd']);
      expect(areSetsEqual(set1, set2)).toBe(false);
    });

    it('should handle sets with various data types', () => {
      const set1 = new Set(['string', 123, true, null]);
      const set2 = new Set(['string', 123, true, null]);
      expect(areSetsEqual(set1, set2)).toBe(true);
    });

    it('should return false when second set is missing an element', () => {
      const set1 = new Set(['a', 'b', 'c']);
      const set2 = new Set(['a', 'b']);
      expect(areSetsEqual(set1, set2)).toBe(false);
    });

    it('should return false when first set is missing an element', () => {
      const set1 = new Set(['a', 'b']);
      const set2 = new Set(['a', 'b', 'c']);
      expect(areSetsEqual(set1, set2)).toBe(false);
    });
  });

  // Edge case tests for compare method
  describe('compare - Edge Cases', () => {
    it('should handle undefined metadata gracefully', () => {
      const oldSkeleton = createSkeleton({ metadata: undefined });
      const newSkeleton = createSkeleton();

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result).toBeDefined();
      expect(result.differences).toHaveLength(4); // taskId, workspace, truncatedInstruction, metadata differences
    });

    it('should handle null metadata gracefully', () => {
      const oldSkeleton = createSkeleton({ metadata: null as any });
      const newSkeleton = createSkeleton();

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result).toBeDefined();
      expect(result.differences).toHaveLength(4); // taskId, workspace, truncatedInstruction, metadata differences
    });

    it('should handle undefined arrays for childTaskInstructionPrefixes', () => {
      const oldSkeleton = createSkeleton({ childTaskInstructionPrefixes: undefined });
      const newSkeleton = createSkeleton();

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result).toBeDefined();
    });

    it('should handle empty arrays for childTaskInstructionPrefixes', () => {
      const oldSkeleton = createSkeleton({ childTaskInstructionPrefixes: [] });
      const newSkeleton = createSkeleton({ childTaskInstructionPrefixes: [] });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result.areIdentical).toBe(true);
    });

    it('should handle multiple differences simultaneously', () => {
      const oldSkeleton = createSkeleton({
        taskId: 'task-old',
        metadata: {
          ...createSkeleton().metadata,
          messageCount: 5,
          workspace: '/old/workspace',
        },
        isCompleted: false,
      });

      const newSkeleton = createSkeleton({
        taskId: 'task-new',
        metadata: {
          ...createSkeleton().metadata,
          messageCount: 15,
          workspace: '/new/workspace',
        },
        isCompleted: true,
      });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result.differences).toHaveLength(4); // taskId, workspace, messageCount, isCompleted
      expect(result.similarityScore).toBeLessThan(100);
    });
  });

  // Tests for high similarity edge cases
  describe('compare - High Similarity Scenarios', () => {
    it('should handle 89% similarity case (8/9 fields identical)', () => {
      const oldSkeleton = createSkeleton();
      const newSkeleton = createSkeleton({
        metadata: {
          ...createSkeleton().metadata,
          messageCount: 99,
        },
      });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result.similarityScore).toBeCloseTo(88.89, 0);
    });

    it('should handle 66.67% similarity case (6/9 fields identical)', () => {
      const oldSkeleton = createSkeleton();
      const newSkeleton = createSkeleton({
        taskId: 'different',
        metadata: {
          ...createSkeleton().metadata,
          messageCount: 99,
          lastActivity: 'different',
        },
      });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      expect(result.similarityScore).toBeCloseTo(66.67, 0);
    });
  });

  // Tests for severity distribution
  describe('getDifferenceSummary - Severity Distribution', () => {
    it('should count critical differences correctly', () => {
      const oldSkeleton = createSkeleton({ taskId: 'old' });
      const newSkeleton = createSkeleton({ taskId: 'new' });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      const summary = comparator.getDifferenceSummary(result);

      expect(summary.critical).toBe(1);
      expect(summary.major).toBe(0);
      expect(summary.minor).toBe(0);
    });

    it('should count mixed severities correctly', () => {
      const oldSkeleton = createSkeleton();
      const newSkeleton = createSkeleton({
        taskId: 'new', // critical
        metadata: {
          ...createSkeleton().metadata,
          messageCount: 99, // major
          lastActivity: 'different', // minor
        },
      });

      const result = comparator.compare(oldSkeleton, newSkeleton);
      const summary = comparator.getDifferenceSummary(result);

      expect(summary.critical).toBe(1);
      expect(summary.major).toBeGreaterThanOrEqual(1);
      expect(summary.minor).toBeGreaterThanOrEqual(1);
    });
  });

  // Tests for improve detection
  describe('identifyImprovements - Additional Scenarios', () => {
    it('should detect instruction completion improvement', () => {
      const oldSkeleton = createSkeleton({
        truncatedInstruction: 'long instruction...',
        metadata: { ...createSkeleton().metadata, workspace: '/workspace/project' }
      });
      const newerSkeleton = createSkeleton({
        // Set truncatedInstruction to empty string to make it falsy
        truncatedInstruction: '',
        metadata: { ...createSkeleton().metadata, workspace: '\\\\workspace\\\\project' }
      });

      const improvements = comparator.identifyImprovements(oldSkeleton, newerSkeleton);
      console.log('Actual improvements:', improvements);
      expect(improvements).toContain('Instruction complète extraite (truncated → complete)');
    });

    it('should detect no improvement when child task count decreases', () => {
      const oldSkeleton = createSkeleton({ childTaskInstructionPrefixes: ['a', 'b', 'c'] });
      const newerSkeleton = createSkeleton({ childTaskInstructionPrefixes: ['a'] });

      const improvements = comparator.identifyImprovements(oldSkeleton, newerSkeleton);
      expect(improvements.some(i => i.includes('child tasks'))).toBe(false);
    });

    it('should detect path normalization improvement', () => {
      const oldSkeleton = createSkeleton({
        metadata: { ...createSkeleton().metadata, workspace: '/workspace/project' }
      });
      const newerSkeleton = createSkeleton({
        metadata: { ...createSkeleton().metadata, workspace: '\\\\workspace\\\\project' }
      });

      const improvements = comparator.identifyImprovements(oldSkeleton, newerSkeleton);
      expect(improvements).toContain('Normalisation path Windows (/ → \\\\)');
    });
  });
});