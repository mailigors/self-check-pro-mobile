import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/checklist_models.dart';
import 'filling_controller.dart';
import 'attachment_preview.dart';
import 'media_source_sheet.dart';

class ItemAnswerCard extends ConsumerWidget {
  const ItemAnswerCard({
    super.key,
    required this.checklistId,
    required this.item,
    required this.answer,
    this.error,
    this.readOnly = false,
    this.uploading = false,
  });

  final int checklistId;
  final TemplateItem item;
  final ItemAnswer answer;
  final String? error;
  final bool readOnly;
  final bool uploading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: error == null ? AppColors.borderSubtle : AppColors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(item: item),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.description!, style: AppText.bodyH4()),
          ],
          const SizedBox(height: 8),
          _Control(
            checklistId: checklistId,
            item: item,
            answer: answer,
            readOnly: readOnly,
          ),
          if (!readOnly || answer.hasComment)
            _CommentField(
              checklistId: checklistId,
              itemId: item.id,
              comment: answer.comment,
              readOnly: readOnly,
            ),
          if (uploading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3, color: AppColors.brand),
          ],
          if (item.photoRequired || item.videoRequired) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (item.photoRequired)
                  _Requirement(
                    icon: Icons.camera_alt_outlined,
                    label: 'Требуется фото',
                  ),
                if (item.videoRequired)
                  _Requirement(
                    icon: Icons.videocam_outlined,
                    label: 'Требуется видео',
                  ),
              ],
            ),
          ],
          _Attachments(
            checklistId: checklistId,
            item: item,
            answer: answer,
            readOnly: readOnly,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const AppIcon(
                  AppIcon.warning,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: AppText.bodyH5(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.brand),
      const SizedBox(width: 6),
      Text(label, style: AppText.bodyH5(color: AppColors.text)),
      Text(' *', style: AppText.bodyH5(color: AppColors.brand)),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label({required this.item});

  final TemplateItem item;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: item.name),
          if (item.required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.brand),
            ),
        ],
      ),
      style: AppText.bodyH4(color: AppColors.text)
          .copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _Control extends ConsumerWidget {
  const _Control({
    required this.checklistId,
    required this.item,
    required this.answer,
    required this.readOnly,
  });

  final int checklistId;
  final TemplateItem item;
  final ItemAnswer answer;
  final bool readOnly;

  FillingController _ctrl(WidgetRef ref) =>
      ref.read(fillingControllerProvider(checklistId).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.questionType) {
      case 'boolean':
        return _Boolean(
          value: answer.value is bool ? answer.value as bool : null,
          readOnly: readOnly,
          onChanged: (value) =>
              _ctrl(ref).setAnswer(item.id, value, clear: value == null),
        );
      case 'long_text':
        return _SyncedTextField(
          text: '${answer.value ?? ''}',
          hint: item.settings.placeholder ?? 'Подробное описание...',
          showLength: true,
          minLength: item.settings.minLength,
          maxLength: item.settings.maxLength,
          minLines: 3,
          maxLines: 6,
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: (value) =>
              _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
        );
      case 'number':
      case 'numeric':
      case 'double':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SyncedTextField(
              text: answer.value?.toString() ?? '',
              hint: item.settings.placeholder ?? 'Введите число',
              unit: item.settings.unit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !readOnly,
              readOnly: readOnly,
              onChanged: (value) {
                final normalized = value.replaceAll(',', '.');
                final number = num.tryParse(normalized);
                _ctrl(ref)
                    .setAnswer(item.id, number ?? value, clear: value.isEmpty);
              },
            ),
            _BoundsHint(
              min: _numberLabel(
                item.settings.minValue,
                precision: item.questionType == 'double'
                    ? item.settings.precision ?? 2
                    : null,
              ),
              max: _numberLabel(
                item.settings.maxValue,
                precision: item.questionType == 'double'
                    ? item.settings.precision ?? 2
                    : null,
              ),
            ),
          ],
        );
      case 'slider':
        final min = (item.settings.min ?? 0).toDouble();
        final max = (item.settings.max ?? 10).toDouble();
        final current = (answer.value is num)
            ? (answer.value as num).toDouble().clamp(min, max)
            : min;
        return _SliderField(
          min: min,
          max: max,
          value: current,
          start: item.settings.labelStart,
          end: item.settings.labelEnd,
          enabled: !readOnly,
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value.round()),
        );
      case 'select':
      case 'singlechoice':
      case 'single_choice':
        if (item.questionType == 'select' ||
            item.settings.uiHint?.toLowerCase() == 'dropdown') {
          final selected =
              item.settings.options.contains(answer.value?.toString())
              ? answer.value?.toString()
              : null;
          return DropdownButtonFormField<String>(
            isExpanded: true,
            hint: Text('Выберите вариант', style: AppText.bodyH4()),
            key: ValueKey(selected),
            initialValue: selected,
            items: item.settings.options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      item.settings.optionLabels[option] ?? option,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: readOnly
                ? null
                : (value) => _ctrl(ref).setAnswer(item.id, value),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              hintStyle: AppText.bodyH3(color: AppColors.placeholder),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.brand, width: 1),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final option in item.settings.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChoiceRow(
                  label: item.settings.optionLabels[option] ?? option,
                  selected: answer.value?.toString() == option,
                  kind: _ChoiceKind.radio,
                  onTap: readOnly
                      ? null
                      : () => _ctrl(ref).setAnswer(
                          item.id,
                          option,
                          clear: answer.value?.toString() == option,
                        ),
                ),
              ),
          ],
        );
      case 'multichoice':
      case 'multi_choice':
        final selected = answer.value is List
            ? (answer.value as List).map((e) => '$e').toSet()
            : <String>{};
        return Column(
          children: [
            for (final option in item.settings.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChoiceRow(
                  label: item.settings.optionLabels[option] ?? option,
                  selected: selected.contains(option),
                  kind: _ChoiceKind.check,
                  onTap: readOnly
                      ? null
                      : () {
                          final next = {...selected};
                          if (!next.add(option)) next.remove(option);
                          _ctrl(ref).setAnswer(
                            item.id,
                            next.toList(),
                            clear: next.isEmpty,
                          );
                        },
                ),
              ),
          ],
        );
      case 'date':
      case 'datetime':
        return _DateField(
          item: item,
          value: answer.value?.toString(),
          readOnly: readOnly,
          withTime: item.questionType == 'datetime',
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value),
        );
      case 'file':
        return _SyncedTextField(
          text: '${answer.value ?? ''}',
          hint: item.settings.placeholder ?? 'Комментарий к файлу',
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: (value) =>
              _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
        );
      default:
        return _SyncedTextField(
          text: '${answer.value ?? ''}',
          hint: item.settings.placeholder ?? 'Введите ответ',
          showLength: true,
          minLength: item.settings.minLength,
          maxLength: item.settings.maxLength,
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: (value) =>
              _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
        );
    }
  }
}

