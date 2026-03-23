/**
 * forms.js - Client-side form validation and AJAX submission for v7cms Form Builder
 */
(function() {
  'use strict';

  document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('form[data-form-slug]').forEach(initForm);
  });

  function initForm(formEl) {
    const slug = formEl.getAttribute('data-form-slug');
    const useRecaptcha = formEl.getAttribute('data-recaptcha') === 'true';
    const messageEl = formEl.querySelector('.form-message');

    formEl.addEventListener('submit', async function(e) {
      e.preventDefault();

      // Clear previous errors
      formEl.querySelectorAll('.field-error').forEach(el => el.remove());
      if (messageEl) {
        messageEl.classList.add('hidden');
        messageEl.textContent = '';
      }

      // Collect form data
      const data = {};
      formEl.querySelectorAll('input, textarea, select').forEach(function(input) {
        if (input.type === 'submit') return;
        if (input.type === 'checkbox') {
          data[input.name] = input.checked ? 'true' : 'false';
        } else if (input.type === 'radio') {
          if (input.checked) data[input.name] = input.value;
        } else {
          data[input.name] = input.value;
        }
      });

      // Client-side validation
      const errors = validateForm(formEl, data);
      if (errors.length > 0) {
        showErrors(formEl, errors);
        return;
      }

      // Get reCAPTCHA token if needed
      if (useRecaptcha && typeof grecaptcha !== 'undefined' && window.RECAPTCHA_SITE_KEY) {
        try {
          const recaptchaObj = window.RECAPTCHA_ENTERPRISE ? grecaptcha.enterprise : grecaptcha;
          data.recaptcha_token = await recaptchaObj.execute(window.RECAPTCHA_SITE_KEY, { action: 'form_submit' });
        } catch (err) {
          console.error('reCAPTCHA error:', err);
        }
      }

      // Submit
      const submitBtn = formEl.querySelector('button[type="submit"]');
      const originalText = submitBtn.textContent;
      submitBtn.disabled = true;
      submitBtn.textContent = 'Submitting...';

      try {
        const response = await fetch(`/forms/${slug}/submit`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data)
        });

        const result = await response.json();

        if (response.ok && result.success) {
          if (messageEl) {
            messageEl.textContent = result.message;
            messageEl.className = 'form-message mt-4 p-4 bg-green-50 text-green-700 rounded-lg';
          }
          formEl.reset();
        } else {
          const errs = result.errors || ['An error occurred. Please try again.'];
          showErrors(formEl, errs.map(e => ({ message: e })));
        }
      } catch (err) {
        console.error('Form submission error:', err);
        if (messageEl) {
          messageEl.textContent = 'An error occurred. Please try again.';
          messageEl.className = 'form-message mt-4 p-4 bg-red-50 text-red-700 rounded-lg';
        }
      }

      submitBtn.disabled = false;
      submitBtn.textContent = originalText;
    });
  }

  function validateForm(formEl, data) {
    const errors = [];
    const checkedRadioNames = new Set();
    formEl.querySelectorAll('input[required], textarea[required], select[required]').forEach(function(input) {
      if (input.type === 'radio') {
        const name = input.name;
        if (checkedRadioNames.has(name)) return;
        checkedRadioNames.add(name);
        if (!data[name]) {
          const label = getLabelText(formEl, input);
          errors.push({ field: name, message: `${label} is required` });
        }
      } else if (input.type === 'checkbox') {
        if (!input.checked) {
          const label = getLabelText(formEl, input);
          errors.push({ field: input.name, message: `${label} is required` });
        }
      } else if (!input.value.trim()) {
        const label = getLabelText(formEl, input);
        errors.push({ field: input.name, message: `${label} is required` });
      }
    });

    // Email validation
    formEl.querySelectorAll('input[type="email"]').forEach(function(input) {
      if (input.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.value)) {
        const label = getLabelText(formEl, input);
        errors.push({ field: input.name, message: `${label} must be a valid email` });
      }
    });

    // Number min/max
    formEl.querySelectorAll('input[type="number"]').forEach(function(input) {
      if (input.value) {
        const val = parseFloat(input.value);
        if (input.min && val < parseFloat(input.min)) {
          errors.push({ field: input.name, message: `${getLabelText(formEl, input)} must be at least ${input.min}` });
        }
        if (input.max && val > parseFloat(input.max)) {
          errors.push({ field: input.name, message: `${getLabelText(formEl, input)} must be at most ${input.max}` });
        }
      }
    });

    return errors;
  }

  function getLabelText(formEl, input) {
    if (input.type === 'radio') {
      const fieldset = input.closest('fieldset');
      if (fieldset) {
        const legend = fieldset.querySelector('legend');
        if (legend) return legend.textContent.replace('*', '').trim();
      }
    }
    const label = formEl.querySelector(`label[for="${input.id}"]`);
    return label ? label.textContent.replace('*', '').trim() : input.name;
  }

  function showErrors(formEl, errors) {
    const messageEl = formEl.querySelector('.form-message');
    if (messageEl && errors.length > 0) {
      messageEl.textContent = '';
      errors.forEach(function(e, i) {
        if (i > 0) messageEl.appendChild(document.createElement('br'));
        messageEl.appendChild(document.createTextNode(e.message || e));
      });
      messageEl.className = 'form-message mt-4 p-4 bg-red-50 text-red-700 rounded-lg';
    }
  }
})();
