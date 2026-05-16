(function() {
  'use strict';

  window.MathJax = {
    tex: {
      inlineMath:  [['$', '$'], ['\\(', '\\)']],
      displayMath: [['$$', '$$'], ['\\[', '\\]']],
      processEscapes: true
    },
    options: {
      skipHtmlTags: ['script', 'noscript', 'style', 'textarea'],
      processHtmlClass: 'notebook-preview-content'
    },
    startup: {
      ready: function() {
        MathJax.startup.defaultReady();
      }
    }
  };

  // Load MathJax with SRI integrity hash
  (function() {
    var script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-chtml.js';
    script.integrity = 'sha256-8+VdFOq8L8GFpXMDc8MiDMVyXHBGLLFMkYvBbMVQMiE=';
    script.crossOrigin = 'anonymous';
    script.async = true;
    document.head.appendChild(script);
  })();

  function loadMathJax() {
    var previews = document.querySelectorAll('.notebook-preview-content');
    if (previews.length === 0) return;

    var script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
    script.async = true;
    script.id = 'MathJax-script';
    document.head.appendChild(script);
  }

  window.NotebookPreview = {
    typesetContainer: function(containerId) {
      if (typeof MathJax === 'undefined') return;
      var container = document.getElementById(containerId);
      if (container) {
        MathJax.typesetPromise([container]).catch(function(err) {
          console.warn('MathJax typesetting failed:', err);
        });
      }
    }
  };

  document.addEventListener('DOMContentLoaded', function() {
    loadMathJax();
  });

}());