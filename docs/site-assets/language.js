"use strict";

const languages = {
  "en-US": "English",
  "de-DE": "Deutsch",
  "es-ES": "Español",
  "fr-FR": "Français",
  "it-IT": "Italiano",
  "ja-JP": "日本語",
  "ko-KR": "한국어",
  "nl-NL": "Nederlands",
  "pl-PL": "Polski",
  "pt-BR": "Português (Brasil)",
  "pt-PT": "Português (Portugal)",
  "ru-RU": "Русский",
  "tr-TR": "Türkçe",
  "zh-CN": "简体中文",
  "zh-TW": "繁體中文"
};
const defaultLanguage = "en-US";
const languageStorageKey = "scenezoi-site-language";
const languageRoot = new URL("./locales/", document.currentScript.src);
const languagePicker = document.getElementById("site-language");
const originalSiteText = new WeakMap();
const siteTranslations = new Map([[defaultLanguage, {}]]);
let languageRequest = 0;

function matchSiteLanguage(preference) {
  if (!preference) return;
  const [language, ...parts] = preference.toLowerCase().replaceAll("_", "-").split("-");
  if (language === "zh") {
    if (parts.includes("hant")) return "zh-TW";
    if (parts.includes("hans")) return "zh-CN";
    return parts.some(part => ["tw", "hk", "mo"].includes(part)) ? "zh-TW" : "zh-CN";
  }
  if (language === "pt") return parts.includes("pt") ? "pt-PT" : "pt-BR";
  return Object.keys(languages).find(code => code.startsWith(language + "-"));
}

function preferredSiteLanguage() {
  try {
    const saved = localStorage.getItem(languageStorageKey);
    if (Object.hasOwn(languages, saved)) return saved;
  } catch {
    // The browser preference still works when storage is disabled.
  }
  for (const preference of navigator.languages?.length ? navigator.languages : [navigator.language]) {
    const match = matchSiteLanguage(preference);
    if (match) return match;
  }
  return defaultLanguage;
}

// Numbered slots keep the original element and its attributes (such as a link's
// destination). {1} keeps its contents. {1:translated text} replaces its contents.
function localizeSiteElement(element, dictionary) {
  if (!originalSiteText.has(element)) {
    originalSiteText.set(element, Array.from(element.childNodes));
  }
  const original = originalSiteText.get(element);
  const translated = dictionary[element.dataset.i18n];
  const attribute = element.dataset.i18nAttribute;
  if (attribute) {
    const fallback = element.dataset.i18nFallback ??= element.getAttribute(attribute);
    element.setAttribute(attribute, translated || fallback);
  } else if (!translated) {
    element.replaceChildren(...original);
  } else {
    const slots = original.filter(node => node.nodeType === Node.ELEMENT_NODE);
    const nodes = translated.split(/(\{[1-9]\d*(?::[^{}]+)?\})/).map(part => {
      const slot = part.match(/^\{([1-9]\d*)(?::([^{}]+))?\}$/);
      if (!slot) return part;
      const child = slots[Number(slot[1]) - 1]?.cloneNode(true);
      if (!child) return part;
      if (slot[2] !== undefined) child.textContent = slot[2];
      return child;
    });
    element.replaceChildren(...nodes);
  }
}

function setSiteMessage(element, key, fallback) {
  if (key) element.dataset.i18n = key;
  else delete element.dataset.i18n;
  originalSiteText.set(element, [document.createTextNode(fallback)]);
  localizeSiteElement(element, siteTranslations.get(document.documentElement.lang));
}

async function setSiteLanguage(language, remember = false) {
  const request = ++languageRequest;
  if (!siteTranslations.has(language)) {
    try {
      const response = await fetch(new URL(language + ".json", languageRoot));
      if (!response.ok) throw new Error("Language file unavailable");
      siteTranslations.set(language, await response.json());
    } catch {
      if (request === languageRequest) languagePicker.value = document.documentElement.lang;
      return;
    }
  }
  if (request !== languageRequest) return;
  const dictionary = siteTranslations.get(language);
  document.documentElement.lang = language;
  languagePicker.value = language;
  for (const element of document.querySelectorAll("[data-i18n]")) {
    localizeSiteElement(element, dictionary);
  }
  if (remember) {
    try {
      localStorage.setItem(languageStorageKey, language);
    } catch {
      // The selection still applies to this page.
    }
  }
  document.dispatchEvent(new Event("site-language-change"));
}

const languageCollator = new Intl.Collator("en", { sensitivity: "base" });
for (const [code, name] of Object.entries(languages).sort((a, b) => languageCollator.compare(a[1], b[1]))) {
  const option = new Option(name, code);
  option.lang = code;
  languagePicker.add(option);
}
const initialLanguage = preferredSiteLanguage();
languagePicker.value = initialLanguage;
languagePicker.addEventListener("change", () => setSiteLanguage(languagePicker.value, true));
languagePicker.parentElement.hidden = false;
setSiteLanguage(initialLanguage);
