# Race Condition Fix - Manual Verification Guide

## Overview

This document provides manual testing procedures to verify that the race condition fix works correctly.

## The Bug (Before Fix)

**Scenario:**

1. User types a message while a tool is executing
2. Tool response arrives → UI re-renders → `sendingDisabled` becomes `true`
3. User clicks Send button (still visually active)
4. **BUG:** Message was queued BUT `clearDraft()` immediately wiped the input
5. **RESULT:** Message disappeared from UI before user confirmation → **DATA LOSS**

## The Fix

### Changes Made

1. **Removed clearDraft() during queueing** (`ChatView.tsx:608-620`)
    - When `sendingDisabled: true`, messages are queued but draft is NOT cleared
    - Draft remains visible until system processes it properly
2. **Reduced debounce from 300ms to 100ms**
    - Provides faster autosave for better race condition protection
    - Reduces vulnerability window from 300ms to 100ms

### Technical Details

```typescript
// BEFORE (BUG):
if (sendingDisabled) {
	vscode.postMessage({ type: "queueMessage", text, images })
	clearDraft() // ❌ BUG: Clears immediately
	setSelectedImages([])
	return
}

// AFTER (FIXED):
if (sendingDisabled) {
	vscode.postMessage({ type: "queueMessage", text, images })
	// ✅ FIX: Do NOT clear draft when queueing
	// Draft stays visible until message is properly processed
	return
}
```

## Manual Test Cases

### Test 1: Basic Race Condition Scenario

**Steps:**

1. Open Roo-Cline in VSCode
2. Start a new task (e.g., "Create a hello world function")
3. Wait for a tool to start executing (watch for "Executing..." indicator)
4. **While tool is executing**, type a new message: "Also add error handling"
5. **Immediately** after typing, click the Send button
6. Observe the message input field

**Expected Result:**

- ✅ Message stays visible in the input field
- ✅ Message is queued (check console: "queueMessage")
- ✅ When tool finishes, queued message is processed
- ✅ **NO DATA LOSS**

**Failure Indicators:**

- ❌ Message disappears from input immediately after clicking Send
- ❌ Message is never sent or processed
- ❌ User has to re-type the message

### Test 2: Fast Typing Scenario (100ms Debounce)

**Steps:**

1. Open Roo-Cline
2. Start a task
3. Type a message **very quickly** (< 100ms between keystrokes): "Fast typing test"
4. Click Send **within 150ms** of finishing typing
5. Observe behavior

**Expected Result:**

- ✅ Message is saved to localStorage within ~100ms
- ✅ Message is sent successfully
- ✅ If race condition occurs, message is recoverable from localStorage

**Verification:**

- Open browser DevTools → Application → Local Storage
- Check for key: `roo-draft.{task-id}`
- Should contain the message text within 100ms of typing

### Test 3: Message Recovery After Reload

**Steps:**

1. Start typing a message: "This is important"
2. Wait 200ms (for autosave to trigger)
3. **Before sending**, reload VSCode window (Ctrl+R or Cmd+R)
4. Observe the message input field

**Expected Result:**

- ✅ Message is restored from localStorage
- ✅ User can continue editing or send

### Test 4: Multiple Rapid Messages

**Steps:**

1. Start a task
2. Send first message: "Message 1"
3. **Immediately** while tool is processing, type: "Message 2"
4. Click Send
5. **Immediately** type: "Message 3"
6. Click Send

**Expected Result:**

- ✅ All three messages are queued or sent
- ✅ No message is lost
- ✅ Messages are processed in order

### Test 5: Concurrent Tool Response

**Steps:**

1. Start a task that executes a long-running command
2. Type a message mid-execution
3. Observe for the exact moment when a tool response arrives
4. Click Send **at that exact moment**
5. Check console logs for timing

**Expected Result:**

- ✅ Even if clicked at the exact moment of tool response, message is not lost
- ✅ Message remains visible in input
- ✅ Message is queued and eventually processed

## Automated Test Coverage

While manual testing is important, automated tests should also verify:

### Unit Tests (Hook Level)

- [x] `useAutosaveDraft` saves drafts within 100ms
- [x] `useAutosaveDraft` handles localStorage errors gracefully
- [x] Draft content persists across component unmounts

### Integration Tests (Component Level)

- [ ] Message is NOT cleared when queueing (sendingDisabled: true)
- [ ] Message IS cleared after successful send (sendingDisabled: false)
- [ ] Draft persists across re-renders
- [ ] Multiple rapid sends don't lose messages

**Note:** Integration tests have TypeScript configuration issues with the test context.
Manual testing remains the primary verification method for now.

## Performance Verification

### Debounce Timing

**Before:**

- Debounce: 300ms
- Vulnerability window: 300ms (user types → autosave triggers)
- Risk: High for users who type and send quickly

**After:**

- Debounce: 100ms
- Vulnerability window: 100ms
- Risk: Significantly reduced (3x better)

### localStorage Operations

Monitor localStorage write frequency:

```javascript
// In browser console:
let writeCount = 0
const originalSetItem = localStorage.setItem
localStorage.setItem = function (...args) {
	writeCount++
	console.log(`localStorage write #${writeCount}:`, args[0])
	return originalSetItem.apply(this, args)
}
```

**Expected:**

- Writes should be debounced (not on every keystroke)
- Write frequency should be reasonable (~10 writes/second max during typing)
- No performance degradation observed

## Rollback Criteria

If any of these occur, consider rolling back:

1. **Data Loss Still Occurs:**

    - Messages disappear during race conditions
    - Queued messages are never processed

2. **Performance Degradation:**

    - UI becomes sluggish during typing
    - Excessive localStorage writes cause freezing

3. **localStorage Errors:**

    - Quota exceeded errors become frequent
    - Data corruption in localStorage

4. **Regression in Existing Functionality:**
    - Normal message sending breaks
    - Draft persistence stops working
    - Other UI components affected

## Success Criteria

The fix is considered successful when:

- ✅ No data loss in race condition scenarios (Test 1-5 all pass)
- ✅ 100ms debounce provides fast autosave without performance impact
- ✅ Existing functionality remains intact
- ✅ User feedback confirms no more "swallowed messages"
- ✅ Console logs show messages are queued correctly

## Monitoring Post-Deployment

After deployment, monitor for:

1. **User Reports:**

    - "Message disappeared" issues should decrease to zero
    - Check GitHub issues for related bug reports

2. **Telemetry:**

    - Track `queueMessage` vs `sendMessage` ratios
    - Monitor localStorage error rates

3. **Performance:**
    - Check for increased localStorage quota errors
    - Monitor UI responsiveness metrics

## Known Limitations

1. **Very Fast Typing (<100ms):**

    - If user types and sends within 100ms, autosave may not complete
    - However, message is still sent correctly (not lost)
    - Only affects recovery after reload

2. **localStorage Quota:**

    - Large conversations may hit storage limits
    - Gracefully handled with console warnings
    - User notified if quota exceeded

3. **Multiple Conversations:**
    - Each conversation has its own draft key
    - Switching conversations preserves individual drafts
    - No interference between conversation drafts

## Conclusion

This fix addresses the critical race condition that caused message loss. The combination of:

1. Not clearing draft during queueing
2. Reduced debounce time (100ms)
3. Robust localStorage error handling

...provides a comprehensive solution that maintains message integrity even in edge cases.
