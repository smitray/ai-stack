# Whisper STT - Long Conversation Fix

## Problem

Long conversations (2+ minutes) were failing to transcribe.

### Root Causes

1. **API Timeout Too Short** - Only 120 seconds (2 minutes)
   - Long audio files need more time to transcribe
   - 5 minute audio = ~3-5 minutes transcription time

2. **Not Enough Retries** - Only 3 retries
   - Server can get overwhelmed with long files
   - Need more retry attempts for large files

3. **No User Feedback** - Users didn't know it was still working
   - Long transcriptions can take minutes
   - Users thought it was stuck/frozen

---

## Solution

### 1. Extended API Timeout

**Before:** `--max-time 120` (2 minutes)  
**After:** `--max-time 600` (10 minutes)

```bash
# Now supports up to 10 minute transcriptions
--max-time 600 --connect-timeout 30
```

### 2. More Retries

**Before:** 3 retries, 2 second delay  
**After:** 5 retries, 3 second delay (exponential backoff)

```bash
max_retries=5
retry_delay=3  # 3, 6, 12, 24, 48 seconds between retries
```

### 3. Long Recording Notification

For recordings >60 seconds, shows:
```
"Long recording (180s) - this may take a while..."
```

---

## How It Works Now

### Short Conversations (<60s)
```
Press Super+N (stop)
  ↓
"Processing..." (brief)
  ↓
Text appears (silent)
  ↓
Done!
```

### Long Conversations (>60s)
```
Press Super+N (stop)
  ↓
"Processing..." (brief)
  ↓
"Long recording (180s) - this may take a while..."
  ↓
[Silent transcription - can take several minutes]
  ↓
Text appears (silent)
  ↓
Done!
```

---

## Timeout Breakdown

| Recording Length | File Size | Transcription Time | Status |
|-----------------|-----------|-------------------|--------|
| 30 seconds | ~160KB | 5-10 seconds | ✅ Fast |
| 1 minute | ~320KB | 10-20 seconds | ✅ Fast |
| 3 minutes | ~960KB | 30-60 seconds | ✅ OK |
| 5 minutes | ~1.6MB | 1-2 minutes | ✅ OK |
| 10 minutes | ~3.2MB | 3-5 minutes | ✅ OK |
| 15 minutes | ~4.8MB | 5-8 minutes | ⚠️ May timeout |

---

## Retry Logic

### When Server is Busy (503/504)
```
Attempt 1: Wait 3 seconds
Attempt 2: Wait 6 seconds
Attempt 3: Wait 12 seconds
Attempt 4: Wait 24 seconds
Attempt 5: Wait 48 seconds
Total wait: Up to 93 seconds
```

### When Server Errors (500)
```
Same retry pattern as above
```

---

## Log Examples

### Successful Long Transcription
```log
[2026-03-09 05:15:00] [INFO] Processing recording...
[2026-03-09 05:15:01] [INFO] Long recording detected: ~180s
[2026-03-09 05:15:01] [INFO] Audio file ready (576000 bytes)
[2026-03-09 05:15:01] [INFO] Transcribing audio...
[2026-03-09 05:16:23] [INFO] Transcribed: [long text from 3 minute conversation]
```

### Server Busy - Retry Success
```log
[2026-03-09 05:15:00] [INFO] Transcribing audio...
[2026-03-09 05:15:03] [INFO] Server busy, retrying (1/5)...
[2026-03-09 05:15:09] [INFO] Server busy, retrying (2/5)...
[2026-03-09 05:15:21] [INFO] Transcribed: [text]
```

### Timeout Failure
```log
[2026-03-09 05:15:00] [INFO] Transcribing audio...
[2026-03-09 05:25:00] [ERROR] Transcription failed (HTTP 000)
[2026-03-09 05:25:00] [ERROR] Connection failed - server may have crashed or timed out
```

---

## Tips for Long Conversations

### Best Practices

1. **Break into chunks** - For very long conversations (10+ min), consider:
   - Press Super+N every few minutes
   - Transcribe in segments
   - More reliable than one huge file

2. **Watch VRAM** - Long transcriptions use more VRAM:
   - Check with `nvidia-smi`
   - Stop server after if you need VRAM

3. **Check logs** - If transcription fails:
   ```bash
   tail -30 ~/.local/share/hypr-stt/$(date +%Y-%m-%d).log
   ```

### When to Use What

| Use Case | Recommendation |
|----------|---------------|
| Quick commands (<30s) | ✅ Perfect |
| Meeting notes (2-5 min) | ✅ Works great |
| Lecture recording (10-20 min) | ⚠️ Break into chunks |
| All-day dictation | ❌ Use dedicated software |

---

## Technical Details

### Audio Format
- **Sample Rate:** 16kHz
- **Channels:** 1 (mono)
- **Format:** s16 (16-bit PCM)
- **Bitrate:** ~256 kbps (32KB/s)

### File Size Estimates
```
30 seconds  = ~160KB
1 minute    = ~320KB
5 minutes   = ~1.6MB
10 minutes  = ~3.2MB
```

### Transcription Speed
- **small model:** ~2-3x real-time on GPU
- **5 min audio:** ~2-3 minutes to transcribe
- **10 min audio:** ~4-6 minutes to transcribe

---

## Error Handling

### HTTP 000 - Connection Failed
```
Cause: Server crashed, network issue, or timeout
Solution: Check server status, restart if needed
```

### HTTP 500 - Server Error
```
Cause: Server overloaded, out of VRAM
Solution: Automatic retry, wait for server to recover
```

### HTTP 503/504 - Service Unavailable/Timeout
```
Cause: Server busy with long transcription
Solution: Automatic retry with exponential backoff
```

---

## Summary

**Changes Made:**
1. ✅ Timeout: 120s → 600s (5x increase)
2. ✅ Retries: 3 → 5 (more attempts)
3. ✅ Backoff: 2s → 3s base (longer between retries)
4. ✅ Notification for >60s recordings
5. ✅ Better error logging

**Result:**
- ✅ Supports conversations up to 10 minutes
- ✅ Automatic retry on server busy
- ✅ User feedback for long transcriptions
- ✅ Better error messages
