import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MainApp());
}

const _seedColor = Colors.blue;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme = lightDynamic ?? ColorScheme.fromSeed(seedColor: _seedColor);
        final ColorScheme darkScheme =
            darkDynamic ?? ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
        return MaterialApp(
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const Scaffold(body: Center(child: Text('Hello World!'))),
        );
      },
    );
  }
}
