// Fakes and a mount helper for the composer widget tests.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/input/chat_composer.dart';
import 'package:sim_app/features/chat/input/composer_attachments.dart';
import 'package:sim_design/sim_design.dart';

const String workspaceId = 'ws-1';

/// Finds the [Semantics] widget carrying a parity id.
Finder byParityId(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);

class FakeContextSource implements ComposerContextSource {
  FakeContextSource({
    this.groups = const [],
    this.skills = const [],
    this.mcpServers = const [],
    this.integrations = const [],
  });

  List<ComposerResourceGroup> groups;
  final List<ComposerSkill> skills;
  final List<ComposerMcpServer> mcpServers;
  final List<ComposerIntegration> integrations;
  int inventoryLoads = 0;
  Completer<List<ComposerResourceGroup>>? pendingInventory;

  @override
  Future<List<ComposerResourceGroup>> loadInventory(String workspaceId) {
    inventoryLoads++;
    return pendingInventory?.future ?? Future.value(groups);
  }

  @override
  Future<List<ComposerSkill>> loadSkills(String workspaceId) async => skills;

  @override
  Future<List<ComposerMcpServer>> loadMcpServers(String workspaceId) async =>
      mcpServers;

  @override
  Future<List<ComposerIntegration>> loadIntegrations() async => integrations;
}

class FakeUploader implements ComposerUploader {
  final List<Completer<({String key, String path})>> pending = [];
  final List<String> names = [];
  int cancelled = 0;

  @override
  Future<({String key, String path})> upload(
    ComposerPickedFile file, {
    required String contentType,
    required ComposerUploadCancel cancel,
  }) {
    names.add(file.name);
    final completer = Completer<({String key, String path})>();
    cancel.onCancel(() {
      cancelled++;
      if (!completer.isCompleted) {
        completer.completeError(StateError('aborted'));
      }
    });
    pending.add(completer);
    return completer.future;
  }
}

/// The drafts storage of the tests: the engine's in-memory chat storage
/// (its [MemoryChatStorage.values] hold the raw envelope).
class MemoryDraftBackend extends MemoryChatStorage {}

/// Mounts [composer] at [width] inside a light (or dark) Sim app with an
/// overlay host and a toast stack.
Future<void> pumpComposer(
  WidgetTester tester,
  Widget composer, {
  double width = 704,
  Size viewport = const Size(1440, 900),
  bool dark = false,
  SimToasts? toasts,
  Alignment alignment = Alignment.center,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? simDarkTheme() : simLightTheme(),
      builder: (context, child) => SimOverlayHost(
        child: Stack(
          children: [
            child ?? const SizedBox(),
            if (toasts != null) SimToastStack(controller: toasts),
          ],
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: alignment,
          child: SizedBox(width: width, child: composer),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The composer's text field.
Finder get editableField => find.byType(EditableText);

/// The editor state of the mounted composer.
EditableTextState editableState(WidgetTester tester) =>
    tester.state<EditableTextState>(editableField);
