import 'package:sim_app/features/home/models.dart';
import 'package:sim_design/sim_design.dart';

/// `RESOURCE_REGISTRY` (`resource-registry.tsx:143-306`): the family label
/// and icon of each resource type. File tabs use the document icon of their
/// name (`getDocumentIcon`).
({String label, SimIconData icon}) resourceConfig(HomeResourceType type) =>
    switch (type) {
      HomeResourceType.sources => (
        label: 'Sources',
        icon: SimEmcnIcons.search,
      ),
      HomeResourceType.search => (
        label: 'Search results',
        icon: SimEmcnIcons.search,
      ),
      HomeResourceType.generic => (
        label: 'Results',
        icon: SimEmcnIcons.terminalWindow,
      ),
      HomeResourceType.workflow => (
        label: 'Workflows',
        icon: SimEmcnIcons.workflow,
      ),
      HomeResourceType.table => (label: 'Tables', icon: SimEmcnIcons.table),
      HomeResourceType.dashboard => (
        label: 'Dashboards',
        icon: SimEmcnIcons.dashboard,
      ),
      HomeResourceType.test => (
        label: 'Tests',
        icon: SimEmcnIcons.shieldCheck,
      ),
      HomeResourceType.file => (label: 'Files', icon: SimEmcnIcons.file),
      HomeResourceType.knowledgebase => (
        label: 'Knowledge Bases',
        icon: SimEmcnIcons.database,
      ),
      HomeResourceType.folder => (
        label: 'Folders',
        icon: SimEmcnIcons.folder,
      ),
      HomeResourceType.filefolder => (
        label: 'File Folders',
        icon: SimEmcnIcons.folder,
      ),
      HomeResourceType.task => (label: 'Chats', icon: SimEmcnIcons.task),
      HomeResourceType.log => (label: 'Logs', icon: SimEmcnIcons.library),
      HomeResourceType.integration => (
        label: 'Integrations',
        icon: SimEmcnIcons.connections,
      ),
      HomeResourceType.browser => (
        label: 'Browser',
        icon: SimEmcnIcons.globe,
      ),
      HomeResourceType.terminal => (
        label: 'Terminal',
        icon: SimEmcnIcons.terminalWindow,
      ),
    };

/// `getDocumentIcon('', name)`: the file-type glyph of a file name.
SimIconData documentIcon(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => SimEmcnIcons.pdfIcon,
    'csv' => SimEmcnIcons.csvIcon,
    'doc' || 'docx' => SimEmcnIcons.docxIcon,
    'xls' || 'xlsx' => SimEmcnIcons.xlsxIcon,
    'ppt' || 'pptx' => SimEmcnIcons.pptxIcon,
    'json' => SimEmcnIcons.jsonIcon,
    'md' || 'markdown' => SimEmcnIcons.markdownIcon,
    'html' || 'htm' => SimEmcnIcons.htmlIcon,
    'txt' => SimEmcnIcons.txtIcon,
    'zip' => SimEmcnIcons.zipIcon,
    'mp3' || 'wav' || 'm4a' || 'ogg' => SimEmcnIcons.audioIcon,
    'mp4' || 'mov' || 'webm' => SimEmcnIcons.videoIcon,
    _ => SimEmcnIcons.defaultFileIcon,
  };
}

/// The tab glyph of [resource] (`renderTabIcon`).
SimIconData resourceTabIcon(HomeResource resource) =>
    resource.type == HomeResourceType.file
    ? documentIcon(resource.title)
    : resourceConfig(resource.type).icon;

/// `RESOURCE_MENU_ORDER` (`resource-registry.tsx:308-323`): the product
/// order of every menu listing resource families.
const List<HomeResourceType> resourceMenuOrder = <HomeResourceType>[
  HomeResourceType.integration,
  HomeResourceType.task,
  HomeResourceType.dashboard,
  HomeResourceType.test,
  HomeResourceType.table,
  HomeResourceType.file,
  HomeResourceType.filefolder,
  HomeResourceType.knowledgebase,
  HomeResourceType.workflow,
  HomeResourceType.log,
  HomeResourceType.folder,
  HomeResourceType.browser,
  HomeResourceType.terminal,
  HomeResourceType.generic,
];

/// `byResourceMenuOrder`.
int byResourceMenuOrder(HomeResourceType a, HomeResourceType b) =>
    resourceMenuOrder.indexOf(a) - resourceMenuOrder.indexOf(b);

/// `ADD_RESOURCE_EXCLUDED_TYPES` (`resource-tabs.tsx:69-74`): no tab
/// surface (folders, chats, sources) or mention-only (integrations).
const List<HomeResourceType> addResourceExcludedTypes = <HomeResourceType>[
  HomeResourceType.sources,
  HomeResourceType.folder,
  HomeResourceType.task,
  HomeResourceType.integration,
];