class _CommentField extends ConsumerWidget {
  const _CommentField({
    required this.checklistId,
    required this.itemId,
    required this.comment,
    required this.readOnly,
  });

  final int checklistId;
  final int itemId;
  final String? comment;
  final bool readOnly;

  bool get _enabled => comment != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        InkWell(
          onTap: readOnly
              ? null
              : () {
                  ref
                      .read(fillingControllerProvider(checklistId).notifier)
                      .setComment(itemId, comment: _enabled ? null : '');
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.add_comment_outlined,
                  size: 18,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _enabled ? 'Комментарий' : 'Добавить комментарий',
                    style: AppText.bodyH5(color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          _SyncedTextField(
            text: comment ?? '',
            hint: 'Комментарий',
            minLines: 3,
            maxLines: 6,
            enabled: !readOnly,
            readOnly: readOnly,
            keyboardType: TextInputType.multiline,
            onChanged: (value) {
              ref
                  .read(fillingControllerProvider(checklistId).notifier)
                  .setComment(itemId, comment: value);
            },
          ),
        ],
      ],
    );
  }
}

class _Boolean extends StatelessWidget {
  const _Boolean({
    required this.value,
    required this.onChanged,
    required this.readOnly,
  });
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool readOnly;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _boolChip('Да', true)),
      const SizedBox(width: 10),
      Expanded(child: _boolChip('Нет', false)),
    ],
  );
  Widget _boolChip(String label, bool option) {
    final selected = value == option;
    final color = option ? AppColors.success : AppColors.brand;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? color : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: selected ? color : AppColors.border),
        ),
        child: InkWell(
          onTap: readOnly ? null : () => onChanged(selected ? null : option),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.bodyH4(
                color: selected ? AppColors.surface : AppColors.text,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChoiceKind { radio, check }

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.kind,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final _ChoiceKind kind;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.brand : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                kind == _ChoiceKind.radio
                    ? (selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (selected
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank),
                size: 22,
                color: selected ? AppColors.surface : AppColors.border,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyH4(
                    color: selected ? AppColors.surface : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.start,
    this.end,
  });
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final String? start;
  final String? end;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              start ?? '${min.round()}',
              style: AppText.bodyH5(color: AppColors.text),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '${value.round()}',
              style: AppText.bodyH5(color: AppColors.surface),
            ),
          ),
          Expanded(
            child: Text(
              end ?? '${max.round()}',
              textAlign: TextAlign.end,
              style: AppText.bodyH5(color: AppColors.text),
            ),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 5,
          activeTrackColor: AppColors.brand,
          inactiveTrackColor: AppColors.border,
          thumbColor: AppColors.brand,
          overlayColor: AppColors.brandSoft,
        ),
        child: Slider(
          min: min,
          max: max,
          value: value,
          label: '${value.round()}',
          onChanged: enabled && max > min ? onChanged : null,
        ),
      ),
    ],
  );
}

