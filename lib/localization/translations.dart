class Translations {
  final String lang;
  Translations(this.lang);

  static const Map<String, Map<String, String>> _data = {
    // ES / EN / EU
  };

  String get(String key) => _data[lang]?[key] ?? key;
}
