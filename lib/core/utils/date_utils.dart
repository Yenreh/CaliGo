import 'package:intl/intl.dart';

/// Date formatting utilities
class DateUtils {
  /// Format date for display (locale-aware)
  static String formatDate(DateTime date, {String locale = 'es'}) {
    final formatter = DateFormat.yMd(locale).add_jm();
    return formatter.format(date);
  }

  /// Format date and time for display (e.g., "07/12/2025 3:45 PM")
  static String formatDateTime(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(date);
  }
  
  /// Format date as relative time (e.g., "hace 2 horas")
  static String formatRelativeTime(DateTime date, {String locale = 'es'}) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (locale == 'es') {
      if (difference.inDays > 30) {
        return 'hace ${difference.inDays ~/ 30} mes${difference.inDays ~/ 30 > 1 ? 'es' : ''}';
      } else if (difference.inDays > 0) {
        return 'hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'hace un momento';
      }
    } else {
      if (difference.inDays > 30) {
        return '${difference.inDays ~/ 30} month${difference.inDays ~/ 30 > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'just now';
      }
    }
  }
}
