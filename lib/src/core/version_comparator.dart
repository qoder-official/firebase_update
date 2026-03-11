class VersionComparator {
  const VersionComparator();

  int compare(String current, String other) {
    final currentParts = _parse(current);
    final otherParts = _parse(other);
    final maxLength = currentParts.length > otherParts.length
        ? currentParts.length
        : otherParts.length;

    for (var index = 0; index < maxLength; index++) {
      final currentValue =
          index < currentParts.length ? currentParts[index] : 0;
      final otherValue = index < otherParts.length ? otherParts[index] : 0;

      if (currentValue > otherValue) {
        return 1;
      }
      if (currentValue < otherValue) {
        return -1;
      }
    }

    return 0;
  }

  List<int> _parse(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}