String _numberLabel(num? value, {int? precision}) {
  if (value == null) return '-';
  final format = NumberFormat('0.################', 'ru');
  if (precision != null) {
    final digits = precision.clamp(0, 20);
    format.minimumFractionDigits = digits;
    format.maximumFractionDigits = digits;
  }
  return format.format(value);
}

class _BoundsHint extends StatelessWidget {
  const _BoundsHint({required this.min, required this.max});
  final String min;
  final String max;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text('мин $min · макс $max', style: AppText.bodyH5()),
  );
}

class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.text,
    required this.onChanged,
    this.hint,
    this.unit,
    this.showLength = false,
    this.minLength,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String text;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? unit;
  final bool showLength;
  final int? minLength;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text && widget.text != oldWidget.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.text.characters.length;
    final invalid =
        (widget.maxLength != null && count > widget.maxLength!) ||
        (count > 0 && widget.minLength != null && count < widget.minLength!);
    final target = widget.maxLength ?? widget.minLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          hint: widget.hint,
          suffix: widget.unit == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.unit!,
                    style: AppText.bodyH5(color: AppColors.text),
                  ),
                ),
          controller: _controller,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onChanged: (value) {
            setState(() {});
            widget.onChanged(value);
          },
        ),
        if (widget.showLength) ...[
          const SizedBox(height: 8),
          Text(
            'Символов: $count · мин ${widget.minLength ?? '-'} · макс ${widget.maxLength ?? '-'}',
            style: AppText.bodyH5(
              color: invalid ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          if (target != null && target > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (count / target).clamp(0, 1),
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: AppColors.border,
              color: invalid ? AppColors.error : AppColors.success,
            ),
          ],
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.item,
    required this.value,
    required this.readOnly,
    required this.withTime,
    required this.onChanged,
  });

  final TemplateItem item;
  final String? value;
  final bool readOnly;
  final bool withTime;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(value ?? '');
    final label = parsed == null
        ? (withTime ? 'Выберите дату и время' : 'Выберите дату')
        : DateFormat(
            withTime ? 'dd.MM.yyyy  HH:mm' : 'd MMMM yyyy',
            'ru',
          ).format(parsed.toLocal());
    final min =
        DateTime.tryParse(
          item.settings.minDate ?? item.settings.minDatetime ?? '',
        ) ??
        DateTime(2020);
    final max =
        DateTime.tryParse(
          item.settings.maxDate ?? item.settings.maxDatetime ?? '',
        ) ??
        DateTime(2100);
    String boundLabel(String? raw) {
      final date = DateTime.tryParse(raw ?? '');
      if (date == null) return '-';
      return DateFormat(withTime ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy')
          .format(withTime ? date.toLocal() : date);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          readOnly: true,
          enabled: !readOnly,
          hint: label,
          controller: TextEditingController(text: parsed == null ? '' : label),
          suffix: const Padding(
            padding: EdgeInsets.all(12),
            child: AppIcon(AppIcon.calendar, size: 24),
          ),
          onTap: readOnly
              ? null
              : () async {
                  final seed = parsed ?? DateTime.now();
                  final initial = seed.isBefore(min)
                      ? min
                      : seed.isAfter(max)
                      ? max
                      : seed;
                  final date = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: min,
                    lastDate: max,
                  );
                  if (date == null) return;
                  var result = date;
                  if (withTime && context.mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        parsed ?? DateTime.now(),
                      ),
                    );
                    if (time != null) {
                      result = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    }
                  }
                  onChanged(
                    withTime
                        ? result.toUtc().toIso8601String()
                        : DateFormat('yyyy-MM-dd').format(result),
                  );
                },
        ),
        _BoundsHint(
          min: boundLabel(
            withTime ? item.settings.minDatetime : item.settings.minDate,
          ),
          max: boundLabel(
            withTime ? item.settings.maxDatetime : item.settings.maxDate,
          ),
        ),
      ],
    );
  }
}

