// Alpine.js app for v7cms admin
let quill = null;
let pageQuill = null;

function cmsApp() {
    return {
        loading: true,
        authenticated: false,
        user: {},
        currentView: 'posts',
        posts: [],
        editingPost: false,
        currentPost: {},
        saving: false,
        pages: [],
        editingPage: false,
        currentPage: {},
        savingPage: false,
        settings: {
            site_title: '',
            site_tagline: '',
            site_author: '',
            welcome_title: '',
            welcome_subtitle: '',
            footer_text: '',
            show_copyright_year: true,
            meta_description: '',
            meta_keywords: '',
            contact_email: '',
            github_url: '',
            social_url: '',
            posts_per_page: 10,
            date_format: '%B %d, %Y'
        },
        savingSettings: false,

        // Validation state
        validationErrors: {
            post: {},
            page: {},
            settings: {}
        },
        touchedFields: {
            post: new Set(),
            page: new Set(),
            settings: new Set()
        },
        showValidationSummary: false,
        validationSummaryErrors: [],
        slugCheckTimeout: null,
        slugCheckCache: {},
        theme: {},
        themeTab: 'colors',
        savingTheme: false,
        previewPage: '/',
        previewUrl: '',
        previewDebounceTimer: null,

        async init() {
            await this.checkAuth();
            if (this.authenticated) {
                await Promise.all([this.loadPosts(), this.loadPages(), this.loadSettings(), this.loadTheme()]);
                this.loading = false;
            } else {
                this.loading = false;
            }
        },

        async checkAuth() {
            try {
                const response = await fetch('/api/auth/me');
                const data = await response.json();

                if (data.logged_in) {
                    this.authenticated = true;
                    this.user = data.user;
                } else {
                    this.authenticated = false;
                }
            } catch (error) {
                console.error('Auth check failed:', error);
                this.authenticated = false;
            }
        },

        async loadPosts() {
            try {
                const response = await fetch('/api/posts?include_drafts=true');
                const data = await response.json();
                this.posts = data.posts;
            } catch (error) {
                console.error('Failed to load posts:', error);
                alert('Failed to load posts');
            }
        },

        createNewPost() {
            this.currentPost = {
                title: '',
                slug: '',
                content: '',
                published: false
            };
            this.editingPost = true;
            // Clear any previous validation state
            this.clearValidationState('post');

            // Initialize Quill editor
            this.$nextTick(() => {
                this.initQuill();
            });
        },

        editPost(post) {
            this.currentPost = { ...post };
            this.editingPost = true;

            // Initialize Quill editor with content
            this.$nextTick(() => {
                this.initQuill(post.content);
            });
        },

        initQuill(content = '') {
            if (quill) {
                quill = null;
            }

            quill = new Quill('#editor', {
                theme: 'snow',
                modules: {
                    toolbar: [
                        [{ 'header': [1, 2, 3, false] }],
                        ['bold', 'italic', 'underline', 'strike'],
                        ['blockquote', 'code-block'],
                        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                        [{ 'script': 'sub'}, { 'script': 'super' }],
                        [{ 'indent': '-1'}, { 'indent': '+1' }],
                        ['link', 'image'],
                        ['clean']
                    ]
                }
            });

            if (content) {
                quill.root.innerHTML = content;
            }
        },

        async savePost() {
            // Get content from Quill before validation
            if (quill) {
                this.currentPost.content = quill.root.innerHTML;
            }

            // Validate all fields and show summary
            this.showValidationSummary = true;
            const isValid = this.validatePost();
            this.updateValidationSummary('post');

            if (!isValid) {
                // Scroll to first error
                this.scrollToFirstError();
                return;
            }

            this.saving = true;

            try {
                const method = this.currentPost.id ? 'PUT' : 'POST';
                const url = this.currentPost.id
                    ? `/api/posts/${this.currentPost.id}`
                    : '/api/posts';

                const response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify({
                        title: this.currentPost.title,
                        slug: this.currentPost.slug || undefined,
                        content: this.currentPost.content,
                        published: this.currentPost.published
                    })
                });

                if (response.ok) {
                    await this.loadPosts();
                    this.editingPost = false;
                    this.currentPost = {};
                    quill = null;
                    // Clear validation state on success
                    this.clearValidationState('post');
                } else {
                    const error = await response.json();
                    alert('Error: ' + (error.errors ? error.errors.join(', ') : error.error));
                }
            } catch (error) {
                console.error('Failed to save post:', error);
                alert('Failed to save post');
            } finally {
                this.saving = false;
            }
        },

        cancelEdit() {
            this.editingPost = false;
            this.currentPost = {};
            quill = null;
        },

        async deletePost(post) {
            const confirmed = confirm(
                `Are you sure you want to delete "${post.title}"?\n\n` +
                `This action cannot be undone.`
            );

            if (!confirmed) {
                return;
            }

            try {
                const response = await fetch(`/api/posts/${post.id}`, {
                    method: 'DELETE',
                    headers: {
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });

                if (response.ok || response.status === 204) {
                    await this.loadPosts();
                } else {
                    alert('Failed to delete post');
                }
            } catch (error) {
                console.error('Failed to delete post:', error);
                alert('Failed to delete post');
            }
        },

        async logout() {
            try {
                await fetch('/api/auth/logout', { method: 'POST' });
                window.location.reload();
            } catch (error) {
                console.error('Logout failed:', error);
            }
        },

        formatDate(dateString) {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        },

        async loadSettings() {
            try {
                const response = await fetch('/api/settings');
                const data = await response.json();
                this.settings = data.settings;
            } catch (error) {
                console.error('Error loading settings:', error);
                alert('Failed to load settings');
            }
        },

        async saveSettings() {
            if (this.savingSettings) return;

            // Validate all fields and show summary
            this.showValidationSummary = true;
            const isValid = this.validateSettings();
            this.updateValidationSummary('settings');

            if (!isValid) {
                // Scroll to first error
                this.scrollToFirstError();
                return;
            }

            this.savingSettings = true;
            try {
                const response = await fetch('/api/settings', {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(this.settings)
                });

                if (response.ok) {
                    const data = await response.json();
                    this.settings = data.settings;
                    alert('Settings saved successfully!');
                    // Clear validation state on success
                    this.clearValidationState('settings');
                } else {
                    const data = await response.json();
                    alert('Failed to save settings: ' + (data.errors ? data.errors.join(', ') : 'Unknown error'));
                }
            } catch (error) {
                console.error('Error saving settings:', error);
                alert('Failed to save settings');
            } finally {
                this.savingSettings = false;
            }
        },

        async resetToDefaults() {
            if (!confirm('Are you sure you want to reset all settings to defaults? This cannot be undone.')) {
                return;
            }

            try {
                const response = await fetch('/api/settings/reset', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

                if (response.ok) {
                    const data = await response.json();
                    this.settings = data.settings;
                    alert('Settings reset to defaults successfully!');
                } else {
                    throw new Error('Failed to reset settings');
                }
            } catch (error) {
                console.error('Error resetting settings:', error);
                alert('Failed to reset settings');
            }
        },

        // Theme Management

        async loadTheme() {
            try {
                const response = await fetch('/api/theme');
                const data = await response.json();
                this.theme = data.theme || {};
                this.loadPreview();
            } catch (error) {
                console.error('Error loading theme:', error);
            }
        },

        async saveTheme() {
            this.savingTheme = true;
            try {
                const response = await fetch('/api/theme', {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.theme)
                });
                if (!response.ok) {
                    const error = await response.json();
                    alert('Error saving theme: ' + (error.errors ? error.errors.join(', ') : 'Unknown error'));
                    return;
                }
                const data = await response.json();
                this.theme = data.theme;
                alert('Theme saved successfully!');
                this.loadPreview();
            } catch (error) {
                console.error('Error saving theme:', error);
                alert('Error saving theme');
            } finally {
                this.savingTheme = false;
            }
        },

        async resetTheme() {
            if (!confirm('Reset theme to defaults?')) return;
            try {
                const response = await fetch('/api/theme/reset', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' }
                });
                const data = await response.json();
                this.theme = data.theme;
                alert('Theme reset to defaults successfully!');
                this.loadPreview();
            } catch (error) {
                console.error('Error resetting theme:', error);
                alert('Failed to reset theme');
            }
        },

        validateAndUpdateColor(event, field) {
            const value = event.target.value.trim();
            const hexPattern = /^#([0-9A-Fa-f]{3}){1,2}$/;

            // If valid hex color, update and trigger preview
            if (hexPattern.test(value)) {
                this.theme[field] = value.toLowerCase();
                event.target.classList.remove('border-red-500');
                this.updatePreview();
            } else {
                // Show validation error with red border
                event.target.classList.add('border-red-500');
            }
        },

        updatePreview() {
            clearTimeout(this.previewDebounceTimer);
            this.previewDebounceTimer = setTimeout(() => this.loadPreview(), 500);
        },

        loadPreview() {
            const params = new URLSearchParams();
            Object.keys(this.theme).forEach(key => {
                if (key !== 'id' && this.theme[key] != null) params.set(key, this.theme[key]);
            });
            // Add timestamp to force iframe reload
            params.set('_t', Date.now());
            this.previewUrl = `${this.previewPage}?theme_preview=1&${params.toString()}`;
        },

        // Validation Helper Methods

        validateEmail(email) {
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            return emailRegex.test(email);
        },

        validateUrl(url) {
            try {
                new URL(url);
                return true;
            } catch {
                return false;
            }
        },

        markTouched(formType, fieldName) {
            this.touchedFields[formType].add(fieldName);
        },

        clearSlugCache() {
            this.slugCheckCache = {};
        },

        async checkSlugUniqueness(type, slug, currentId) {
            // Clear existing timeout
            clearTimeout(this.slugCheckTimeout);

            // Check cache first
            const cacheKey = `${type}-${slug}`;
            if (this.slugCheckCache[cacheKey] !== undefined) {
                return this.slugCheckCache[cacheKey];
            }

            // Debounce: wait 1000ms (1 second) after user stops typing
            this.slugCheckTimeout = setTimeout(async () => {
                try {
                    const endpoint = type === 'post' ? '/api/posts' : '/api/pages';
                    const response = await fetch(`${endpoint}?slug=${encodeURIComponent(slug)}`);
                    if (!response.ok) {
                        console.error('Slug uniqueness check failed:', response.status);
                        return; // Don't block on API errors
                    }
                    const data = await response.json();

                    // Check if slug exists and belongs to different item
                    const items = data.posts || data.pages;
                    const exists = items.some(item =>
                        item.slug === slug && item.id !== currentId
                    );

                    if (exists) {
                        this.validationErrors[type].slug = 'This slug is already in use';
                    } else {
                        // Clear slug error if it was about uniqueness
                        if (this.validationErrors[type].slug === 'This slug is already in use') {
                            delete this.validationErrors[type].slug;
                        }
                    }

                    // Cache the result
                    this.slugCheckCache[cacheKey] = !exists;
                    this.updateValidationSummary(type);

                } catch (error) {
                    console.error('Error checking slug uniqueness:', error);
                    // Don't block saving on network error
                }
            }, 1000);
        },

        // Form Validation Methods

        validatePost() {
            const errors = {};

            // Title: required, max 200 chars
            if (!this.currentPost.title?.trim()) {
                errors.title = 'Title is required';
            } else if (this.currentPost.title.length > 200) {
                errors.title = 'Title must be 200 characters or less';
            }

            // Slug: optional, but if provided must be valid format
            if (this.currentPost.slug?.trim()) {
                if (!/^[a-z0-9-]+$/.test(this.currentPost.slug)) {
                    errors.slug = 'Slug must contain only lowercase letters, numbers, and hyphens';
                } else {
                    // Check uniqueness with 1 second debounce
                    this.checkSlugUniqueness('post', this.currentPost.slug, this.currentPost.id);
                }
            }

            // Content: Quill editor not empty
            if (!quill || quill.getText().trim().length === 0) {
                errors.content = 'Content is required';
            }

            this.validationErrors.post = errors;
            return Object.keys(errors).length === 0;
        },

        isPostValid() {
            return Object.keys(this.validationErrors.post).length === 0;
        },

        validatePage() {
            const errors = {};

            // Title: required, max 200 chars
            if (!this.currentPage.title?.trim()) {
                errors.title = 'Title is required';
            } else if (this.currentPage.title.length > 200) {
                errors.title = 'Title must be 200 characters or less';
            }

            // Slug: optional, but if provided must be valid format
            if (this.currentPage.slug?.trim()) {
                if (!/^[a-z0-9-]+$/.test(this.currentPage.slug)) {
                    errors.slug = 'Slug must contain only lowercase letters, numbers, and hyphens';
                } else {
                    // Check uniqueness with 1 second debounce
                    this.checkSlugUniqueness('page', this.currentPage.slug, this.currentPage.id);
                }
            }

            // Content: Quill editor not empty
            if (!pageQuill || pageQuill.getText().trim().length === 0) {
                errors.content = 'Content is required';
            }

            // Parent validation: ensure not circular
            if (this.currentPage.parent_id && this.currentPage.parent_id === this.currentPage.id) {
                errors.parent_id = 'A page cannot be its own parent';
            }

            this.validationErrors.page = errors;
            return Object.keys(errors).length === 0;
        },

        isPageValid() {
            return Object.keys(this.validationErrors.page).length === 0;
        },

        validateSettings() {
            const errors = {};

            // Required fields
            if (!this.settings.site_title?.trim()) {
                errors.site_title = 'Site title is required';
            } else if (this.settings.site_title.length > 100) {
                errors.site_title = 'Site title must be 100 characters or less';
            }

            if (!this.settings.welcome_title?.trim()) {
                errors.welcome_title = 'Welcome title is required';
            } else if (this.settings.welcome_title.length > 200) {
                errors.welcome_title = 'Welcome title must be 200 characters or less';
            }

            // site_author length check
            if (this.settings.site_author && this.settings.site_author.length > 100) {
                errors.site_author = 'Site author must be 100 characters or less';
            }

            // Email format (optional field)
            if (this.settings.contact_email && !this.validateEmail(this.settings.contact_email)) {
                errors.contact_email = 'Invalid email format';
            }

            // URLs (optional fields)
            if (this.settings.github_url && !this.validateUrl(this.settings.github_url)) {
                errors.github_url = 'Invalid URL format';
            }

            if (this.settings.social_url && !this.validateUrl(this.settings.social_url)) {
                errors.social_url = 'Invalid URL format';
            }

            // Numeric range with type checking
            const postsPerPage = parseInt(this.settings.posts_per_page, 10);
            if (isNaN(postsPerPage) || postsPerPage < 1 || postsPerPage > 100) {
                errors.posts_per_page = 'Posts per page must be between 1 and 100';
            }

            // String length validations
            if (this.settings.site_tagline && this.settings.site_tagline.length > 200) {
                errors.site_tagline = 'Site tagline must be 200 characters or less';
            }

            // meta_keywords length check
            if (this.settings.meta_keywords && this.settings.meta_keywords.length > 500) {
                errors.meta_keywords = 'Meta keywords must be 500 characters or less';
            }

            if (this.settings.welcome_subtitle && this.settings.welcome_subtitle.length > 300) {
                errors.welcome_subtitle = 'Welcome subtitle must be 300 characters or less';
            }

            if (this.settings.footer_text && this.settings.footer_text.length > 300) {
                errors.footer_text = 'Footer text must be 300 characters or less';
            }

            // date_format required check
            if (!this.settings.date_format?.trim()) {
                errors.date_format = 'Date format is required';
            }

            this.validationErrors.settings = errors;
            return Object.keys(errors).length === 0;
        },

        isSettingsValid() {
            return Object.keys(this.validationErrors.settings).length === 0;
        },

        // Validation Summary Methods

        updateValidationSummary(formType) {
            const errors = this.validationErrors[formType];
            const labels = {
                title: 'Title',
                slug: 'Slug',
                content: 'Content',
                parent_id: 'Parent Page',
                site_title: 'Site Title',
                site_tagline: 'Site Tagline',
                site_author: 'Site Author',
                welcome_title: 'Welcome Title',
                welcome_subtitle: 'Welcome Subtitle',
                footer_text: 'Footer Text',
                contact_email: 'Contact Email',
                github_url: 'GitHub URL',
                social_url: 'Social URL',
                posts_per_page: 'Posts Per Page',
                meta_keywords: 'Meta Keywords',
                date_format: 'Date Format'
            };

            this.validationSummaryErrors = Object.entries(errors).map(([field, message]) => ({
                field: `${formType}-${field}`,
                label: labels[field] || field,
                message
            }));
        },

        clearValidationState(formType) {
            this.validationErrors[formType] = {};
            this.touchedFields[formType].clear();
            this.validationSummaryErrors = [];
            this.showValidationSummary = false;
            this.clearSlugCache();
        },

        scrollToFirstError() {
            if (this.validationSummaryErrors.length > 0) {
                const firstError = this.validationSummaryErrors[0];
                const fieldName = firstError.field.split('-').pop();
                const element = document.querySelector(`[x-model*="${fieldName}"]`);
                element?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                element?.focus();
            }
        },

        focusField(fieldId) {
            const fieldName = fieldId.split('-').pop();
            const element = document.querySelector(`[x-model*="${fieldName}"]`);
            element?.scrollIntoView({ behavior: 'smooth', block: 'center' });
            element?.focus();
        },

        // Pages Management

        async loadPages() {
            try {
                const response = await fetch('/api/pages?include_drafts=true');
                const data = await response.json();
                this.pages = data.pages;
            } catch (error) {
                console.error('Failed to load pages:', error);
                alert('Failed to load pages');
            }
        },

        createNewPage() {
            this.currentPage = {
                title: '',
                slug: '',
                content: '',
                parent_id: '',
                position: 0,
                page_type: 'standard',
                published: false
            };
            this.editingPage = true;
            // Clear any previous validation state
            this.clearValidationState('page');

            // Initialize Quill editor for pages
            this.$nextTick(() => {
                this.initPageQuill();
            });
        },

        editPage(page) {
            this.currentPage = { ...page };
            this.editingPage = true;

            // Initialize Quill editor with content
            this.$nextTick(() => {
                this.initPageQuill(page.content);
            });
        },

        initPageQuill(content = '') {
            if (pageQuill) {
                pageQuill = null;
            }

            pageQuill = new Quill('#page-editor', {
                theme: 'snow',
                modules: {
                    toolbar: [
                        [{ 'header': [1, 2, 3, false] }],
                        ['bold', 'italic', 'underline', 'strike'],
                        ['blockquote', 'code-block'],
                        [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                        [{ 'script': 'sub'}, { 'script': 'super' }],
                        [{ 'indent': '-1'}, { 'indent': '+1' }],
                        ['link', 'image'],
                        ['clean']
                    ]
                }
            });

            if (content) {
                pageQuill.root.innerHTML = content;
            }
        },

        async savePage() {
            // Get content from Quill before validation
            if (pageQuill) {
                this.currentPage.content = pageQuill.root.innerHTML;
            }

            // Validate all fields and show summary
            this.showValidationSummary = true;
            const isValid = this.validatePage();
            this.updateValidationSummary('page');

            if (!isValid) {
                // Scroll to first error
                this.scrollToFirstError();
                return;
            }

            this.savingPage = true;

            try {
                const method = this.currentPage.id ? 'PUT' : 'POST';
                const url = this.currentPage.id
                    ? `/api/pages/${this.currentPage.id}`
                    : '/api/pages';

                const response = await fetch(url, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    },
                    body: JSON.stringify({
                        title: this.currentPage.title,
                        slug: this.currentPage.slug || undefined,
                        content: this.currentPage.content,
                        parent_id: this.currentPage.parent_id || null,
                        position: this.currentPage.position,
                        page_type: this.currentPage.page_type,
                        published: this.currentPage.published
                    })
                });

                if (response.ok) {
                    await this.loadPages();
                    this.editingPage = false;
                    this.currentPage = {};
                    pageQuill = null;
                    // Clear validation state on success
                    this.clearValidationState('page');
                } else {
                    const error = await response.json();
                    alert('Error: ' + (error.errors ? error.errors.join(', ') : error.error));
                }
            } catch (error) {
                console.error('Failed to save page:', error);
                alert('Failed to save page');
            } finally {
                this.savingPage = false;
            }
        },

        cancelPageEdit() {
            this.editingPage = false;
            this.currentPage = {};
            pageQuill = null;
        },

        async deletePage(page) {
            // Count child pages
            const childCount = this.pages.filter(p => p.parent_id === page.id).length;

            // Build confirmation message
            let message = `Are you sure you want to delete "${page.title}"?\n\n`;

            if (childCount > 0) {
                message += `WARNING: This page has ${childCount} child page${childCount > 1 ? 's' : ''}.\n`;
                message += `Deleting this page will also permanently delete all ${childCount} child page${childCount > 1 ? 's' : ''}.\n\n`;
            }

            message += `This action cannot be undone.`;

            const confirmed = confirm(message);

            if (!confirmed) {
                return;
            }

            try {
                const response = await fetch(`/api/pages/${page.id}`, {
                    method: 'DELETE',
                    headers: {
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });

                if (response.ok || response.status === 204) {
                    await this.loadPages();
                } else {
                    alert('Failed to delete page');
                }
            } catch (error) {
                console.error('Failed to delete page:', error);
                alert('Failed to delete page');
            }
        },

        getPageTitle(pageId) {
            const page = this.pages.find(p => p.id === pageId);
            return page ? page.title : '';
        }
    };
}
