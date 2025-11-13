// Alpine.js app for v7cms admin
let quill = null;

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

        async init() {
            await this.checkAuth();
            if (this.authenticated) {
                await this.loadPosts();
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
        }
    };
}
