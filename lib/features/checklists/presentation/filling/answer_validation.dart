import 'package:flutter/material.dart';

import '../../domain/checklist_models.dart';

/// Shared by live feedback and the final submission guard.
String? validateAnswer(
  TemplateItem item,
  ItemAnswer answer, {
  bool complete = false,
}) {
  final value = answer.value;
  final empty =
      value == null ||
      (value is String && value.trim().isEmpty) ||
      (value is List && value.isEmpty);
  if (complete && item.photoRequired && answer.photoIds.isEmpty) {
    return 'Требуется фото';
  }
  if (complete && item.videoRequired && answer.videoIds.isEmpty) {
    return 'Требуется видео';
  }
  if (empty) {
    return item.required && answer.isEmpty ? 'Обязательный вопрос' : null;
  }
  final settings = item.settings;
  switch (item.questionType) {
    case 'number':
    case 'numeric':
    case 'double':
    case 'slider':
      final number = value is num
          ? value
          : num.tryParse('$value'.replaceAll(',', '.'));
      if (number == null || !number.isFinite) return 'Введите корректное число';
      final min = item.questionType == 'slider'
          ? settings.min
          : settings.minValue;
      final max = item.questionType == 'slider'
          ? settings.max
          : settings.maxValue;
      if (min != null && number < min) return 'Значение меньше минимума';
      if (max != null && number > max) return 'Значение больше максимума';
    case 'date':
    case 'datetime':
      final date = DateTime.tryParse('$value');
      if (date == null) return 'Введите корректную дату';
      final min = DateTime.tryParse(
        (item.questionType == 'datetime'
                ? settings.minDatetime
                : settings.minDate) ??
            '',
      );
      final max = DateTime.tryParse(
        (item.questionType == 'datetime'
                ? settings.maxDatetime
                : settings.maxDate) ??
            '',
      );
      if (min != null && date.isBefore(min)) return 'Дата раньше минимума';
      if (max != null && date.isAfter(max)) return 'Дата позже максимума';
    case 'multi_choice':
    case 'multichoice':
      if (value is! List || value.any((v) => !settings.options.contains('$v'))) {
        return 'Выберите доступные варианты';
      }
      if (settings.minSelections != null &&
          value.length < settings.minSelections!) {
        return 'Выбрано слишком мало вариантов';
      }
      if (settings.maxSelections != null &&
          value.length > settings.maxSelections!) {
        return 'Выбрано слишком много вариантов';
      }
    case 'select':
    case 'single_choice':
    case 'singlechoice':
      if (!settings.options.contains('$value')) {
        return 'Выберите доступный вариант';
      }
    case 'text':
    case 'short_text':
    case 'long_text':
      final length = '$value'.characters.length;
      if (settings.minLength != null && length < settings.minLength!) {
        return 'Минимум символов: ${settings.minLength}';
      }
      if (settings.maxLength != null && length > settings.maxLength!) {
        return 'Максимум символов: ${settings.maxLength}';
      }
  }
  return null;
}
