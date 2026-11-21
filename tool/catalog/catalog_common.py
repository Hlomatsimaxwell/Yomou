"""Shared config for the generated source catalogs.

Both generators read the same gitignored .data/ files and emit a committed
.dart payload. Keeping the language names and host normalisation in one place
means a new language code only has to be taught to the pipeline once.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / ".data"
CATALOG_DIR = ROOT / "lib/data/sources/catalog"

LANG_NAMES = {
    "en": "English", "ja": "Japanese", "ko": "Korean", "zh": "Chinese",
    "zh-Hans": "Chinese", "zh-Hant": "Chinese", "es": "Spanish",
    "pt": "Portuguese", "pt-BR": "Portuguese (BR)", "fr": "French",
    "it": "Italian", "de": "German", "ru": "Russian", "ar": "Arabic",
    "id": "Indonesian", "th": "Thai", "vi": "Vietnamese", "tr": "Turkish",
    "pl": "Polish", "uk": "Ukrainian", "cs": "Czech", "hu": "Hungarian",
    "ro": "Romanian", "nl": "Dutch", "sv": "Swedish", "no": "Norwegian",
    "da": "Danish", "el": "Greek", "he": "Hebrew", "hi": "Hindi",
    "bn": "Bengali", "bg": "Bulgarian", "ca": "Catalan", "ms": "Malay",
    "ta": "Tamil", "fa": "Persian", "sr": "Serbian", "hr": "Croatian",
    "sk": "Slovak", "sl": "Slovenian", "sq": "Albanian", "af": "Afrikaans",
    "is": "Icelandic", "fil": "Filipino", "tl": "Filipino",
    "ne": "Nepali", "all": "Multi-language",
}


def bare_host(url):
    """'https://www.Example.com/manga' -> 'example.com'.

    sources_catalog.json is keyed by the bare host, while engines.json keeps
    the URL the extension actually talks to (which may include www. or a path).
    """
    return url.split("//", 1)[-1].split("/", 1)[0].lower().removeprefix("www.")


def language_label(langs):
    """The 'Manga, English, ...' label the source list shows."""
    codes = langs or ["all"]
    return "Manga, " + ", ".join(LANG_NAMES.get(code, "Multi-language") for code in codes)
