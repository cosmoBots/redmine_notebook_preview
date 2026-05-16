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