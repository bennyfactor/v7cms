function cmsApp() {
  return {
    // State
    loading: true,
    authenticated: false,
    user: {},
    currentView: 'posts',

    // Posts
    posts: [],
    postsPagination: { total: 0, loaded: 0, loading: false },
    editingPost: false,
    currentPost: {},
    saving: false,
    quillInstance: null,

    // Pages
    pages: [],
    nestedPages: [],
    expandedPages: {},
    pagesPagination: { total: 0, loaded: 0, loading: false },
    editingPage: false,
    currentPage: {},
    savingPage: false,
    quillPageInstance: null,
    pageTypes: [],

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

    // Users
    users: [],
    togglingUserId: null,

    // Redirects
    redirects: [],
    editingRedirect: null,
    redirectForm: {
      short_path: '',
      target_path: ''
    },

    // Assets
    assets: [],
    assetPage: 1,
    assetPagination: {},
    assetSearch: '',
    assetTypeFilter: '',
    selectedAsset: null,
    uploading: false,

    // Tags
    tags: [],
    newTagName: '',
    postTagSearch: '',
    postTagDropdownOpen: false,

    // Media Library Modal
    showMediaLibrary: false,
    mediaAssets: [],
    mediaSearch: '',
    mediaTypeFilter: 'image',
    selectedMediaAsset: null,
    mediaCallback: null,

    // Image Processing
    imageProcessingAvailable: false,

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

    // Version history
    showVersionHistory: false,
    showAllVersions: false,
    loadingVersions: false,
    permanentVersions: [],
    temporaryVersions: [],
    versionPreview: null,
    versionPreviewType: null,
    versionPreviewId: null,

    // Menus
    menus: [],
    editingMenu: false,
    currentMenu: {},
    savingMenu: false,
    menuItems: [],
    showItemForm: false,
    currentMenuItem: {},
    menuItemTargetBlank: false,

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

    get flattenedPages() {
      if (this.nestedPages.length === 0) {
        // Fall back to flat pages list (unauthenticated)
        return this.pages.map(p => ({ ...p, depth: 0, children: [] }));
      }
      const result = [];
      const flatten = (pages) => {
        for (const page of pages) {
          result.push(page);
          if (page.children && page.children.length > 0 && this.expandedPages[page.id]) {
            flatten(page.children);
          }
        }
      };
      flatten(this.nestedPages);
      return result;
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
      if (this.authenticated && this.user.admin) {
        await Promise.all([
          this.fetchPosts(),
          this.fetchPages(),
          this.loadPageTypes(),
          this.loadSettings(),
          this.fetchTheme(),
          this.fetchComments(),
          this.updatePendingCount(),
          this.fetchRedirects(),
          this.checkImageProcessing(),
          this.loadTags(),
          this.fetchMenus()
        ]);

        // Poll for pending count every 60 seconds
        setInterval(() => {
          this.updatePendingCount();
        }, 60000);

        // Clean up Quill editors when navigating away via sidebar
        this.$watch('currentView', () => {
          if (this.editingPost) this.cancelEdit();
          if (this.editingPage) this.cancelPageEdit();
        });
      }
      this.loading = false;
    },

    async checkAuth() {
      try {
        const response = await fetch('/api/auth/me', { credentials: 'include' });
        if (response.ok) {
          const data = await response.json();
          this.user = data.user || {};
          this.authenticated = data.logged_in === true;
        } else {
          console.error('Auth check failed:', response.status, response.statusText);
          this.authenticated = false;
          this.user = {};
        }
      } catch (error) {
        console.error('Auth check failed:', error);
        this.authenticated = false;
        this.user = {};
      }
    },

    async logout() {
      try {
        await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' });
      } catch (error) {
        console.error('Error during logout:', error);
      } finally {
        window.location.reload();
      }
    },

    // Posts
    async fetchPosts(loadMore = false) {
      try {
        if (loadMore) {
          this.postsPagination.loading = true;
        }

        const offset = loadMore ? this.posts.length : 0;
        const response = await fetch(`/api/posts?include_drafts=true&limit=20&offset=${offset}`, { credentials: 'include' });
        if (!response.ok) {
          console.error('Failed to fetch posts:', response.status, response.statusText);
          if (!loadMore) {
            this.posts = [];
            this.postsPagination = { total: 0, loaded: 0, loading: false };
          }
          return;
        }
        const data = await response.json();

        if (loadMore) {
          this.posts = [...this.posts, ...(data.posts || [])];
        } else {
          this.posts = data.posts || [];
        }

        this.postsPagination = {
          total: data.pagination?.total || this.posts.length,
          loaded: this.posts.length,
          loading: false
        };
      } catch (error) {
        console.error('Error fetching posts:', error);
        if (!loadMore) {
          this.posts = [];
          this.postsPagination = { total: 0, loaded: 0, loading: false };
        }
        this.postsPagination.loading = false;
      }
    },

    createNewPost() {
      this.currentPost = { title: '', slug: '', content: '', status: 'draft', published: false, comments_enabled: true, tag_ids: [], tags: [] };
      this.editingPost = true;
      this.resetValidation('post');
      this.$nextTick(() => this.initQuill());
    },

    editPost(post) {
      this.currentPost = { ...post };
      this.currentPost.tags = post.tags || [];
      this.currentPost.tag_ids = (post.tags || []).map(t => t.id);
      this.editingPost = true;
      this.resetValidation('post');
      this.$nextTick(() => this.initQuill(post.content));
    },

    cancelEdit() {
      this.destroyQuill('quillInstance', 'editor');
      this.editingPost = false;
      this.currentPost = {};
      this.resetValidation('post');
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
      this.currentPost.tag_ids = this.currentPost.tag_ids || [];

      const method = this.currentPost.id ? 'PUT' : 'POST';
      const url = this.currentPost.id ? `/api/posts/${this.currentPost.id}` : '/api/posts';

      try {
        const response = await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.currentPost)
        });
        if (!response.ok) {
          console.error('Failed to save post:', response.status, response.statusText);
          alert('Failed to save post: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchPosts();
        this.cancelEdit();
      } catch (error) {
        console.error('Error saving post:', error);
        alert('Failed to save post');
      } finally {
        this.saving = false;
      }
    },

    async deletePost(post) {
      if (!confirm(`Delete "${post.title}"?`)) return;

      try {
        const response = await fetch(`/api/posts/${post.id}`, {
          method: 'DELETE',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to delete post:', response.status, response.statusText);
          alert('Failed to delete post: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchPosts();
      } catch (error) {
        console.error('Error deleting post:', error);
        alert('Failed to delete post');
      }
    },

    async markPostReady(id) {
      try {
        const response = await fetch(`/api/posts/${id}/status`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          credentials: 'include',
          body: JSON.stringify({ status: 'ready' })
        });
        if (!response.ok) {
          console.error('Failed to mark post ready:', response.status, response.statusText);
          alert('Failed to mark post ready');
          return;
        }
        const data = await response.json();
        this.currentPost = data.post;
        await this.fetchPosts();
      } catch (error) {
        console.error('Error marking post ready:', error);
        alert('Failed to mark post ready');
      }
    },

    async publishPost(id) {
      try {
        const response = await fetch(`/api/posts/${id}/publish`, {
          method: 'POST',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to publish post:', response.status, response.statusText);
          alert('Failed to publish post');
          return;
        }
        const data = await response.json();
        this.currentPost = data.post;
        await this.fetchPosts();
      } catch (error) {
        console.error('Error publishing post:', error);
        alert('Failed to publish post');
      }
    },

    async unpublishPost(id) {
      if (!confirm('Unpublish this post? It will no longer be visible to the public.')) return;

      try {
        const response = await fetch(`/api/posts/${id}/unpublish`, {
          method: 'POST',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to unpublish post:', response.status, response.statusText);
          alert('Failed to unpublish post');
          return;
        }
        const data = await response.json();
        this.currentPost = data.post;
        await this.fetchPosts();
      } catch (error) {
        console.error('Error unpublishing post:', error);
        alert('Failed to unpublish post');
      }
    },

    destroyQuill(instanceKey, editorId) {
      if (this[instanceKey]) {
        // Remove the toolbar that Quill injected as a sibling
        const editor = document.getElementById(editorId);
        if (editor) {
          const toolbar = editor.parentNode.querySelector('.ql-toolbar');
          if (toolbar) toolbar.remove();
          // Reset editor container to a clean state
          editor.innerHTML = '';
          editor.className = editor.className.replace(/ql-\S+/g, '').trim();
        }
        this[instanceKey] = null;
      }
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

        // Custom image handler to open media library
        this.quillInstance.getModule('toolbar').addHandler('image', () => {
          this.openMediaLibrary((asset) => {
            const range = this.quillInstance.getSelection(true);
            this.quillInstance.insertEmbed(range.index, 'image', asset.url);
          });
        });

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
    async fetchPages(loadMore = false) {
      try {
        if (this.authenticated) {
          // Use nested endpoint for tree view when authenticated
          const response = await fetch('/api/pages?include_drafts=true&nested=true', { credentials: 'include' });
          if (!response.ok) {
            console.error('Failed to fetch pages:', response.status, response.statusText);
            this.nestedPages = [];
            this.pages = [];
            return;
          }
          const data = await response.json();
          this.nestedPages = data.pages || [];
          // Auto-expand top-level pages that have children
          for (const page of this.nestedPages) {
            if (page.children && page.children.length > 0 && this.expandedPages[page.id] === undefined) {
              this.expandedPages[page.id] = true;
            }
          }
          // Also maintain flat pages list for getPageTitle lookups
          this.pages = this.flattenNestedPages(this.nestedPages);
          this.pagesPagination = { total: this.pages.length, loaded: this.pages.length, loading: false };
        } else {
          if (loadMore) {
            this.pagesPagination.loading = true;
          }

          const offset = loadMore ? this.pages.length : 0;
          const response = await fetch(`/api/pages?limit=20&offset=${offset}`, { credentials: 'include' });
          if (!response.ok) {
            console.error('Failed to fetch pages:', response.status, response.statusText);
            if (!loadMore) {
              this.pages = [];
              this.pagesPagination = { total: 0, loaded: 0, loading: false };
            } else {
              this.pagesPagination.loading = false;
            }
            return;
          }
          const data = await response.json();

          if (loadMore) {
            this.pages = [...this.pages, ...(data.pages || [])];
          } else {
            this.pages = data.pages || [];
          }

          this.pagesPagination = {
            total: data.pagination?.total || this.pages.length,
            loaded: this.pages.length,
            loading: false
          };
        }
      } catch (error) {
        console.error('Error fetching pages:', error);
        if (!loadMore) {
          this.pages = [];
          this.nestedPages = [];
          this.pagesPagination = { total: 0, loaded: 0, loading: false };
        }
        this.pagesPagination.loading = false;
      }
    },

    flattenNestedPages(pages) {
      const result = [];
      for (const page of pages) {
        result.push(page);
        if (page.children && page.children.length > 0) {
          result.push(...this.flattenNestedPages(page.children));
        }
      }
      return result;
    },

    togglePageExpanded(pageId) {
      this.expandedPages[pageId] = !this.expandedPages[pageId];
    },

    async loadPageTypes() {
      try {
        const response = await fetch('/api/pages/types');
        if (!response.ok) {
          console.error('Failed to load page types:', response.status, response.statusText);
          return;
        }
        const data = await response.json();
        this.pageTypes = data.types || [];
      } catch (error) {
        console.error('Error loading page types:', error);
      }
    },

    createNewPage() {
      this.currentPage = { title: '', slug: '', content: '', parent_id: null, page_type: 'standard', content_source: 'children', items_limit: 10, position: 0, hero_image_url: '', status: 'draft', published: false, content_filter_tag_id: null };
      this.editingPage = true;
      this.resetValidation('page');
      this.$nextTick(() => this.initPageQuill());
    },

    editPage(page) {
      this.currentPage = { ...page };
      this.currentPage.content_filter_tag_id = page.content_filter_tag_id || null;
      this.editingPage = true;
      this.resetValidation('page');
      this.$nextTick(() => this.initPageQuill(page.content));
    },

    cancelPageEdit() {
      this.destroyQuill('quillPageInstance', 'page-editor');
      this.editingPage = false;
      this.currentPage = {};
      this.resetValidation('page');
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

      // Strip nested tree data before sending to API
      const { children, depth, ...pageData } = this.currentPage;

      try {
        const response = await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(pageData)
        });
        if (!response.ok) {
          console.error('Failed to save page:', response.status, response.statusText);
          alert('Failed to save page: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchPages();
        this.cancelPageEdit();
      } catch (error) {
        console.error('Error saving page:', error);
        alert('Failed to save page');
      } finally {
        this.savingPage = false;
      }
    },

    async deletePage(page) {
      if (!confirm(`Delete "${page.title}"?`)) return;

      try {
        const response = await fetch(`/api/pages/${page.id}`, {
          method: 'DELETE',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to delete page:', response.status, response.statusText);
          alert('Failed to delete page: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchPages();
      } catch (error) {
        console.error('Error deleting page:', error);
        alert('Failed to delete page');
      }
    },

    async markPageReady(id) {
      try {
        const response = await fetch(`/api/pages/${id}/status`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          credentials: 'include',
          body: JSON.stringify({ status: 'ready' })
        });
        if (!response.ok) {
          console.error('Failed to mark page ready:', response.status, response.statusText);
          alert('Failed to mark page ready');
          return;
        }
        const data = await response.json();
        this.currentPage = data.page;
        await this.fetchPages();
      } catch (error) {
        console.error('Error marking page ready:', error);
        alert('Failed to mark page ready');
      }
    },

    async publishPage(id) {
      try {
        const response = await fetch(`/api/pages/${id}/publish`, {
          method: 'POST',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to publish page:', response.status, response.statusText);
          alert('Failed to publish page');
          return;
        }
        const data = await response.json();
        this.currentPage = data.page;
        await this.fetchPages();
      } catch (error) {
        console.error('Error publishing page:', error);
        alert('Failed to publish page');
      }
    },

    async unpublishPage(id) {
      if (!confirm('Unpublish this page? It will no longer be visible to the public.')) return;

      try {
        const response = await fetch(`/api/pages/${id}/unpublish`, {
          method: 'POST',
          headers: { 'X-Requested-With': 'XMLHttpRequest' },
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to unpublish page:', response.status, response.statusText);
          alert('Failed to unpublish page');
          return;
        }
        const data = await response.json();
        this.currentPage = data.page;
        await this.fetchPages();
      } catch (error) {
        console.error('Error unpublishing page:', error);
        alert('Failed to unpublish page');
      }
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

        // Custom image handler to open media library
        this.quillPageInstance.getModule('toolbar').addHandler('image', () => {
          this.openMediaLibrary((asset) => {
            const range = this.quillPageInstance.getSelection(true);
            this.quillPageInstance.insertEmbed(range.index, 'image', asset.url);
          });
        });

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
      try {
        const response = await fetch('/api/theme');
        if (!response.ok) {
          console.error('Failed to fetch theme:', response.status, response.statusText);
          this.theme = {};
          return;
        }
        const data = await response.json();
        this.theme = data.theme || {};
        this.loadPreview();
      } catch (error) {
        console.error('Error fetching theme:', error);
        this.theme = {};
      }
    },

    async saveTheme() {
      this.savingTheme = true;
      try {
        const response = await fetch('/api/theme', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.theme)
        });
        if (!response.ok) {
          console.error('Failed to save theme:', response.status, response.statusText);
          alert('Failed to save theme: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        alert('Theme saved successfully!');
      } catch (error) {
        console.error('Error saving theme:', error);
        alert('Failed to save theme');
      } finally {
        this.savingTheme = false;
      }
    },

    async resetTheme() {
      if (!confirm('Reset theme to defaults? This will discard all customizations.')) return;

      try {
        const response = await fetch('/api/theme/reset', {
          method: 'POST',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to reset theme:', response.status, response.statusText);
          alert('Failed to reset theme: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchTheme();
      } catch (error) {
        console.error('Error resetting theme:', error);
        alert('Failed to reset theme');
      }
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
      try {
        const response = await fetch('/api/settings');
        if (!response.ok) {
          console.error('Failed to load settings:', response.status, response.statusText);
          this.settings = {};
          return;
        }
        const data = await response.json();
        this.settings = data.settings || {};
      } catch (error) {
        console.error('Error loading settings:', error);
        this.settings = {};
      }
    },

    async checkImageProcessing() {
      const response = await fetch('/api/assets/capabilities');
      if (response.ok) {
        const data = await response.json();
        this.imageProcessingAvailable = data.image_processing;
      }
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
        const response = await fetch('/api/settings', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify(this.settings)
        });
        if (!response.ok) {
          console.error('Failed to save settings:', response.status, response.statusText);
          alert('Failed to save settings: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        alert('Settings saved successfully!');
      } catch (error) {
        console.error('Error saving settings:', error);
        alert('Failed to save settings');
      } finally {
        this.savingSettings = false;
      }
    },

    async resetToDefaults() {
      if (!confirm('Reset all settings to defaults? This cannot be undone.')) return;

      try {
        const response = await fetch('/api/settings/reset', {
          method: 'POST',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to reset settings:', response.status, response.statusText);
          alert('Failed to reset settings: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.loadSettings();
      } catch (error) {
        console.error('Error resetting settings:', error);
        alert('Failed to reset settings');
      }
    },

    // Tags
    async loadTags() {
        try {
            const response = await fetch('/api/tags', { credentials: 'include', headers: { 'X-Requested-With': 'XMLHttpRequest' } });
            const data = await response.json();
            this.tags = data.tags;
        } catch (error) {
            console.error('Failed to load tags:', error);
        }
    },

    async createTag() {
        if (!this.newTagName.trim()) return;
        try {
            const response = await fetch('/api/tags', {
                method: 'POST',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
                body: JSON.stringify({ name: this.newTagName.trim() })
            });
            if (response.ok) {
                this.newTagName = '';
                await this.loadTags();
            } else {
                const data = await response.json();
                alert(data.errors ? data.errors.join(', ') : 'Failed to create tag');
            }
        } catch (error) {
            console.error('Failed to create tag:', error);
        }
    },

    async renameTag(tag) {
        const newName = prompt('Rename tag:', tag.name);
        if (!newName || newName === tag.name) return;
        try {
            const response = await fetch(`/api/tags/${tag.id}`, {
                method: 'PUT',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
                body: JSON.stringify({ name: newName })
            });
            if (response.ok) {
                await this.loadTags();
            } else {
                const data = await response.json();
                alert(data.errors ? data.errors.join(', ') : 'Failed to rename tag');
            }
        } catch (error) {
            console.error('Failed to rename tag:', error);
        }
    },

    async deleteTag(tag) {
        if (!confirm(`Delete tag "${tag.name}"?`)) return;
        try {
            const response = await fetch(`/api/tags/${tag.id}`, {
                method: 'DELETE',
                credentials: 'include',
                headers: { 'X-Requested-With': 'XMLHttpRequest' }
            });
            if (response.ok) {
                await this.loadTags();
            } else {
                const data = await response.json();
                alert(data.error || 'Failed to delete tag');
            }
        } catch (error) {
            console.error('Failed to delete tag:', error);
        }
    },

    // Comments
    async fetchComments() {
      try {
        const status = this.commentFilter || '';
        const response = await fetch(`/api/comments?status=${status}`, {
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to fetch comments:', response.status, response.statusText);
          this.comments = [];
          return;
        }
        const data = await response.json();
        this.comments = Array.isArray(data.comments) ? data.comments : [];
        await this.updatePendingCount();
      } catch (error) {
        console.error('Error fetching comments:', error);
        this.comments = [];
      }
    },

    async updatePendingCount() {
      try {
        const response = await fetch('/api/comments/pending_count');
        if (!response.ok) {
          console.error('Failed to fetch pending count:', response.status, response.statusText);
          this.pendingCommentCount = 0;
          return;
        }
        const data = await response.json();
        this.pendingCommentCount = typeof data.count === 'number' ? data.count : 0;
      } catch (error) {
        console.error('Error fetching pending count:', error);
        this.pendingCommentCount = 0;
      }
    },

    async approveComment(id) {
      if (!confirm('Approve this comment?')) return;

      try {
        const response = await fetch(`/api/comments/${id}/approve`, {
          method: 'PUT',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to approve comment:', response.status, response.statusText);
          alert('Failed to approve comment: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchComments();
      } catch (error) {
        console.error('Error approving comment:', error);
        alert('Failed to approve comment');
      }
    },

    async markSpam(id) {
      if (!confirm('Mark this comment as spam?')) return;

      try {
        const response = await fetch(`/api/comments/${id}/spam`, {
          method: 'PUT',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to mark comment as spam:', response.status, response.statusText);
          alert('Failed to mark as spam: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchComments();
      } catch (error) {
        console.error('Error marking comment as spam:', error);
        alert('Failed to mark as spam');
      }
    },

    async deleteComment(id) {
      if (!confirm('Delete this comment permanently?\n\nThis action cannot be undone.')) return;

      try {
        const response = await fetch(`/api/comments/${id}`, {
          method: 'DELETE',
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to delete comment:', response.status, response.statusText);
          alert('Failed to delete comment: ' + (response.status === 401 || response.status === 403 ? 'Authentication required' : 'Server error'));
          return;
        }
        await this.fetchComments();
      } catch (error) {
        console.error('Error deleting comment:', error);
        alert('Failed to delete comment');
      }
    },

    // Users
    async fetchUsers() {
      try {
        const response = await fetch('/api/users', {
          credentials: 'include'
        });
        if (!response.ok) {
          console.error('Failed to fetch users:', response.status, response.statusText);
          return;
        }
        const data = await response.json();
        this.users = data.users || [];
      } catch (error) {
        console.error('Error fetching users:', error);
      }
    },

    async toggleUserAdmin(user) {
      const newAdminValue = !user.admin;
      const action = newAdminValue ? 'grant admin access to' : 'revoke admin access from';

      if (!newAdminValue && !confirm(`${action} ${user.name || user.email}?\n\nThis will ${newAdminValue ? 'allow' : 'prevent'} them from accessing the admin panel.`)) {
        return;
      }

      this.togglingUserId = user.id;

      try {
        const response = await fetch(`/api/users/${user.id}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          credentials: 'include',
          body: JSON.stringify({ admin: newAdminValue })
        });

        if (!response.ok) {
          const data = await response.json();
          alert(data.error || 'Failed to update user');
          return;
        }

        const data = await response.json();
        const index = this.users.findIndex(u => u.id === user.id);
        if (index !== -1) {
          this.users[index] = data.user;
        }
      } catch (error) {
        console.error('Error updating user:', error);
        alert('Failed to update user');
      } finally {
        this.togglingUserId = null;
      }
    },

    // Validation

    // Redirects
    async fetchRedirects() {
      try {
        const response = await fetch('/api/redirects', {
          credentials: 'include',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) {
          console.error('Failed to fetch redirects:', response.status, response.statusText);
          this.redirects = [];
          return;
        }

        const data = await response.json();
        this.redirects = data.redirects || [];
      } catch (error) {
        console.error('Error fetching redirects:', error);
        this.redirects = [];
      }
    },

    async createRedirect() {
      if (!this.redirectForm.short_path || !this.redirectForm.target_path) {
        alert('Please fill in both fields');
        return;
      }

      try {
        const response = await fetch('/api/redirects', {
          method: 'POST',
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify({
            short_path: this.redirectForm.short_path,
            target_path: this.redirectForm.target_path
          })
        });

        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.errors ? data.errors.join(', ') : 'Failed to create redirect');
        }

        this.redirects.push(data.redirect);
        this.redirectForm = { short_path: '', target_path: '' };

        alert('Redirect created successfully! .htaccess has been updated.');
      } catch (error) {
        console.error('Error creating redirect:', error);
        alert(error.message || 'Failed to create redirect');
      }
    },

    editRedirect(redirect) {
      this.editingRedirect = { ...redirect };
    },

    cancelEditRedirect() {
      this.editingRedirect = null;
    },

    async updateRedirect(id) {
      if (!this.editingRedirect) return;

      try {
        const response = await fetch(`/api/redirects/${id}`, {
          method: 'PUT',
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify({
            short_path: this.editingRedirect.short_path,
            target_path: this.editingRedirect.target_path
          })
        });

        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.errors ? data.errors.join(', ') : 'Failed to update redirect');
        }

        const index = this.redirects.findIndex(r => r.id === id);
        if (index !== -1) {
          this.redirects[index] = data.redirect;
        }

        this.editingRedirect = null;
        alert('Redirect updated successfully! .htaccess has been updated.');
      } catch (error) {
        console.error('Error updating redirect:', error);
        alert(error.message || 'Failed to update redirect');
      }
    },

    async deleteRedirect(id) {
      if (!confirm('Are you sure you want to delete this redirect? This will update .htaccess immediately.')) {
        return;
      }

      try {
        const response = await fetch(`/api/redirects/${id}`, {
          method: 'DELETE',
          credentials: 'include',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) {
          throw new Error('Failed to delete redirect');
        }

        this.redirects = this.redirects.filter(r => r.id !== id);

        alert('Redirect deleted successfully! .htaccess has been updated.');
      } catch (error) {
        console.error('Error deleting redirect:', error);
        alert('Failed to delete redirect');
      }
    },

    // Assets
    async loadAssets() {
      const params = new URLSearchParams({
        page: this.assetPage,
        per_page: 24
      });
      if (this.assetSearch) params.append('search', this.assetSearch);
      if (this.assetTypeFilter) params.append('type', this.assetTypeFilter);

      const response = await fetch(`/api/assets?${params}`);
      const data = await response.json();
      this.assets = data.assets;
      this.assetPagination = data.pagination;
    },

    selectAsset(asset) {
      this.selectedAsset = { ...asset };
    },

    async uploadAsset(event) {
      const files = event.target.files;
      if (!files.length) return;

      this.uploading = true;

      for (const file of files) {
        const formData = new FormData();
        formData.append('file', file);

        try {
          const response = await fetch('/api/assets', {
            method: 'POST',
            body: formData
          });

          if (!response.ok) {
            const error = await response.json();
            alert(error.error || 'Upload failed');
          }
        } catch (e) {
          alert('Upload failed: ' + e.message);
        }
      }

      this.uploading = false;
      event.target.value = '';
      this.loadAssets();
    },

    async updateAssetAltText() {
      if (!this.selectedAsset) return;

      await fetch(`/api/assets/${this.selectedAsset.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ alt_text: this.selectedAsset.alt_text })
      });
    },

    async deleteAsset(asset) {
      if (!confirm(`Delete "${asset.filename}"? This cannot be undone.`)) return;

      await fetch(`/api/assets/${asset.id}`, { method: 'DELETE' });
      this.selectedAsset = null;
      this.loadAssets();
    },

    formatFileSize(bytes) {
      if (bytes < 1024) return bytes + ' B';
      if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
      return (bytes / 1048576).toFixed(1) + ' MB';
    },

    copyToClipboard(text) {
      navigator.clipboard.writeText(text);
    },

    // Media Library Modal
    openMediaLibrary(callback) {
      this.mediaCallback = callback;
      this.selectedMediaAsset = null;
      this.showMediaLibrary = true;
      this.loadMediaLibrary();
    },

    closeMediaLibrary() {
      this.showMediaLibrary = false;
      this.mediaCallback = null;
    },

    async loadMediaLibrary() {
      const params = new URLSearchParams({ per_page: 40 });
      if (this.mediaSearch) params.append('search', this.mediaSearch);
      if (this.mediaTypeFilter) params.append('type', this.mediaTypeFilter);

      const response = await fetch(`/api/assets?${params}`);
      const data = await response.json();
      this.mediaAssets = data.assets;
    },

    selectMediaAsset(asset) {
      this.selectedMediaAsset = asset;
    },

    async uploadMediaAsset(event) {
      const file = event.target.files[0];
      if (!file) return;

      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch('/api/assets', {
        method: 'POST',
        body: formData
      });

      if (response.ok) {
        const asset = await response.json();
        this.selectedMediaAsset = asset;
        this.loadMediaLibrary();
      }

      event.target.value = '';
    },

    insertSelectedMedia() {
      if (this.selectedMediaAsset && this.mediaCallback) {
        this.mediaCallback(this.selectedMediaAsset);
      }
      this.closeMediaLibrary();
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
    },

    formatRelativeTime(dateString) {
      if (!dateString) return 'Never';
      const date = new Date(dateString);
      const now = new Date();
      const diffMs = now - date;
      const diffSecs = Math.floor(diffMs / 1000);
      const diffMins = Math.floor(diffSecs / 60);
      const diffHours = Math.floor(diffMins / 60);
      const diffDays = Math.floor(diffHours / 24);

      if (diffSecs < 60) return 'Just now';
      if (diffMins < 60) return `${diffMins} minute${diffMins === 1 ? '' : 's'} ago`;
      if (diffHours < 24) return `${diffHours} hour${diffHours === 1 ? '' : 's'} ago`;
      if (diffDays < 7) return `${diffDays} day${diffDays === 1 ? '' : 's'} ago`;
      return this.formatDate(dateString);
    },

    // Version History
    async loadVersions(type, id) {
      this.loadingVersions = true;
      try {
        const allParam = this.showAllVersions ? '?all=true' : '';
        const response = await fetch(`/api/${type}s/${id}/versions${allParam}`);
        if (!response.ok) throw new Error('Failed to load versions');

        const data = await response.json();
        this.permanentVersions = data.versions.filter(v => v.permanent);
        this.temporaryVersions = data.versions.filter(v => !v.permanent);
      } catch (error) {
        console.error('Error loading versions:', error);
        this.permanentVersions = [];
        this.temporaryVersions = [];
      } finally {
        this.loadingVersions = false;
      }
    },

    async previewVersion(type, id, versionNumber) {
      try {
        const response = await fetch(`/api/${type}s/${id}/versions/${versionNumber}`);
        if (!response.ok) throw new Error('Failed to load version');

        const data = await response.json();
        this.versionPreview = data.version;
        this.versionPreviewType = type;
        this.versionPreviewId = id;
      } catch (error) {
        console.error('Error loading version:', error);
        alert('Failed to load version');
      }
    },

    async restoreVersion(type, id, versionNumber) {
      if (!confirm(`Restore to version ${versionNumber}? Current changes will be overwritten.`)) {
        return;
      }

      try {
        const response = await fetch(`/api/${type}s/${id}/versions/${versionNumber}/restore`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) throw new Error('Failed to restore version');

        const data = await response.json();

        // Update the editing item
        if (type === 'post' && this.editingPost) {
          this.currentPost = data.post;
          if (this.quillInstance) {
            this.quillInstance.root.innerHTML = data.post.content || '';
          }
        } else if (type === 'page' && this.editingPage) {
          this.currentPage = data.page;
          if (this.quillPageInstance) {
            this.quillPageInstance.root.innerHTML = data.page.content || '';
          }
        }

        // Reload versions list
        this.loadVersions(type, id);

        alert('Version restored successfully');
      } catch (error) {
        console.error('Error restoring version:', error);
        alert('Failed to restore version');
      }
    },

    async keepVersion(type, id, versionNumber) {
      try {
        const response = await fetch(`/api/${type}s/${id}/versions/${versionNumber}/keep`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) throw new Error('Failed to keep version');

        // Reload versions list
        this.loadVersions(type, id);

        alert('Version marked as permanent');
      } catch (error) {
        console.error('Error keeping version:', error);
        alert('Failed to keep version');
      }
    },

    // Menus

    async fetchMenus() {
      try {
        const response = await fetch('/api/menus', {
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        if (!response.ok) {
          console.error('Failed to fetch menus:', response.status);
          this.menus = [];
          return;
        }
        const data = await response.json();
        this.menus = data.menus || [];
      } catch (error) {
        console.error('Error fetching menus:', error);
        this.menus = [];
      }
    },

    newMenu() {
      this.currentMenu = { name: '', location: '' };
      this.menuItems = [];
      this.editingMenu = true;
      this.showItemForm = false;
    },

    async editMenu(menu) {
      try {
        const response = await fetch(`/api/menus/${menu.id}`, {
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        if (!response.ok) throw new Error('Failed to load menu');
        const data = await response.json();
        this.currentMenu = { id: data.menu.id, name: data.menu.name, slug: data.menu.slug, location: data.menu.location || '' };
        this.menuItems = this.flattenMenuItems(data.menu.items || []);
        this.editingMenu = true;
        this.showItemForm = false;
      } catch (error) {
        console.error('Error loading menu:', error);
        alert('Failed to load menu');
      }
    },

    flattenMenuItems(items, parentId = null) {
      const result = [];
      for (const item of items) {
        result.push({
          id: item.id,
          label: item.label,
          href: item.href,
          link_type: item.link_type || 'custom',
          linkable_type: item.linkable_type,
          linkable_id: item.linkable_id,
          url: item.url,
          target: item.target,
          parent_id: parentId,
          position: result.filter(i => i.parent_id === parentId).length
        });
        if (item.children && item.children.length > 0) {
          result.push(...this.flattenMenuItems(item.children, item.id));
        }
      }
      return result;
    },

    cancelMenuEdit() {
      this.editingMenu = false;
      this.currentMenu = {};
      this.menuItems = [];
      this.showItemForm = false;
      this.currentMenuItem = {};
    },

    async saveMenu() {
      if (!this.currentMenu.name) {
        alert('Menu name is required');
        return;
      }
      this.savingMenu = true;
      try {
        const method = this.currentMenu.id ? 'PUT' : 'POST';
        const url = this.currentMenu.id ? `/api/menus/${this.currentMenu.id}` : '/api/menus';
        const response = await fetch(url, {
          method,
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify({
            name: this.currentMenu.name,
            location: this.currentMenu.location || null
          })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.errors ? data.errors.join(', ') : 'Failed to save menu');
        this.currentMenu.id = data.menu.id;
        this.currentMenu.slug = data.menu.slug;
        await this.fetchMenus();
      } catch (error) {
        console.error('Error saving menu:', error);
        alert(error.message || 'Failed to save menu');
      } finally {
        this.savingMenu = false;
      }
    },

    async deleteMenu(menu) {
      if (!confirm(`Delete menu "${menu.name}" and all its items?`)) return;
      try {
        const response = await fetch(`/api/menus/${menu.id}`, {
          method: 'DELETE',
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        if (!response.ok) throw new Error('Failed to delete menu');
        this.menus = this.menus.filter(m => m.id !== menu.id);
      } catch (error) {
        console.error('Error deleting menu:', error);
        alert('Failed to delete menu');
      }
    },

    editMenuItem(item) {
      this.currentMenuItem = { ...item };
      this.menuItemTargetBlank = item.target === '_blank';
      this.showItemForm = true;
    },

    async saveMenuItem() {
      if (!this.currentMenuItem.label) {
        alert('Label is required');
        return;
      }

      const itemData = {
        label: this.currentMenuItem.label,
        link_type: this.currentMenuItem.link_type || 'custom',
        parent_id: this.currentMenuItem.parent_id || null,
        target: this.menuItemTargetBlank ? '_blank' : null
      };

      if (itemData.link_type === 'custom') {
        itemData.url = this.currentMenuItem.url;
      } else {
        const type = itemData.link_type === 'page' ? 'V7CMS::Page' : 'V7CMS::Post';
        itemData.linkable_type = type;
        itemData.linkable_id = this.currentMenuItem.linkable_id;
      }

      try {
        const isEdit = !!this.currentMenuItem.id;
        const method = isEdit ? 'PUT' : 'POST';
        const url = isEdit
          ? `/api/menu-items/${this.currentMenuItem.id}`
          : `/api/menus/${this.currentMenu.id}/items`;

        const response = await fetch(url, {
          method,
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify(itemData)
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.errors ? data.errors.join(', ') : 'Failed to save item');

        if (isEdit) {
          const idx = this.menuItems.findIndex(i => i.id === data.item.id);
          if (idx !== -1) this.menuItems[idx] = data.item;
        } else {
          this.menuItems.push(data.item);
        }

        this.showItemForm = false;
        this.currentMenuItem = {};
        this.menuItemTargetBlank = false;
        await this.fetchMenus();
      } catch (error) {
        console.error('Error saving menu item:', error);
        alert(error.message || 'Failed to save item');
      }
    },

    async deleteMenuItem(item) {
      if (!confirm(`Delete "${item.label}"?`)) return;
      try {
        const response = await fetch(`/api/menu-items/${item.id}`, {
          method: 'DELETE',
          credentials: 'include',
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        if (!response.ok) throw new Error('Failed to delete item');
        // Remove item and its children
        this.menuItems = this.menuItems.filter(i => i.id !== item.id && i.parent_id !== item.id);
        await this.fetchMenus();
      } catch (error) {
        console.error('Error deleting item:', error);
        alert('Failed to delete item');
      }
    },

    async moveMenuItem(item, direction) {
      const siblings = this.menuItems.filter(i => i.parent_id === item.parent_id);
      const currentIdx = siblings.findIndex(i => i.id === item.id);
      const targetIdx = currentIdx + direction;

      if (targetIdx < 0 || targetIdx >= siblings.length) return;

      // Swap positions
      const other = siblings[targetIdx];
      const tempPos = item.position;
      item.position = other.position;
      other.position = tempPos;

      // Build reorder payload from all items
      const reorderItems = this.menuItems.map(i => ({
        id: i.id,
        position: i.position,
        parent_id: i.parent_id
      }));

      try {
        const response = await fetch(`/api/menus/${this.currentMenu.id}/reorder`, {
          method: 'PUT',
          credentials: 'include',
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: JSON.stringify({ items: reorderItems })
        });
        if (!response.ok) throw new Error('Failed to reorder');

        // Re-sort menuItems
        this.menuItems.sort((a, b) => {
          if (a.parent_id !== b.parent_id) return (a.parent_id || 0) - (b.parent_id || 0);
          return a.position - b.position;
        });
      } catch (error) {
        console.error('Error reordering:', error);
        // Revert swap
        other.position = item.position;
        item.position = tempPos;
      }
    }
  };
}
