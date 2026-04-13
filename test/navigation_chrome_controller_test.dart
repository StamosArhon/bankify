import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bankify/pages/navigation.dart';

void main() {
  test('navigation chrome controller reset clears destination chrome', () {
    final NavigationChromeController controller = NavigationChromeController(
      title: const Text('Main'),
    );
    const PreferredSizeWidget bottom = PreferredSize(
      preferredSize: Size(0, 0),
      child: SizedBox.shrink(),
    );

    controller.setActions(<Widget>[const Icon(Icons.search)]);
    controller.setBottom(bottom);
    controller.setFab(const Icon(Icons.add));

    controller.resetForDestination(title: const Text('Settings'));

    expect((controller.title as Text).data, 'Settings');
    expect(controller.actions, isNull);
    expect(controller.bottom, isNull);
    expect(controller.fab, isNull);
  });
}
