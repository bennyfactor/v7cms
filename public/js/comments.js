// Comments functionality for v7cms
// Handles loading comments, submitting new comments, and conditional form display

let commentsOffset = 0;
const COMMENTS_LIMIT = 20;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  loadComments(POST_ID);
  setupCommentForm();
  setupLoadMore();
});

// Load comments from API and check if comments are allowed
async function loadComments(postId) {
  try {
    // Fetch post data to check comments_allowed status
    const postResponse = await fetch(`/api/posts/${postId}`);
    const postData = await postResponse.json();

    // Check if comments are allowed (both globally and for this post)
    // API returns { post: { comments_allowed: true/false, ... } }
    const commentsAllowed = postData.post && postData.post.comments_allowed;

    // Get form and container elements
    const formContainer = document.querySelector('#comment-form').parentElement;
    const commentsSection = document.querySelector('.max-w-3xl.mx-auto.mt-12');

    // Show/hide form based on comments_allowed
    if (!commentsAllowed) {
      // Hide the form
      formContainer.style.display = 'none';

      // Check if closed message already exists
      let closedMessage = document.getElementById('comments-closed-message');

      // Create and insert closed message if it doesn't exist
      if (!closedMessage) {
        closedMessage = document.createElement('div');
        closedMessage.id = 'comments-closed-message';
        closedMessage.className = 'bg-gray-100 border border-gray-300 rounded-lg p-4 mb-6 text-center text-gray-600';
        closedMessage.textContent = 'Comments are closed for this post.';
        formContainer.parentNode.insertBefore(closedMessage, formContainer);
      }
    } else {
      // Show the form
      formContainer.style.display = 'block';

      // Remove closed message if it exists
      const closedMessage = document.getElementById('comments-closed-message');
      if (closedMessage) {
        closedMessage.remove();
      }
    }

    // Load and display comments (always show existing approved comments)
    const commentsResponse = await fetch(`/api/posts/${postId}/comments?limit=${COMMENTS_LIMIT}&offset=${commentsOffset}`);
    const data = await commentsResponse.json();

    displayComments(data.comments);
    updateCommentCount(data.total);

    // Show/hide Load More button
    const loadMoreBtn = document.getElementById('load-more');
    if (data.total > commentsOffset + data.comments.length) {
      loadMoreBtn.style.display = 'block';
    } else {
      loadMoreBtn.style.display = 'none';
    }

  } catch (error) {
    console.error('Error loading comments:', error);
  }
}

// Display comments in the list
function displayComments(comments) {
  const commentsList = document.getElementById('comments-list');

  comments.forEach(comment => {
    const commentEl = createCommentElement(comment);
    commentsList.appendChild(commentEl);
  });
}

// Create HTML element for a single comment
function createCommentElement(comment) {
  const div = document.createElement('div');
  div.className = 'bg-white rounded-lg shadow-sm border border-gray-200 p-6';

  const date = new Date(comment.created_at);
  const dateStr = date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });

  // Build author section (name + optional URL)
  let authorHTML = `<strong class="text-gray-900">${escapeHtml(comment.author_name)}</strong>`;
  if (comment.author_url) {
    authorHTML = `<a href="${escapeHtml(comment.author_url)}" target="_blank" rel="nofollow noopener" class="text-blue-600 hover:text-blue-800 font-semibold">${escapeHtml(comment.author_name)}</a>`;
  }

  div.innerHTML = `
    <div class="flex items-start justify-between mb-3">
      <div>
        ${authorHTML}
        <div class="text-sm text-gray-500">${dateStr}</div>
      </div>
    </div>
    <div class="text-gray-700 prose prose-sm max-w-none">
      ${escapeHtml(comment.content).replace(/\n/g, '<br>')}
    </div>
  `;

  return div;
}

// Update comment count display
function updateCommentCount(total) {
  const countEl = document.getElementById('comment-count');
  if (countEl) {
    countEl.textContent = total;
  }
}

// Setup comment form submission
function setupCommentForm() {
  const form = document.getElementById('comment-form');

  form.addEventListener('submit', async function(e) {
    e.preventDefault();

    const submitBtn = document.getElementById('submit-btn');
    const messageEl = document.getElementById('form-message');

    // Disable submit button
    submitBtn.disabled = true;
    submitBtn.textContent = 'Submitting...';

    try {
      // Get reCAPTCHA token
      const token = await grecaptcha.execute(RECAPTCHA_SITE_KEY, { action: 'submit_comment' });

      // Prepare form data
      const formData = {
        author_name: document.getElementById('author_name').value,
        author_email: document.getElementById('author_email').value,
        author_url: document.getElementById('author_url').value,
        content: document.getElementById('content').value,
        recaptcha_token: token
      };

      // Submit comment
      const response = await fetch(`/api/posts/${POST_ID}/comments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
      });

      const result = await response.json();

      if (response.ok) {
        // Success
        showMessage('success', 'Thank you! Your comment has been submitted and is awaiting moderation.');
        form.reset();
      } else {
        // Error
        showMessage('error', result.error || 'Failed to submit comment. Please try again.');
      }

    } catch (error) {
      console.error('Error submitting comment:', error);
      showMessage('error', 'An error occurred. Please try again.');
    } finally {
      // Re-enable submit button
      submitBtn.disabled = false;
      submitBtn.textContent = 'Submit Comment';
    }
  });
}

// Setup Load More button
function setupLoadMore() {
  const loadMoreBtn = document.getElementById('load-more');

  loadMoreBtn.addEventListener('click', async function() {
    loadMoreBtn.disabled = true;
    loadMoreBtn.textContent = 'Loading...';

    commentsOffset += COMMENTS_LIMIT;

    try {
      const response = await fetch(`/api/posts/${POST_ID}/comments?limit=${COMMENTS_LIMIT}&offset=${commentsOffset}`);
      const data = await response.json();

      displayComments(data.comments);

      // Hide button if no more comments
      if (data.total <= commentsOffset + data.comments.length) {
        loadMoreBtn.style.display = 'none';
      }

    } catch (error) {
      console.error('Error loading more comments:', error);
    } finally {
      loadMoreBtn.disabled = false;
      loadMoreBtn.textContent = 'Load More Comments';
    }
  });
}

// Show form message
function showMessage(type, message) {
  const messageEl = document.getElementById('form-message');
  messageEl.className = `p-3 rounded-lg text-sm ${type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' : 'bg-red-100 text-red-800 border border-red-200'}`;
  messageEl.textContent = message;
  messageEl.classList.remove('hidden');

  // Auto-hide after 5 seconds
  setTimeout(() => {
    messageEl.classList.add('hidden');
  }, 5000);
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
