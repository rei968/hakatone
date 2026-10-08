import '../lib/db.dart';

void main() {
  print('🚀 Запуск тестування бази даних...');

  initDatabase();
  final jsonResult = getHeroesWithBuildsJson();

  print('\n📊 Отримано JSON з бази даних:');
  print(jsonResult);

  print('\n✅ Тест завершено успішно!');
}