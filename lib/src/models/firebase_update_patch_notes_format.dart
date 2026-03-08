/// The rendering format for patch notes content.
enum FirebaseUpdatePatchNotesFormat {
  /// Plain text patch notes. Each non-empty line is rendered as a separate
  /// paragraph in the default presentation, with read-more expansion when
  /// content exceeds five lines.
  plainText,

  /// HTML patch notes rendered with `flutter_html`. Supports headings, lists,
  /// bold, and other standard inline elements, with read-more expansion for
  /// longer content.
  html,
}
