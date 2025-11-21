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

        async init() {
            await this.checkAuth();
            if (this.authenticated) {
                await Promise.all([this.loadPosts(), this.loadPages(), this.loadSettings()]);
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
                const url = `/api/posts?include_drafts=true&limit=100`;
                const response = await fetch(url);
                const data = await response.json();

                this.posts = data.posts;
                this.pagination = data.pagination;

                // If there are more posts, load them recursively
                if (this.pagination.offset + this.pagination.count < this.pagination.total) {
                    await this.loadMorePosts(this.pagination.offset + this.pagination.limit);
                }
            } catch (error) {
                console.error('Error loading posts:', error);
                alert('Failed to load posts');
            }
        },

        async loadMorePosts(offset) {
            try {
                const url = `/api/posts?include_drafts=true&limit=100&offset=${offset}`;
                const response = await fetch(url);
                const data = await response.json();

                this.posts = [...this.posts, ...data.posts];

                // If there are more, keep loading
                if (offset + data.pagination.count < data.pagination.total) {
                    await this.loadMorePosts(offset + data.pagination.limit);
                }
            } catch (error) {
                console.error('Error loading more posts:', error);
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
            this.saving = true;

            // Get content from Quill
            if (quill) {
                this.currentPost.content = quill.root.innerHTML;
            }

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
            if (!confirm(`Are you sure you want to delete "${post.title}"?`)) {
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

        // Pages Management

        async loadPages() {
            try {
                const url = `/api/pages?include_drafts=true&limit=100`;
                const response = await fetch(url);
                const data = await response.json();

                this.pages = data.pages;

                // If there are more pages, load them recursively
                if (data.pagination.offset + data.pagination.count < data.pagination.total) {
                    await this.loadMorePages(data.pagination.offset + data.pagination.limit);
                }
            } catch (error) {
                console.error('Error loading pages:', error);
                alert('Failed to load pages');
            }
        },

        async loadMorePages(offset) {
            try {
                const url = `/api/pages?include_drafts=true&limit=100&offset=${offset}`;
                const response = await fetch(url);
                const data = await response.json();

                this.pages = [...this.pages, ...data.pages];

                // If there are more, keep loading
                if (offset + data.pagination.count < data.pagination.total) {
                    await this.loadMorePages(offset + data.pagination.limit);
                }
            } catch (error) {
                console.error('Error loading more pages:', error);
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
            this.savingPage = true;

            // Get content from Quill
            if (pageQuill) {
                this.currentPage.content = pageQuill.root.innerHTML;
            }

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
            if (!confirm(`Are you sure you want to delete "${page.title}"?`)) {
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
