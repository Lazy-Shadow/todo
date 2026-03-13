import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_list/main.dart';

void main() {
  testWidgets('Todo app loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(TodoApp(prefs: prefs));
    expect(find.text('Todo List'), findsOneWidget);
  });
}
