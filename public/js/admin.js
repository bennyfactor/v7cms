// v7cms Admin Application - Alpine.js Component
function cmsApp() {
    return {
        loading: true,
        authenticated: false,
        user: {},
        currentView: 'posts',
        posts: [],
        editingPost: false,
        currentPost: {},
        savingPost: false,
        quillEditor: null,
        pages: [],
        editingPage: false,
        currentPage: {},
        savingPage: false,
        pageQuillEditor: null,
        settings: {},
        theme: {},
        themeTab: 'colors',
        savingTheme: false,
        previewPage: '/',
        previewUrl: '',
        previewDebounceTimer: null,

        async init() {
            try {
                const response = await fetch('/api/auth/me');
                const data = await response.json();
                if (data.logged_in) {
                    this.authenticated = true;
                    this.user = data.user;
                    await Promise.all([this.loadPosts(), this.loadPages(), this.loadSettings(), this.loadTheme()]);
                }
            } catch (error) {
                console.error('Initialization error:', error);
            } finally {
                this.loading = false;
            }
        },

        async logout() {
            try {
                await fetch('/api/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json' } });
                window.location.href = '/admin/';
            } catch (error) {
                console.error('Logout error:', error);
            }
        },

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
                alert('Theme reset');
                this.loadPreview();
            } catch (error) {
                console.error('Error resetting theme:', error);
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

        async loadPosts() { const r = await fetch('/api/posts?include_drafts=true'); this.posts = (await r.json()).posts || []; },
        async loadPages() { const r = await fetch('/api/pages?include_drafts=true'); this.pages = (await r.json()).pages || []; },
        async loadSettings() { const r = await fetch('/api/settings'); this.settings = (await r.json()).settings || {}; },
    };
}