/// Тір героя в меті (поле `tier`). У БД можливі S, A, B, C.
enum Tier {
  s('S', 'Домінують у патчі'),
  a('A', 'Сильні й надійні'),
  b('B', 'Ситуативні'),
  c('C', 'Слабкі в цьому патчі'),

  /// Бекенд не віддав тір або віддав незнайомий — секція «Без тіру» наприкінці.
  none('—', 'Без тіру');

  const Tier(this.letter, this.description);

  final String letter;
  final String description;

  String get title => this == none ? 'Без тіру' : '$letter-тір';

  static Tier fromApi(String? value) {
    for (final tier in values) {
      if (tier != none && tier.letter == value?.trim().toUpperCase()) return tier;
    }
    return none;
  }
}
