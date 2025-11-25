// Comments State
let commentsLoaded = 0;
const LOAD_INCREMENT = 20;

// Load comments on page load
document.addEventListener('DOMContentLoaded', () => {
  loadComments(0);
  setupCommentForm();
  setupLoadMore();
});

// Load comments from API
async function loadComments(offset) {
  try {
    const response = await fetch(
      `/api/posts/${POST_ID}/comments?limit=${LOAD_INCREMENT}&offset=${offset}`
    );

    if (!response.ok) throw new Error('Failed to load comments');

    const data = await response.json();

    renderComments(data.comments);
    commentsLoaded += data.comments.length;

    // Update count
    document.getElementById('comment-count').textContent = data.pagination.total;

    // Show/hide "Load More" button
    const loadMoreBtn = document.getElementById('load-more');
    if (data.pagination.has_more) {
      loadMoreBtn.style.display = 'block';
    } else {
      loadMoreBtn.style.display = 'none';
    }
  } catch (error) {
    console.error('Error loading comments:', error);
  }
}

// Render comments to DOM
function renderComments(comments) {
  const commentsList = document.getElementById('comments-list');

  comments.forEach(comment => {
    const commentEl = document.createElement('div');
    commentEl.className = 'bg-white rounded-lg shadow-sm border border-gray-200 p-6';

    const date = new Date(comment.created_at);
    const formattedDate = date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    let authorHtml = `<strong class="text-gray-900">${escapeHtml(comment.author_name)}</strong>`;
    if (comment.author_url) {
      authorHtml = `<a href="${escapeHtml(comment.author_url)}" target="_blank" rel="noopener noreferrer" class="text-blue-500 hover:underline font-semibold">${escapeHtml(comment.author_name)}</a>`;
    }

    commentEl.innerHTML = `
      <div class="flex justify-between items-start mb-3">
        <div>
          ${authorHtml}
          <span class="text-gray-500 text-sm ml-2">${formattedDate}</span>
        </div>
      </div>
      <div class="text-gray-700 whitespace-pre-wrap">${escapeHtml(comment.content)}</div>
    `;

    commentsList.appendChild(commentEl);
  });
}

// Setup comment form submission
function setupCommentForm() {
  const form = document.getElementById('comment-form');
  const submitBtn = document.getElementById('submit-btn');
  const messageEl = document.getElementById('form-message');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Disable form
    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting...';
    messageEl.className = 'hidden';

    try {
      // Get reCAPTCHA token
      const token = await grecaptcha.execute(RECAPTCHA_SITE_KEY, { action: 'submit' });

      // Prepare data
      const formData = {
        author_name: form.author_name.value.trim(),
        author_email: form.author_email.value.trim(),
        author_url: form.author_url.value.trim() || null,
        content: form.content.value.trim(),
        recaptcha_token: token
      };

      // Submit comment
      const response = await fetch(`/api/posts/${POST_ID}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      if (response.ok) {
        // Success
        messageEl.textContent = data.message || 'Comment submitted for moderation!';
        messageEl.className = 'p-3 rounded-lg text-sm bg-green-50 text-green-800 border border-green-200';
        form.reset();
      } else {
        // Error
        messageEl.textContent = data.error || 'Failed to submit comment';
        messageEl.className = 'p-3 rounded-lg text-sm bg-red-50 text-red-800 border border-red-200';
      }
    } catch (error) {
      messageEl.textContent = 'Network error. Please try again.';
      messageEl.className = 'p-3 rounded-lg text-sm bg-red-50 text-red-800 border border-red-200';
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = 'Submit Comment';
    }
  });
}

// Setup load more button
function setupLoadMore() {
  const loadMoreBtn = document.getElementById('load-more');
  loadMoreBtn.addEventListener('click', () => {
    loadComments(commentsLoaded);
  });
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
