# Message Send Flow Analysis - Autosave Draft Safety

## Critical Question
**Does the autosave draft implementation guarantee that messages are properly sent when clicking Send, without data loss?**

## Answer: YES - Here's the proof

### 1. Message Send Flow (Step by Step)

```typescript
// In ChatView.tsx - handleSendMessage callback
const handleSendMessage = useCallback(
  (text: string, images: string[]) => {
    text = text.trim()
    
    if (text || images.length > 0) {
      if (sendingDisabled) {
        // STEP 1: Message is sent/queued FIRST
        vscode.postMessage({ type: "queueMessage", text, images })
        
        // STEP 2: Draft is cleared AFTER successful send
        clearDraft()
        setSelectedImages([])
        return
      }
      
      // Similar pattern for other message types
      // Always: Send message → Then clear draft
    }
  },
  [clearDraft, sendingDisabled]
)
```

### 2. Why This Is Safe

**Key Safety Mechanisms:**

1. **Synchronous Execution Order**
   - JavaScript executes synchronously in this callback
   - `vscode.postMessage(...)` is called FIRST
   - `clearDraft()` is called SECOND
   - No async gap where data could be lost

2. **State Before Send**
   - `inputValue` (which becomes `text` parameter) already contains the message
   - The message exists in component state, NOT in localStorage at this point
   - Clearing localStorage AFTER send doesn't affect the already-captured message

3. **No Debounce Interference**
   - `clearDraft()` immediately:
     - Clears component state (`setDraftContent('')`)
     - Cancels any pending debounced save
     - Removes from localStorage
   - Even if debounce is pending, it's cancelled before it could interfere

### 3. Test Coverage Analysis

#### Current Test: "should clear draft after successful message send"
```typescript
it('should clear draft after successful message send', async () => {
  localStorageMock.getItem.mockReturnValue('Draft message')
  renderChatView()

  const textarea = screen.getByTestId('message-input')
  const sendButton = screen.getByTestId('send-button')

  // Verify draft is loaded
  expect(textarea).toHaveValue('Draft message')

  // Send the message
  fireEvent.click(sendButton)

  // Should clear the draft
  await waitFor(() => {
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('roo-draft.test-task-123')
  })

  // Verify input is cleared
  expect(textarea).toHaveValue('')
})
```

**What this test DOES verify:**
- ✅ Draft is loaded correctly
- ✅ Send button click triggers the send
- ✅ Draft is cleared from localStorage
- ✅ Input is cleared from UI

**What this test DOESN'T explicitly verify:**
- ❌ Message content is sent via `vscode.postMessage` BEFORE draft is cleared
- ❌ Message content matches the draft content

### 4. Missing Test Coverage - Should We Add?

**Recommended Additional Test:**

```typescript
it('should send message content before clearing draft (send order verification)', async () => {
  localStorageMock.getItem.mockReturnValue('Important message to send')
  const mockPostMessage = vi.fn()
  vscode.postMessage = mockPostMessage
  
  renderChatView()

  const textarea = screen.getByTestId('message-input')
  const sendButton = screen.getByTestId('send-button')

  // Verify draft is loaded
  expect(textarea).toHaveValue('Important message to send')

  // Send the message
  fireEvent.click(sendButton)

  // CRITICAL: Verify message is sent with correct content
  expect(mockPostMessage).toHaveBeenCalledWith(
    expect.objectContaining({
      text: 'Important message to send'
    })
  )

  // Verify send happens BEFORE clear
  const postMessageCall = mockPostMessage.mock.invocationCallOrder[0]
  const removeItemCall = localStorageMock.removeItem.mock.invocationCallOrder[0]
  expect(postMessageCall).toBeLessThan(removeItemCall)
})
```

### 5. Race Condition Analysis

**Potential Concern:** What if debounce saves AFTER send but BEFORE clear?

**Answer:** This is impossible because:

```typescript
// In clearDraft()
const clearDraft = useCallback(() => {
  safeLocalStorage(
    () => localStorage.removeItem(storageKey),
    undefined
  )
  
  setDraftContent('')
  setHasInitialDraft(false)
  
  // CRITICAL: This cancels pending debounce
  if (debounceTimerRef.current) {
    clearTimeout(debounceTimerRef.current)
    setIsDebouncing(false)
  }
}, [storageKey, safeLocalStorage])
```

**Timeline:**
1. User types → `updateDraft()` called → debounce timer starts (300ms)
2. User clicks Send immediately (before 300ms)
3. `handleSendMessage()` calls `vscode.postMessage()` with current state
4. `handleSendMessage()` calls `clearDraft()`
5. `clearDraft()` cancels the pending debounce timer
6. No localStorage write happens

**Result:** Message is sent, draft is cleared, no data loss.

### 6. Backward Compatibility

**Does this change break existing message sending?**

**Answer:** NO

- `inputValue` is now `draftContent` from the hook
- `setInputValue` is now `updateDraft` from the hook  
- `clearDraft()` replaces `setInputValue("")`

All these are **drop-in replacements** with the same signature:
- `string` value
- `(string) => void` setter
- `() => void` clearer

The ONLY difference: persistence side effect (saving to localStorage)

### 7. Production Safety Checklist

✅ **Synchronous execution** - No async gaps  
✅ **Order guarantee** - Send always before clear  
✅ **Debounce cancellation** - Pending saves can't interfere  
✅ **State isolation** - Component state separate from localStorage  
✅ **Error handling** - localStorage errors don't block sending  
✅ **Backward compatible** - Drop-in replacement for existing code  

### 8. Worst Case Scenarios

**Scenario 1:** localStorage.removeItem() throws error during clearDraft()
- **Result:** Draft might remain in localStorage, but message WAS sent successfully
- **Impact:** Minor UX issue (draft not cleared), no data loss
- **Handled:** safeLocalStorage catches and logs error

**Scenario 2:** Rapid typing + immediate send (debounce still pending)
- **Result:** Message sent from component state, debounce cancelled, no double-save
- **Impact:** None, works as expected

**Scenario 3:** Multiple rapid sends
- **Result:** Each send gets its own component state snapshot, each clearDraft cancels its debounce
- **Impact:** None, works as expected

### Conclusion

**The autosave draft implementation is SAFE for message sending because:**

1. Message content exists in component state when Send is clicked
2. `vscode.postMessage` is called synchronously BEFORE any draft clearing
3. `clearDraft()` cancels pending debounced saves to prevent interference
4. Error handling ensures localStorage issues don't block message sending
5. The implementation is a drop-in replacement with identical semantics

**Recommendation:** Add the explicit "send order verification" test to make this guarantee even more obvious in the test suite.