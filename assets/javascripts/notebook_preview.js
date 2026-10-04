(function () {
  'use strict';

  window.MathJax = {
    tex: {
      inlineMath: [['$', '$'], ['\\(', '\\)']],
      displayMath: [['$$', '$$'], ['\\[', '\\]']],
      processEscapes: true
    },
    options: {
      skipHtmlTags: ['script', 'noscript', 'style', 'textarea'],
      processHtmlClass: 'notebook-preview-content|latex-preview-content'
    },
    startup: {
      ready: function () {
        MathJax.startup.defaultReady();
      },
      typeset: false
    }
  };


  window.NotebookPreview = {
    typesetContainer: function (containerId) {
      if (typeof MathJax === 'undefined') return;
      var container = document.getElementById(containerId);
      if (container) {
        MathJax.typesetPromise([container]).catch(function (err) {
          console.warn('MathJax typesetting failed:', err);
        });
      }
    }
  };

  var selector = '.notebook-preview-content, .latex-preview-content';
  var mathJaxPromise;

  function loadMathJax() {
    if (window.MathJax.typesetPromise) {
      return Promise.resolve();
    }
    if (mathJaxPromise) {
      return mathJaxPromise;
    }

    mathJaxPromise = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/mathjax@4.1.3/tex-chtml.js';
      script.integrity = 'sha256-bs0Ulwpz/Ki7EV+NaWeu+BgTXe4AkTOQYcQa2iMAcrY=';
      script.crossOrigin = 'anonymous';
      script.async = true;
      script.onload = resolve;
      script.onerror = function () {
        mathJaxPromise = null;
        reject(new Error('Failed to load MathJax'));
      };
      document.head.appendChild(script);
    });

    return mathJaxPromise;
  }

  function findTargets(node) {
    var targets = [];
    if (node.nodeType !== 1) return targets;

    if (node.matches(selector)) targets.push(node);
    targets = targets.concat(Array.prototype.slice.call(
      node.querySelectorAll(selector)
    ));
    return targets;
  }

  function typeset(node) {
    var targets = findTargets(node).filter(function (element) {
      return !element.dataset.mathjaxProcessed;
    });
    if (!targets.length) return;

    targets.forEach(function (element) {
      element.dataset.mathjaxProcessed = 'true';
    });

    loadMathJax()
      .then(function () {
        return MathJax.typesetPromise(targets);
      })
      .catch(function (error) {
        targets.forEach(function (element) {
          delete element.dataset.mathjaxProcessed;
        });
        console.warn('MathJax typesetting failed:', error);
      });
  }

  function observePreviews() {
    typeset(document.body);

    new MutationObserver(function (records) {
      records.forEach(function (record) {
        record.addedNodes.forEach(typeset);
      });
    }).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observePreviews);
  } else {
    observePreviews();
  }
})();