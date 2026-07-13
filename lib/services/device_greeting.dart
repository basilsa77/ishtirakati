String deviceGreeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  return hour < 12 ? 'صباح الخير' : 'مساء الخير';
}
