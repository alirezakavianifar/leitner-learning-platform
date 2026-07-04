import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import enTranslation from './locales/en.json';
import faTranslation from './locales/fa.json';

const resources = {
  en: { translation: enTranslation },
  fa: { translation: faTranslation }
};

const savedLang = localStorage.getItem('admin_lang') || 'fa'; // Persian by default

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: savedLang,
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false // React already safes from XSS
    }
  });

// Set initial HTML direction and language
document.documentElement.dir = i18n.language === 'fa' ? 'rtl' : 'ltr';
document.documentElement.lang = i18n.language;

// Update dynamically on language change
i18n.on('languageChanged', (lng) => {
  document.documentElement.dir = lng === 'fa' ? 'rtl' : 'ltr';
  document.documentElement.lang = lng;
  localStorage.setItem('admin_lang', lng);
});

const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

export const localizeNumber = (num: number | string | null | undefined): string => {
  if (num === null || num === undefined) return '';
  const str = num.toString();
  if (i18n.language === 'fa') {
    return str.replace(/[0-9]/g, (w) => persianDigits[parseInt(w, 10)]);
  }
  return str;
};

export const formatPrice = (price: number | string | null | undefined): string => {
  if (price === null || price === undefined) return '';
  const numPrice = Number(price);
  if (isNaN(numPrice)) return price.toString();
  const formatted = numPrice.toLocaleString('en-US'); // Adds commas e.g. 15,000,000
  return localizeNumber(formatted);
};

export default i18n;
