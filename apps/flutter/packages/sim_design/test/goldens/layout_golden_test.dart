import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

void main() {
  themedGoldenTest(
    'Table, tab strip, details panel, toasts',
    fileName: 'layout',
    columns: 1,
    constraints: const BoxConstraints(maxWidth: 560),
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: 'table',
        child: const SizedBox(
          width: 420,
          child: SimTable(
            columns: <SimTableColumn>[
              SimTableColumn(flex: 2),
              SimTableColumn(),
            ],
            header: <Widget>[Text('Name'), Text('Status')],
            rows: <SimTableRow>[
              SimTableRow(
                cells: <Widget>[Text('Document.pdf'), Text('Active')],
              ),
              SimTableRow(
                cells: <Widget>[Text('Notes.md'), Text('Draft')],
                selected: true,
              ),
            ],
            caption: 'Two files',
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'table list',
        child: const SizedBox(
          width: 420,
          child: SimTable(
            variant: SimTableVariant.list,
            columns: <SimTableColumn>[SimTableColumn(), SimTableColumn()],
            header: <Widget>[Text('Key'), Text('Value')],
            rows: <SimTableRow>[
              SimTableRow(cells: <Widget>[Text('a'), Text('1')]),
              SimTableRow(cells: <Widget>[Text('b'), Text('2')]),
            ],
          ),
        ),
      ),
      for (final variant in SimTabStripVariant.values)
        GoldenTestScenario(
          name: 'tab strip ${variant.name}',
          child: SizedBox(
            width: 520,
            child: SimTabStrip(
              variant: variant,
              tabs: const <SimTabStripItem>[
                SimTabStripItem(
                  id: 'p',
                  title: 'Pinned',
                  pinned: true,
                  icon: SimIcon(SimIcons.bell),
                ),
                SimTabStripItem(id: '1', title: 'Active tab', active: true),
                SimTabStripItem(id: '2', title: 'Selected', selected: true),
                SimTabStripItem(id: '3', title: 'Background', attention: true),
                SimTabStripItem(id: '4', title: 'Another tab'),
              ],
              onSelect: (_, _) {},
              onClose: (_) {},
              onNew: () {},
            ),
          ),
        ),
      GoldenTestScenario(
        name: 'details panel',
        // A desktop viewport: below `md` the panel spans the full width.
        child: const MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: SizedBox(
            width: 420,
            height: 120,
            child: SimDetailsPanel(
              open: true,
              width: 200,
              resizeLabel: 'Resize log details panel',
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Log details'),
              ),
            ),
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'toast stack',
        child: const SizedBox(
          width: 420,
          height: 180,
          child: _ToastPreview(),
        ),
      ),
    ],
  );
}

class _ToastPreview extends StatefulWidget {
  const _ToastPreview();

  @override
  State<_ToastPreview> createState() => _ToastPreviewState();
}

class _ToastPreviewState extends State<_ToastPreview> {
  late final SimToasts _toasts = SimToasts()
    ..error('Upload failed', description: 'Network timed out')
    ..success(
      'Saved',
      action: SimToastAction(label: 'View', onPressed: () {}),
    )
    ..info('Workflow deployed to production');

  @override
  Widget build(BuildContext context) => SimOverlayHost(
    child: Stack(
      children: <Widget>[SimToastStack(controller: _toasts)],
    ),
  );
}
