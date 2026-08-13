import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/checklist_models.dart';
import 'filling_controller.dart';

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error == null ? AppColors.borderSubtle : AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(item: item),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description!,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          _Control(
            checklistId: checklistId,
            item: item,
            answer: answer,
            readOnly: readOnly,
          ),
          if (uploading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3, color: AppColors.brand),
          ],
          if (item.photoRequired || item.videoRequired) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.photoRequired) ...[
                  const AppIcon(AppIcon.camera, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Требуется фото',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if (item.videoRequired) ...[
                  const SizedBox(width: 12),
                  const AppIcon(AppIcon.video, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Требуется видео',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
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
                const AppIcon(AppIcon.warning, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
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

class _Label extends StatelessWidget {
  const _Label({required this.item});

  final TemplateItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            item.name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ),
        if (item.required)
          Text(
            ' *',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
            ),
          ),
      ],
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
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value, clear: value == null),
        );
      case 'long_text':
        return _SyncedTextField(
          text: '${answer.value ?? ''}',
          hint: item.settings.placeholder ?? 'Подробное описание...',
          minLines: 3,
          maxLines: 6,
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !readOnly,
              readOnly: readOnly,
              onChanged: (value) {
                final normalized = value.replaceAll(',', '.');
                final number = num.tryParse(normalized);
                _ctrl(ref).setAnswer(item.id, number ?? value, clear: value.isEmpty);
              },
            ),
            if (item.settings.unit != null || item.settings.minValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (item.settings.unit != null) 'Ед. изм.: ${item.settings.unit}',
                    if (item.settings.minValue != null) 'мин ${item.settings.minValue}',
                    if (item.settings.maxValue != null) 'макс ${item.settings.maxValue}',
                  ].join('   ·   '),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
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
      case 'single_choice':
        if (item.settings.uiHint == 'dropdown') {
          final selected = item.settings.options.contains(answer.value?.toString())
              ? answer.value?.toString()
              : null;
          return DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected,
            items: item.settings.options
                .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                .toList(),
            onChanged: readOnly ? null : (value) => _ctrl(ref).setAnswer(item.id, value),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
        return Column(
          children: [
            for (final option in item.settings.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChoiceRow(
                  label: option,
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
                  label: option,
                  selected: selected.contains(option),
                  kind: _ChoiceKind.check,
                  onTap: readOnly
                      ? null
                      : () {
                          final next = {...selected};
                          if (!next.add(option)) next.remove(option);
                          _ctrl(ref).setAnswer(item.id, next.toList(), clear: next.isEmpty);
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
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
        );
      default:
        return _SyncedTextField(
          text: '${answer.value ?? ''}',
          hint: item.settings.placeholder ?? 'Введите ответ',
          enabled: !readOnly,
          readOnly: readOnly,
          onChanged: (value) => _ctrl(ref).setAnswer(item.id, value, clear: value.isEmpty),
        );
    }
  }
}

class _Boolean extends StatelessWidget {
  const _Boolean({required this.value, required this.onChanged, required this.readOnly});

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _boolChip('Да', true),
        const SizedBox(width: 12),
        _boolChip('Нет', false),
      ],
    );
  }

  Widget _boolChip(String label, bool option) {
    final selected = value == option;
    return InkWell(
      onTap: readOnly ? null : () => onChanged(selected ? null : option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.brand) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: selected ? AppColors.brand : AppColors.border),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.brand : AppColors.text,
              ),
            ),
          ],
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (kind == _ChoiceKind.radio)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: selected ? AppColors.brand : AppColors.border),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: selected ? AppColors.brand : AppColors.border),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: AppColors.surface)
                    : null,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(start ?? '${min.round()}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: AppColors.borderSubtle,
              thumbColor: AppColors.brand,
              overlayColor: AppColors.brandSoft,
              trackHeight: 4,
            ),
            child: Slider(
              min: min,
              max: max,
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        Text(end ?? '${max.round()}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '${value.round()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.brand,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.text,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String text;
  final ValueChanged<String> onChanged;
  final String? hint;
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
    return AppTextField(
      hint: widget.hint,
      controller: _controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
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
        : DateFormat(withTime ? 'dd.MM.yyyy  HH:mm' : 'd MMMM yyyy', 'ru').format(parsed.toLocal());
    final min = DateTime.tryParse(item.settings.minDate ?? item.settings.minDatetime ?? '') ??
        DateTime(2020);
    final max = DateTime.tryParse(item.settings.maxDate ?? item.settings.maxDatetime ?? '') ??
        DateTime(2100);
    return AppTextField(
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
                  initialTime: TimeOfDay.fromDateTime(parsed ?? DateTime.now()),
                );
                if (time != null) {
                  result = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                }
              }
              onChanged(
                withTime
                    ? result.toUtc().toIso8601String()
                    : DateFormat('yyyy-MM-dd').format(result),
              );
            },
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
    final files = [...answer.photoIds, ...answer.videoIds, ...answer.otherIds];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 8),
        if (!readOnly)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _AttachButton(
                icon: AppIcon.camera,
                onTap: () => _pick(context, ref, ImageSource.camera, 'photo'),
              ),
              const SizedBox(width: 12),
              _AttachButton(
                icon: AppIcon.video,
                onTap: () => _pick(context, ref, ImageSource.camera, 'video'),
              ),
              const SizedBox(width: 12),
              _AttachButton(
                icon: AppIcon.paperclip,
                onTap: () => _pickFile(context, ref),
              ),
            ],
          ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final file in files)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcon.file, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        file.filename ?? 'файл ${file.attachmentId}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      if (!readOnly) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => ref
                              .read(fillingControllerProvider(checklistId).notifier)
                              .removeAttachment(item.id, file.attachmentId),
                          child: const AppIcon(AppIcon.close, size: 16, color: AppColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
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
        await ref.read(fillingControllerProvider(checklistId).notifier).addAttachment(
              item: item,
              filename: file.name,
              bytes: bytes,
              contentType: 'video/mp4',
              kind: 'video',
            );
      } else {
        final file = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 80);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await ref.read(fillingControllerProvider(checklistId).notifier).addAttachment(
              item: item,
              filename: file.name,
              bytes: bytes,
              contentType: 'image/jpeg',
              kind: 'photo',
            );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось загрузить файл')),
      );
    }
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      final file = result?.files.firstOrNull;
      if (file?.bytes == null) return;
      await ref.read(fillingControllerProvider(checklistId).notifier).addAttachment(
            item: item,
            filename: file!.name,
            bytes: file.bytes!,
            contentType: 'application/octet-stream',
            kind: 'other',
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : 'Не удалось загрузить файл')),
      );
    }
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(child: AppIcon(icon, size: 24)),
        ),
      ),
    );
  }
}
