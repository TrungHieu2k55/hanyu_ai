/// handedOff only means the OS/browser accepted the handoff, not that a recipient
/// received or durably saved the file. No state mutation is implied here.
enum FileHandoff { handedOff, canceled, unavailable }
