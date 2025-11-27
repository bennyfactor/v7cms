function cmsApp() {
  return {
    // State
    loading: true,
    authenticated: false,
    user: {},
    currentView: 'posts',

    // Posts
    posts: [],
    editingPost: false,
    currentPost: {},
    saving: false,
    quillInstance: null,

    // Pages
    pages: [],
    editingPage: false,
    currentPage: {},
    savingPage: false,
    quillPageInstance: null,

    // Theme
    theme: {},
    themeTab: 'colors',
    savingTheme: false,
    previewPage: '/',
    previewUrl: '/',

    // Settings
    settings: {},
    savingSettings: false,

    // Comments
    comments: [],
    pendingCommentCount: 0,
    commentFilter: 'pending',

    // Validation
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

    // Computed
    get validationSummaryErrors() {
      const errors = [];
      const formType = this.editingPost ? 'post' : this.editingPage ? 'page' : 'settings';
      const errorObj = this.validationErrors[formType];
      const fieldLabels = {
        title: 'Title',
        slug: 'Slug',
        content: 'Content',
        site_title: 'Site Title',
        welcome_title: 'Welcome Title',
        contact_email: 'Contact Email',
        github_url: 'GitHub URL',
        social_url: 'Social URL',
        posts_per_page: 'Posts Per Page'
      };

      for (const [field, message] of Object.entries(errorObj)) {
        if (message) {
          errors.push({
            field,
            label: fieldLabels[field] || field,
            message
          });
        }
      }
      return errors;
    },

    get filteredComments() {
      switch (this.commentFilter) {
        case 'pending':
          return this.comments.filter(c => !c.approved && !c.spam);
        case 'approved':
          return this.comments.filter(c => c.approved);
        case 'spam':
          return this.comments.filter(c => c.spam);
        default:
          return this.comments;
      }
    },

    // Initialization
    async init() {
      await this.checkAuth();
      if (this.authenticated) {
        await Promise.all([
          this.fetchPosts(),
          this.fetchPages(),
          this.loadSettings(),
          this.fetchTheme(),
          this.fetchComments(),
          this.updatePendingCount()
        ]);

        // Poll for pending count every 60 seconds
        setInterval(() => {
          this.updatePendingCount();
        }, 60000);
      }
      this.loading = false;
    },

    async checkAuth() {
      try {
        const response = await fetch('/api/auth/me', { credentials: 'include' });
        if (response.ok) {
          this.user = await response.json();
          this.authenticated = true;
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      }
    },

    async logout() {
      await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' });
      window.location.reload();
    },

    // Posts
    async fetchPosts() {
      const response = await fetch('/api/posts?include_drafts=true', { credentials: 'include' });
      this.posts = await response.json();
    },

    createNewPost() {
      this.currentPost = { title: '', slug: '', content: '', published: false, comments_enabled: true };
      this.editingPost = true;
      this.resetValidation('post');
      this.$nextTick(() => this.initQuill());
    },

    editPost(post) {
      this.currentPost = { ...post };
      this.editingPost = true;
      this.resetValidation('post');
      this.$nextTick(() => this.initQuill(post.content));
    },

    cancelEdit() {
      this.editingPost = false;
      this.currentPost = {};
      this.resetValidation('post');
      if (this.quillInstance) {
        this.quillInstance = null;
      }
    },

    async savePost() {
      this.markAllTouched('post');
      this.validatePost();

      if (!this.isPostValid()) {
        this.showValidationSummary = true;
        return;
      }

      this.saving = true;
      this.currentPost.content = this.quillInstance.root.innerHTML;

      const method = this.currentPost.id ? 'PUT' : 'POST';
      const url = this.currentPost.id ? `/api/posts/${this.currentPost.id}` : '/api/posts';

      try {
        await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.currentPost)
        });
        await this.fetchPosts();
        this.cancelEdit();
      } catch (error) {
        alert('Failed to save post');
      } finally {
        this.saving = false;
      }
    },

    async deletePost(post) {
      if (!confirm(`Delete "${post.title}"?`)) return;

      await fetch(`/api/posts/${post.id}`, {
        method: 'DELETE',
        credentials: 'include'
      });
      await this.fetchPosts();
    },

    initQuill(content = '') {
      const editor = document.getElementById('editor');
      if (editor && !this.quillInstance) {
        this.quillInstance = new Quill('#editor', {
          theme: 'snow',
          placeholder: 'Write your post content...',
          modules: {
            toolbar: [
              ['bold', 'italic', 'underline', 'strike'],
              ['blockquote', 'code-block'],
              [{ 'header': 1 }, { 'header': 2 }],
              [{ 'list': 'ordered'}, { 'list': 'bullet' }],
              [{ 'script': 'sub'}, { 'script': 'super' }],
              [{ 'indent': '-1'}, { 'indent': '+1' }],
              ['link', 'image'],
              ['clean']
            ]
          }
        });
        this.quillInstance.root.innerHTML = content;

        // Track content changes for validation
        this.quillInstance.on('text-change', () => {
          if (this.touchedFields.post.has('content')) {
            this.validatePost();
          }
        });

        // Mark content as touched on first edit
        this.quillInstance.once('text-change', () => {
          this.markTouched('post', 'content');
        });
      }
    },

    // Pages
    async fetchPages() {
      const response = await fetch('/api/pages?include_drafts=true', { credentials: 'include' });
      this.pages = await response.json();
    },

    createNewPage() {
      this.currentPage = { title: '', slug: '', content: '', parent_id: null, page_type: 'standard', position: 0, published: false };
      this.editingPage = true;
      this.resetValidation('page');
      this.$nextTick(() => this.initPageQuill());
    },

    editPage(page) {
      this.currentPage = { ...page };
      this.editingPage = true;
      this.resetValidation('page');
      this.$nextTick(() => this.initPageQuill(page.content));
    },

    cancelPageEdit() {
      this.editingPage = false;
      this.currentPage = {};
      this.resetValidation('page');
      if (this.quillPageInstance) {
        this.quillPageInstance = null;
      }
    },

    async savePage() {
      this.markAllTouched('page');
      this.validatePage();

      if (!this.isPageValid()) {
        this.showValidationSummary = true;
        return;
      }

      this.savingPage = true;
      this.currentPage.content = this.quillPageInstance.root.innerHTML;

      const method = this.currentPage.id ? 'PUT' : 'POST';
      const url = this.currentPage.id ? `/api/pages/${this.currentPage.id}` : '/api/pages';

      try {
        await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.currentPage)
        });
        await this.fetchPages();
        this.cancelPageEdit();
      } catch (error) {
        alert('Failed to save page');
      } finally {
        this.savingPage = false;
      }
    },

    async deletePage(page) {
      if (!confirm(`Delete "${page.title}"?`)) return;

      await fetch(`/api/pages/${page.id}`, {
        method: 'DELETE',
        credentials: 'include'
      });
      await this.fetchPages();
    },

    getPageTitle(id) {
      const page = this.pages.find(p => p.id === id);
      return page ? page.title : 'Unknown';
    },

    initPageQuill(content = '') {
      const editor = document.getElementById('page-editor');
      if (editor && !this.quillPageInstance) {
        this.quillPageInstance = new Quill('#page-editor', {
          theme: 'snow',
          placeholder: 'Write your page content...',
          modules: {
            toolbar: [
              ['bold', 'italic', 'underline', 'strike'],
              ['blockquote', 'code-block'],
              [{ 'header': 1 }, { 'header': 2 }],
              [{ 'list': 'ordered'}, { 'list': 'bullet' }],
              [{ 'script': 'sub'}, { 'script': 'super' }],
              [{ 'indent': '-1'}, { 'indent': '+1' }],
              ['link', 'image'],
              ['clean']
            ]
          }
        });
        this.quillPageInstance.root.innerHTML = content;

        // Track content changes for validation
        this.quillPageInstance.on('text-change', () => {
          if (this.touchedFields.page.has('content')) {
            this.validatePage();
          }
        });

        // Mark content as touched on first edit
        this.quillPageInstance.once('text-change', () => {
          this.markTouched('page', 'content');
        });
      }
    },

    // Theme
    async fetchTheme() {
      const response = await fetch('/api/theme');
      this.theme = await response.json();
      this.loadPreview();
    },

    async saveTheme() {
      this.savingTheme = true;
      try {
        await fetch('/api/theme', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.theme)
        });
        alert('Theme saved successfully!');
      } catch (error) {
        alert('Failed to save theme');
      } finally {
        this.savingTheme = false;
      }
    },

    async resetTheme() {
      if (!confirm('Reset theme to defaults? This will discard all customizations.')) return;

      await fetch('/api/theme/reset', {
        method: 'POST',
        credentials: 'include'
      });
      await this.fetchTheme();
    },

    updatePreview() {
      clearTimeout(this.previewDebounce);
      this.previewDebounce = setTimeout(() => {
        this.loadPreview();
      }, 500);
    },

    loadPreview() {
      const params = new URLSearchParams();
      for (const [key, value] of Object.entries(this.theme)) {
        if (value) params.append(key, value);
      }
      this.previewUrl = `/api/theme/preview?${params.toString()}&page=${this.previewPage}`;
      const iframe = document.getElementById('theme-preview');
      if (iframe) {
        iframe.src = this.previewUrl;
      }
    },

    validateAndUpdateColor(event, field) {
      const value = event.target.value;
      if (/^#[0-9A-F]{6}$/i.test(value)) {
        this.theme[field] = value;
        this.updatePreview();
      }
    },

    // Settings
    async loadSettings() {
      const response = await fetch('/api/settings');
      this.settings = await response.json();
    },

    async saveSettings() {
      this.markAllTouched('settings');
      this.validateSettings();

      if (!this.isSettingsValid()) {
        this.showValidationSummary = true;
        return;
      }

      this.savingSettings = true;
      try {
        await fetch('/api/settings', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.settings)
        });
        alert('Settings saved successfully!');
      } catch (error) {
        alert('Failed to save settings');
      } finally {
        this.savingSettings = false;
      }
    },

    async resetToDefaults() {
      if (!confirm('Reset all settings to defaults? This cannot be undone.')) return;

      await fetch('/api/settings/reset', {
        method: 'POST',
        credentials: 'include'
      });
      await this.loadSettings();
    },

    // Comments
    async fetchComments() {
      const status = this.commentFilter || '';
      const response = await fetch(`/api/comments?status=${status}`, {
        credentials: 'include'
      });
      const data = await response.json();
      this.comments = data.comments;
      await this.updatePendingCount();
    },

    async updatePendingCount() {
      const response = await fetch('/api/comments/pending_count');
      const data = await response.json();
      this.pendingCommentCount = data.count;
    },

    async approveComment(id) {
      if (!confirm('Approve this comment?')) return;

      await fetch(`/api/comments/${id}/approve`, {
        method: 'PUT',
        credentials: 'include'
      });

      await this.fetchComments();
    },

    async markSpam(id) {
      if (!confirm('Mark this comment as spam?')) return;

      await fetch(`/api/comments/${id}/spam`, {
        method: 'PUT',
        credentials: 'include'
      });

      await this.fetchComments();
    },

    async deleteComment(id) {
      if (!confirm('Delete this comment permanently?\n\nThis action cannot be undone.')) return;

      await fetch(`/api/comments/${id}`, {
        method: 'DELETE',
        credentials: 'include'
      });

      await this.fetchComments();
    },

    // Validation
    markTouched(form, field) {
      this.touchedFields[form].add(field);
    },

    markAllTouched(form) {
      const fields = form === 'post' ? ['title', 'slug', 'content'] :
                     form === 'page' ? ['title', 'slug', 'content'] :
                     ['site_title', 'welcome_title', 'contact_email', 'github_url', 'social_url', 'posts_per_page'];
      fields.forEach(field => this.touchedFields[form].add(field));
    },

    resetValidation(form) {
      this.validationErrors[form] = {};
      this.touchedFields[form].clear();
      this.showValidationSummary = false;
    },

    validatePost() {
      this.validationErrors.post = {};

      if (!this.currentPost.title || this.currentPost.title.trim() === '') {
        this.validationErrors.post.title = 'Title is required';
      }

      if (this.currentPost.slug && !/^[a-z0-9-]+$/.test(this.currentPost.slug)) {
        this.validationErrors.post.slug = 'Slug must contain only lowercase letters, numbers, and hyphens';
      }

      if (this.quillInstance) {
        const content = this.quillInstance.root.innerHTML;
        const text = this.quillInstance.getText().trim();
        if (!text || text === '') {
          this.validationErrors.post.content = 'Content is required';
        }
      }
    },

    validatePage() {
      this.validationErrors.page = {};

      if (!this.currentPage.title || this.currentPage.title.trim() === '') {
        this.validationErrors.page.title = 'Title is required';
      }

      if (this.currentPage.slug && !/^[a-z0-9-]+$/.test(this.currentPage.slug)) {
        this.validationErrors.page.slug = 'Slug must contain only lowercase letters, numbers, and hyphens';
      }

      if (this.quillPageInstance) {
        const content = this.quillPageInstance.root.innerHTML;
        const text = this.quillPageInstance.getText().trim();
        if (!text || text === '') {
          this.validationErrors.page.content = 'Content is required';
        }
      }

      // Check for circular parent reference
      if (this.currentPage.id && this.currentPage.parent_id) {
        if (this.currentPage.parent_id === this.currentPage.id) {
          this.validationErrors.page.parent_id = 'A page cannot be its own parent';
        }
      }
    },

    validateSettings() {
      this.validationErrors.settings = {};

      if (!this.settings.site_title || this.settings.site_title.trim() === '') {
        this.validationErrors.settings.site_title = 'Site title is required';
      }

      if (!this.settings.welcome_title || this.settings.welcome_title.trim() === '') {
        this.validationErrors.settings.welcome_title = 'Welcome title is required';
      }

      if (this.settings.contact_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.settings.contact_email)) {
        this.validationErrors.settings.contact_email = 'Invalid email format';
      }

      if (this.settings.github_url && !/^https?:\/\/.+/.test(this.settings.github_url)) {
        this.validationErrors.settings.github_url = 'Invalid URL format';
      }

      if (this.settings.social_url && !/^https?:\/\/.+/.test(this.settings.social_url)) {
        this.validationErrors.settings.social_url = 'Invalid URL format';
      }

      if (this.settings.posts_per_page && (this.settings.posts_per_page < 1 || this.settings.posts_per_page > 100)) {
        this.validationErrors.settings.posts_per_page = 'Must be between 1 and 100';
      }
    },

    isPostValid() {
      this.validatePost();
      return Object.keys(this.validationErrors.post).length === 0;
    },

    isPageValid() {
      this.validatePage();
      return Object.keys(this.validationErrors.page).length === 0;
    },

    isSettingsValid() {
      this.validateSettings();
      return Object.keys(this.validationErrors.settings).length === 0;
    },

    focusField(field) {
      const input = document.querySelector(`[x-model*="${field}"]`);
      if (input) {
        input.focus();
        input.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    },

    // Utilities
    formatDate(dateString) {
      if (!dateString) return '';
      const date = new Date(dateString);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    }
  };
}
