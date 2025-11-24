# Admin Form Validation - Testing Checklist

**Feature Branch:** `feature/admin-form-validation`
**Server:** http://localhost:9292
**Admin URL:** http://localhost:9292/admin/

## Prerequisites
- Server running (`docker-compose up`)
- Logged in to admin interface (OAuth)
- JavaScript console open (F12) to check for errors

---

## Posts Form Testing

### ✅ Title Validation
- [ ] Try submitting empty title → should show "Title is required"
- [ ] Type 201 characters → should show "Title must be 200 characters or less"
- [ ] Valid title → should show green border after blur

### ✅ Slug Validation
- [ ] Leave empty (optional field) → should allow submission
- [ ] Enter "My-Post" (uppercase) → should show "Slug must contain only lowercase letters, numbers, and hyphens"
- [ ] Enter "test-post" → should check uniqueness after 1 second
- [ ] Enter existing slug → should show "This slug is already in use"
- [ ] Valid unique slug → should show green border after blur

### ✅ Content Validation
- [ ] Try submitting with empty Quill editor → should show "Content is required"
- [ ] Add content → should show green border on editor div

### ✅ Hybrid Validation Timing
- [ ] Fresh field: Type in title without blur → no errors should appear
- [ ] After blur: Errors should appear immediately
- [ ] After touched: Errors should update in real-time as you type

### ✅ Validation Summary
- [ ] Try submitting form with multiple errors → banner should appear
- [ ] Banner should show error count: "3 error(s) prevent saving"
- [ ] Click error link in banner → should scroll to field and focus it
- [ ] Click X button → banner should dismiss
- [ ] Fix all errors and submit → should save successfully

### ✅ Save Button State
- [ ] With validation errors → button should be disabled and grayed out
- [ ] Fix all errors → button should become enabled
- [ ] After successful save → validation state should clear

---

## Pages Form Testing

### ✅ Basic Validations (Same as Posts)
- [ ] Test title validation (required, max 200)
- [ ] Test slug validation (optional, format, uniqueness)
- [ ] Test content validation (required)

### ✅ Parent Page Validation
- [ ] Select current page as parent → should show "A page cannot be its own parent"
- [ ] Select valid parent → should show green border

### ✅ Validation Flow
- [ ] Test hybrid validation (blur → real-time)
- [ ] Test validation summary banner
- [ ] Test save button disabled state

---

## Settings Form Testing

### ✅ Required Fields
- [ ] Clear site_title → should show "Site title is required"
- [ ] Clear welcome_title → should show "Welcome title is required"
- [ ] Clear date_format → should show "Date format is required"

### ✅ Length Validations
- [ ] site_title: 101 chars → "must be 100 characters or less"
- [ ] site_tagline: 201 chars → "must be 200 characters or less"
- [ ] site_author: 101 chars → "must be 100 characters or less"
- [ ] welcome_title: 201 chars → "must be 200 characters or less"
- [ ] welcome_subtitle: 301 chars → "must be 300 characters or less"
- [ ] footer_text: 301 chars → "must be 300 characters or less"
- [ ] meta_keywords: 501 chars → "must be 500 characters or less"

### ✅ Email Validation
- [ ] Enter "invalid-email" → should show "Invalid email format"
- [ ] Enter "test@example.com" → should show green border

### ✅ URL Validation
- [ ] Enter "not-a-url" in github_url → should show "Invalid URL format"
- [ ] Enter "https://github.com/user" → should show green border
- [ ] Same for social_url

### ✅ Numeric Range
- [ ] Enter 0 in posts_per_page → "Posts per page must be between 1 and 100"
- [ ] Enter 101 → same error
- [ ] Enter "abc" → same error (parseInt validation)
- [ ] Enter 50 → should show green border

### ✅ Validation Summary
- [ ] Submit with 5+ errors → banner should list all errors
- [ ] Click any error link → should jump to that field
- [ ] Fix all errors → should be able to save

---

## Cross-Form Testing

### ✅ State Isolation
- [ ] Create validation errors in Posts form
- [ ] Switch to Pages → should not see Posts errors
- [ ] Switch back to Posts → errors should still be there
- [ ] Create new post → errors should clear

### ✅ Cancel/Create New
- [ ] Open edit with errors → click Cancel → errors should remain
- [ ] Click "New Post" → errors should clear completely
- [ ] Same for Pages

---

## Browser Console Checks

- [ ] No JavaScript errors in console
- [ ] No network errors for slug uniqueness checks
- [ ] Slug uniqueness API calls debounced (only 1 call per second of typing)

---

## Performance Testing

### ✅ Slug Uniqueness
- [ ] Type "test-slug-xyz" rapidly → should only make 1 API call after typing stops
- [ ] Delete and re-type same slug → should use cached result (no API call)
- [ ] Check Network tab: Filter by `/api/posts?slug=` and `/api/pages?slug=`

### ✅ Real-time Validation
- [ ] Validation should feel instant (no lag)
- [ ] Validation summary should update immediately when errors change

---

## Edge Cases

- [ ] Submit form while slug uniqueness check is pending (1 sec debounce)
- [ ] Network error during slug check → should not block saving
- [ ] Very long error messages → should wrap correctly in banner
- [ ] Multiple errors in same field → only latest error should show

---

## Success Criteria

All checkboxes above should pass. The validation should:
1. Prevent invalid data submission
2. Provide immediate, clear feedback
3. Not interfere with normal workflow
4. Handle edge cases gracefully
5. Feel responsive (no lag or flicker)

---

## Known Limitations

- **Async slug validation**: Errors appear 1 second after typing stops (by design)
- **Client-side only**: Backend still validates (defense in depth)
- **Circular page references**: Only direct self-reference checked on client (backend has full validation)

---

## If Tests Fail

1. Check browser console for JavaScript errors
2. Verify server logs: `docker-compose logs web`
3. Check Network tab for failed API requests
4. Verify all commits applied: `git log --oneline | head -15`
5. Restart server: `docker-compose restart web`
