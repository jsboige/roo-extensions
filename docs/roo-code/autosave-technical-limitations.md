# Autosave Draft Limitations and Future Improvements

## Overview

This document explains the limitations of the `useAutosaveDraft` hook implementation and outlines necessary improvements to fully resolve the message editor data loss bug.

## Current Implementation

The `useAutosaveDraft` hook provides:
- localStorage persistence with 300ms debounce
- Conversation isolation using task IDs
- Error handling for storage limitations
- Automatic draft clearing on successful sends

## Race Condition Analysis

### The Real Bug

The message editor data loss bug is caused by a **race condition** in `ChatView.tsx` (lines 608-620):

```typescript
if (sendingDisabled) {
    vscode.postMessage({ type: "queueMessage", text, images })
    clearDraft()  // ⚠️ BUG: Clears input BEFORE message is processed
    setSelectedImages([])
    return
}
```

**Scenario:**
1. User types a message (input is active, `sendingDisabled: false`)
2. Tool response arrives → triggers re-render → sets `sendingDisabled: true`
3. User clicks Send button (still visually active)
4. `handleSendMessage` reads `sendingDisabled: true`
5. Message is queued BUT `clearDraft()` immediately wipes the input
6. Message disappears from UI before user sees confirmation

### Why Autosave is Insufficient

The autosave hook provides **partial mitigation** but does NOT fix the root cause:

✅ **Works when:**
- User types and waits >300ms before sending
- Draft is saved to localStorage
- Even if race condition occurs, text can be restored later

❌ **Fails when:**
- User types quickly and sends in <300ms
- Debounce hasn't executed → no save to localStorage
- Race condition clears input → **message is permanently lost**

## Recommended Future Improvements

### Priority 1: Fix the Race Condition Directly

**Option A: Synchronize UI State** (Simplest)
```typescript
// Use useTransition or flushSync to ensure UI updates synchronously
if (sendingDisabled) {
    vscode.postMessage({ type: "queueMessage", text, images })
    // DON'T clear immediately - wait for confirmation
    return
}
```

**Option B: Optimistic UI Pattern**
```typescript
// Add message to UI immediately with "pending" state
// Process when system becomes available
// Clear only after confirmed send
```

**Option C: Lock Mechanism**
```typescript
// Prevent clearDraft() during the critical window
// between button click and message processing
```

### Priority 2: Reduce Debounce Time

Current 300ms debounce creates a vulnerability window. Consider:
- Reduce to 100ms for faster saves
- Use immediate save on Send button click
- Trade-off: more frequent localStorage writes

### Priority 3: Add Optimistic Locking

```typescript
const [isSending, setIsSending] = useState(false)

const handleSend = () => {
    if (isSending) return  // Prevent double-send
    setIsSending(true)
    
    // Send logic...
    
    // Only clear after confirmed success
    onSendSuccess(() => {
        clearDraft()
        setIsSending(false)
    })
}
```

## Testing Strategy for Future PRs

To properly test the race condition fix:

```typescript
it('should handle concurrent send and tool response', async () => {
    const { getByRole, rerender } = render(<ChatView />)
    
    // 1. User types
    const input = getByRole('textbox')
    await userEvent.type(input, 'test message')
    
    // 2. Simulate tool response arriving (triggers sendingDisabled: true)
    rerender(<ChatView sendingDisabled={true} />)
    
    // 3. User clicks send (button still active)
    const sendBtn = getByRole('button', { name: /send/i })
    await userEvent.click(sendBtn)
    
    // 4. Assert: message should NOT disappear
    expect(input).toHaveValue('test message')
    
    // 5. Verify: message was queued
    expect(mockPostMessage).toHaveBeenCalledWith({
        type: 'queueMessage',
        text: 'test message'
    })
})
```

## Conclusion

The `useAutosaveDraft` hook is a **valuable safety net** that:
- Protects against accidental page reloads
- Provides draft persistence across sessions
- Helps in >300ms scenarios

However, it does NOT fully resolve the race condition bug. A complete fix requires:
1. Addressing the `clearDraft()` timing issue in `handleSendMessage`
2. Implementing proper state synchronization
3. Adding comprehensive race condition tests

## References

- Bug investigation report: `bug_investigation_report.md`
- Send message flow analysis: `SEND-MESSAGE-FLOW-ANALYSIS.md`
- Architecture document: `../../../docs/roo-code/ARCHITECTURE-HOOK-AUTOSAVE-DRAFT.md`
- Original issue: Version 3.19.0 (2025-05-29) - "Fix: chat input clearing during running tasks"

## Next Steps

1. Create follow-up PR to fix race condition directly
2. Add comprehensive race condition tests
3. Consider reducing debounce time to 100ms
4. Implement optimistic locking pattern
5. Update user documentation about draft persistence behavior