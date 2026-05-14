import "./style.css";
import cxxIcon from "../Assets/cpp.png";
import pythonIcon from "../Assets/python.png";

const docsBase = __DOCS_BASE__;
const urlRegExp = new RegExp(docsBase + "/([^/]+)/(cxx|python)/");
const langageMap = { python: "cxx", cxx: "python" };

// ----------------------------------------------------------------------------

function patchCPP(selectHTML, toggleLangHTML) {
  const mainContainer = document.querySelector("#titlearea");
  mainContainer.innerHTML = `<div class="kdocs-title-cpp title-line"><div class="title-line"><img class="kdocs-logo" src="${docsBase}-logo-small.png" />${selectHTML}</div><div class="langSwitch title-line">${toggleLangHTML}</div></div>`;
  mainContainer.querySelector("select").addEventListener("change", onSwitch);
}

// ----------------------------------------------------------------------------

function patchPython(selectHTML, toggleLangHTML) {
  const container = document.querySelector(
    ".wy-side-nav-search li.version"
  );
  container.innerHTML = `<div class="title-line kdocs-title-python">${selectHTML}</div>`;
  container.querySelector("select").addEventListener("change", onSwitch);

  const liElem = document.createElement("li");
  liElem.innerHTML = `<div class="kdocs-title-python kdocs-switch-python">${toggleLangHTML}</div>`;
  container.parentElement.appendChild(liElem);
}

// ----------------------------------------------------------------------------

function fetchText(url) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();

    xhr.onreadystatechange = e => {
      if (xhr.readyState === 4) {
        if (xhr.status === 200 || xhr.status === 0) {
          resolve(xhr.response);
        } else {
          reject(xhr, e);
        }
      }
    };

    xhr.open("GET", url, true);
    xhr.responseType = "text";
    xhr.send();
  });
}

// ----------------------------------------------------------------------------

function buildDropDown(versions, active, lang) {
  const buf = [`<select class="versionSelector ${lang}">`];
  versions.forEach(function(version) {
    buf.push(
      `<option value="${version.value}" ${
        version.value == active ? 'selected="selected"' : ""
      }>${version.label}</option>`
    );
  });
  buf.push("</select>");
  return buf.join("");
}

// ----------------------------------------------------------------------------

function buildLanguageToggle(currentVersion, activeLang) {
  return `<a href="/${docsBase}/${currentVersion}/cxx" class="cpp title-line kdocs-lang-link ${activeLang == "cxx" ? "active" : ""}"><img alt="C++ documentation" title="C++ documentation" class="lang-logo cpp" src="/${docsBase}/${cxxIcon}"/> C++</a><a class="python title-line kdocs-lang-link ${activeLang == "python" ? "active" : ""}" href="/${docsBase}/${currentVersion}/python"><img alt="Python documentation" title="Python documentation" class="lang-logo python" src="/${docsBase}/${pythonIcon}" /> Python</a>`;
}

// ----------------------------------------------------------------------------

function patchURL(url, new_version, new_lang) {
  const lang = new_lang || urlRegExp.exec(window.location.href)[2];
  return url.replace(urlRegExp, `${docsBase}/${new_version}/${lang}/`);
}

// ----------------------------------------------------------------------------

function onSwitch(event) {
  const selected = event.target.value;
  const url = window.location.href;
  const newURL = patchURL(url, selected);

  if (newURL != url) {
    window.location.href = newURL;
  }
}

// ----------------------------------------------------------------------------

export function updateDropDown() {
  fetchText(`/${docsBase}/versions.json`).then(txt => {
    const versions = JSON.parse(txt);
    const match = urlRegExp.exec(window.location.href);
    if (match) {
      const lang = match[2];
      const otherLang = langageMap[lang] || "cxx";
      const activeVersion = match[1];

      const selectHTML = buildDropDown(versions, activeVersion, lang, otherLang);
      const toggleLangHTML = buildLanguageToggle(activeVersion, lang);

      if (lang === "python") {
        patchPython(selectHTML, toggleLangHTML);
      } else if (lang === "cxx") {
        patchCPP(selectHTML, toggleLangHTML);
      }
    }
  });
}

// Auto update
updateDropDown();
