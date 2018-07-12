// Oliver Kuckertz, 2014/01, public domain

// Cydia modifies the user agent. Is there a better/documented method for detecting Cydia?
isCydia = navigator.userAgent.indexOf('Cydia') > -1;

window.addEventListener("DOMContentLoaded", function() {
  // Apply filters
  var filterClass = isCydia ? "hide-in-cydia" : "hide-in-safari";
  var elems = document.getElementsByClassName(filterClass);
  while (elems.length) {
    p = elems[0];
    p.parentNode.removeChild(p);
  }

  // Rewrite package URLs to open the Cydia package page instead of the package depication meant for the webbrowser.
  if (isCydia) {
    var re = /.*package\/(.*)\/$/;
    var elems = document.getElementsByTagName("a");
    var i;
    for (i = 0; i < elems.length; i++) {
      var p = elems[i];
      if (re.test(p.href)) {
        p.href = p.href.replace(re, "cydia://package/$1");
      }
    }
  }

  // Modify body classes
  document.body.classList.add("cydia");
}, true);

// Make all links open in new tabs. Cydia requires this for its swipe animations.
if (isCydia) {
  var baseTag = document.createElement("base");
  baseTag.target = "_blank";
  document.getElementsByTagName("head")[0].appendChild(baseTag);
}