class _Attachments extends ConsumerWidget {
  const _Attachments({
    required this.checklistId,
    required this.item,
    required this.answer,
    required this.readOnly,
  });

  final int checklistId;
  final TemplateItem item;
  final ItemAnswer answer;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = [
      for (final file in answer.photoIds) (file: file, kind: 'photo'),
      for (final file in answer.videoIds) (file: file, kind: 'video'),
      for (final file in answer.otherIds) (file: file, kind: 'other'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 8),
        if (!readOnly)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: _AttachButton(
                  icon: AppIcon.camera,
                  tooltip: 'Добавить фото',
                  onTap: () => _chooseMedia(context, ref, 'photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AttachButton(
                  icon: AppIcon.video,
                  tooltip: 'Добавить видео',
                  onTap: () => _chooseMedia(context, ref, 'video'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AttachButton(
                  icon: AppIcon.paperclip,
                  tooltip: 'Прикрепить файл',
                  onTap: () => _pickFile(context, ref),
                ),
              ),
            ],
          ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 8),
          Column(
            children: [
              for (final entry in files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AttachmentFileButton(
                    key: ValueKey(entry.file.attachmentId),
                    attachmentKey: (
                      checklistId: checklistId,
                      answerId: answer.id,
                      file: entry.file,
                    ),
                    kind: entry.kind,
                    onRemove: readOnly
                        ? null
                        : () => ref
                              .read(
                                fillingControllerProvider(checklistId).notifier,
                              )
                              .removeAttachment(
                                item.id,
                                entry.file.attachmentId,
                              ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _chooseMedia(
    BuildContext context,
    WidgetRef ref,
    String kind,
  ) async {
    final source = await showMediaSourceSheet(
      context: context,
      video: kind == 'video',
    );
    if (source == null || !context.mounted) return;
    await _pick(context, ref, source, kind);
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
    String kind,
  ) async {
    final picker = ImagePicker();
    try {
      if (kind == 'video') {
        final file = await picker.pickVideo(source: source);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await ref
            .read(fillingControllerProvider(checklistId).notifier)
            .addAttachment(
              item: item,
              filename: file.name,
              bytes: bytes,
              contentType:
                  lookupMimeType(
                    file.name,
                    headerBytes: bytes.take(32).toList(),
                  ) ??
                  'video/mp4',
              kind: 'video',
            );
      } else {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          imageQuality: 80,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await ref
            .read(fillingControllerProvider(checklistId).notifier)
            .addAttachment(
              item: item,
              filename: file.name,
              bytes: bytes,
              contentType:
                  lookupMimeType(
                    file.name,
                    headerBytes: bytes.take(32).toList(),
                  ) ??
                  'image/jpeg',
              kind: 'photo',
            );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Не удалось загрузить файл',
          ),
        ),
      );
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final file = result?.files.firstOrNull;
      if (file?.bytes == null) return;
      await ref
          .read(fillingControllerProvider(checklistId).notifier)
          .addAttachment(
            item: item,
            filename: file!.name,
            bytes: file.bytes!,
            contentType:
                lookupMimeType(
                  file.name,
                  headerBytes: file.bytes!.take(32).toList(),
                ) ??
                'application/octet-stream',
            kind: 'other',
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Не удалось загрузить файл',
          ),
        ),
      );
    }
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: Center(child: AppIcon(icon, size: 24)),
          ),
        ),
      ),
    );
  }
}
