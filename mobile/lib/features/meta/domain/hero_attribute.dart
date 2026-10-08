/// Основний атрибут героя: поле `primary_attr` у `docs/openapi.yaml` і сідах.
enum HeroAttribute {
  strength('str', 'Сила'),
  agility('agi', 'Спритність'),
  intelligence('int', 'Інтелект'),
  universal('all', 'Універсал');

  const HeroAttribute(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static HeroAttribute? fromApi(String? value) {
    for (final attribute in values) {
      if (attribute.apiValue == value) return attribute;
    }
    return null;
  }
}
