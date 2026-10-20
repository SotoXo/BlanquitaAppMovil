enum AlfresiMood { idle, success, warning, error, thinking }

class AlfresiMessage {
  const AlfresiMessage(this.title, this.body, this.mood);
  final String title, body;
  final AlfresiMood mood;
}
