const isElement = (x) => x && x.nodeType === Node.ELEMENT_NODE;

const walkPath = (el, path = []) => {
  if (isElement(el)) {
    const tag = el.nodeName.toLowerCase(),
          id = (el.id.length != 0 && el.id);
    if (id) {
      return walkPath(
        null, path.concat([`#${id}`]));
    } else {
      return walkPath(el.parentNode, path.concat([tag]));
    }
  } else {
    return path.reverse().join(" ")
  }
};

const elementPath = (el) => {
    let selector = walkPath(el);
    var elements = document.querySelectorAll(selector);
    var index = 0;
    for (var i = 0; i < elements.length; i++) {
        console.log(`compare ${el} to ${elements[i]}`)
      if (el === elements[i]) {
        index = i;
        break;
      }
    }
    return JSON.stringify({
        selector: selector,
        index: index
    })
}

document.addEventListener('click', function(e) {
    webkit.messageHandlers.clickElement.postMessage(elementPath(e.target));
});
