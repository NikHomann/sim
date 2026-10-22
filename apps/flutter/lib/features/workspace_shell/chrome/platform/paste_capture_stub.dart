/// Decides whether a paste of [text] is refused (and reports it).
typedef PasteCaptureDecision = bool Function(String text);

/// Off the web keyboard and toolbar pastes go through the framework, so
/// there is nothing to install. Returns the remover.
void Function() installPasteCapture(PasteCaptureDecision reject) => () {};
