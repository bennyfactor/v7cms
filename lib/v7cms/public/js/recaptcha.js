// reCAPTCHA utilities for v7cms
// Hides the floating badge and adds required attribution text to forms

(function() {
  'use strict';

  // Inject CSS to hide the reCAPTCHA badge
  function hideBadge() {
    const style = document.createElement('style');
    style.textContent = '.grecaptcha-badge { visibility: hidden; }';
    document.head.appendChild(style);
  }

  // Create attribution element
  function createAttribution() {
    const notice = document.createElement('p');
    notice.className = 'recaptcha-notice text-xs text-gray-500 mt-2';
    notice.innerHTML = 'This site is protected by reCAPTCHA and the Google ' +
      '<a href="https://policies.google.com/privacy" class="underline" target="_blank" rel="noopener">Privacy Policy</a> and ' +
      '<a href="https://policies.google.com/terms" class="underline" target="_blank" rel="noopener">Terms of Service</a> apply.';
    return notice;
  }

  // Add attribution to a form (before submit button or at end)
  function addAttributionToForm(form) {
    // Skip if already has attribution
    if (form.querySelector('.recaptcha-notice')) {
      return;
    }

    const attribution = createAttribution();

    // Try to insert before submit button, otherwise append to form
    const submitBtn = form.querySelector('[type="submit"], button:not([type="button"])');
    if (submitBtn && submitBtn.parentNode === form) {
      form.insertBefore(attribution, submitBtn);
    } else if (submitBtn) {
      // Button might be in a wrapper div
      submitBtn.closest('div, p, span')?.parentNode?.insertBefore(attribution, submitBtn.closest('div, p, span')) ||
        form.appendChild(attribution);
    } else {
      form.appendChild(attribution);
    }
  }

  // Initialize: hide badge and add attribution to all marked forms
  function init() {
    hideBadge();

    // Find all forms with data-recaptcha attribute
    document.querySelectorAll('form[data-recaptcha]').forEach(addAttributionToForm);
  }

  // Run on DOMContentLoaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Export for manual use
  window.V7CMSRecaptcha = {
    addAttributionToForm: addAttributionToForm,
    hideBadge: hideBadge
  };
})();
