/// Off the web there is no page unload to prevent. Returns the remover.
void Function() installBeforeUnloadGuard(bool Function() shouldBlock) => () {};
