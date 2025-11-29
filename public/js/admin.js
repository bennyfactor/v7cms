// v7cms Admin Application
function cmsApp() {
  return {
    // State
    loading: true,
    authenticated: false,
    user: {},
    currentView: 'posts',

    // Redirects state
    redirects: [],
    editingRedirect: null,
    redirectForm: {
      short_path: '',
      target_path: ''
    },

    // Initialize the application
    async init() {
      await this.checkAuth();
      if (this.authenticated) {
        await this.fetchRedirects();
      }
      this.loading = false;
    },

    // Check authentication status
    async checkAuth() {
      try {
        const response = await fetch('/api/auth/me', {
          credentials: 'same-origin'
        });
        const data = await response.json();

        if (data.logged_in) {
          this.authenticated = true;
          this.user = data.user;
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      }
    },

    // Logout
    async logout() {
      try {
        await fetch('/api/auth/logout', {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          }
        });
        window.location.reload();
      } catch (error) {
        console.error('Logout failed:', error);
        alert('Logout failed. Please try again.');
      }
    },

    // ========================================================================
    // REDIRECTS CRUD FUNCTIONS
    // ========================================================================

    // Fetch all redirects
    async fetchRedirects() {
      try {
        const response = await fetch('/api/redirects', {
          credentials: 'same-origin',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) {
          throw new Error('Failed to fetch redirects');
        }

        const data = await response.json();
        this.redirects = data.redirects;
      } catch (error) {
        console.error('Error fetching redirects:', error);
        alert('Failed to load redirects');
      }
    },

    // Create new redirect
    async createRedirect() {
      if (!this.redirectForm.short_path || !this.redirectForm.target_path) {
        alert('Please fill in both fields');
        return;
      }

      try {
        const response = await fetch('/api/redirects', {
          method: 'POST',
          credentials: 'same-origin',
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

        // Add to list and reset form
        this.redirects.push(data.redirect);
        this.redirectForm = { short_path: '', target_path: '' };

        alert('Redirect created successfully! .htaccess has been updated.');
      } catch (error) {
        console.error('Error creating redirect:', error);
        alert(error.message || 'Failed to create redirect');
      }
    },

    // Edit redirect
    editRedirect(redirect) {
      this.editingRedirect = { ...redirect };
    },

    // Cancel edit
    cancelEditRedirect() {
      this.editingRedirect = null;
    },

    // Update redirect
    async updateRedirect(id) {
      if (!this.editingRedirect) return;

      try {
        const response = await fetch(`/api/redirects/${id}`, {
          method: 'PUT',
          credentials: 'same-origin',
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

        // Update in list
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

    // Delete redirect
    async deleteRedirect(id) {
      if (!confirm('Are you sure you want to delete this redirect? This will update .htaccess immediately.')) {
        return;
      }

      try {
        const response = await fetch(`/api/redirects/${id}`, {
          method: 'DELETE',
          credentials: 'same-origin',
          headers: {
            'X-Requested-With': 'XMLHttpRequest'
          }
        });

        if (!response.ok) {
          throw new Error('Failed to delete redirect');
        }

        // Remove from list
        this.redirects = this.redirects.filter(r => r.id !== id);

        alert('Redirect deleted successfully! .htaccess has been updated.');
      } catch (error) {
        console.error('Error deleting redirect:', error);
        alert('Failed to delete redirect');
      }
    }
  };
}
