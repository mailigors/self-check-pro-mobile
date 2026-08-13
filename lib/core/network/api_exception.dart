class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.offline = false,
  });

  final String message;
  final int? statusCode;
  final bool offline;

  factory ApiException.fromStatus(int? status, [String? bodyMessage]) {
    final fallback = switch (status) {
      400 => bodyMessage ?? 'Ошибка валидации',
      401 => 'Неверно указаны имя пользователя или пароль',
      403 => 'Доступ запрещен',
      404 => 'Не найдено',
      409 => bodyMessage ?? 'Конфликт данных',
      413 => 'Файл слишком большой',
      429 => 'Превышен лимит запросов. Попробуйте позже',
      _ => bodyMessage ?? 'Не удалось выполнить запрос',
    };
    return ApiException(message: fallback, statusCode: status);
  }

  @override
  String toString() => message;
}
