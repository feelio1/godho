import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 개인정보처리방침·이용약관 본문(assets/legal/*.md)을 그대로 보여주기
/// 위한 가벼운 마크다운 렌더러("법률 본문 삽입" 지시서 F). 범용
/// 마크다운 패키지를 새로 넣지 않는다 — 이 프로젝트는 `intl: 0.20.2`에
/// 고정돼 있어 새 패키지가 끌어오는 의존성이 그 버전과 충돌할 위험이
/// 있고, 두 문서의 문법(제목·인용·구분선·목록·표·굵게)이 고정돼 있어
/// 범용 파서가 굳이 필요하지 않다. 본문은 절대 줄이거나 바꿔 쓰지 않고
/// (verbatim), 【...】 같은 자리표시자도 그대로 보여준다.
class LegalMarkdownView extends StatelessWidget {
  final String markdown;

  const LegalMarkdownView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _parseBlocks(markdown),
    );
  }
}

List<Widget> _parseBlocks(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final blocks = <Widget>[];
  var i = 0;

  while (i < lines.length) {
    final rawLine = lines[i];
    final line = rawLine.trim();

    if (line.isEmpty) {
      i++;
      continue;
    }

    if (line == '---') {
      blocks.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.borderCard),
      ));
      i++;
      continue;
    }

    if (line.startsWith('### ')) {
      blocks.add(_Heading(line.substring(4), level: 3));
      i++;
      continue;
    }
    if (line.startsWith('## ')) {
      blocks.add(_Heading(line.substring(3), level: 2));
      i++;
      continue;
    }
    if (line.startsWith('# ')) {
      blocks.add(_Heading(line.substring(2), level: 1));
      i++;
      continue;
    }

    if (line.startsWith('>')) {
      final quoteLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      blocks.add(_Quote(quoteLines));
      continue;
    }

    if (_isTableRow(line)) {
      final tableLines = <String>[];
      while (i < lines.length && _isTableRow(lines[i].trim())) {
        tableLines.add(lines[i].trim());
        i++;
      }
      blocks.add(_MarkdownTable(tableLines));
      continue;
    }

    final bulletMatch = RegExp(r'^(-)\s+(.*)$').firstMatch(line);
    final orderedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
    if (bulletMatch != null || orderedMatch != null) {
      final indent = rawLine.length - rawLine.trimLeft().length;
      final marker = orderedMatch != null ? '${orderedMatch.group(1)}.' : '•';
      final text = (orderedMatch ?? bulletMatch)!.group(2)!;
      blocks.add(_ListItem(marker: marker, text: text, indent: indent));
      i++;
      continue;
    }

    // 일반 문단 — 다음 특수 줄(제목·인용·구분선·목록·표) 또는 빈 줄까지
    // 이어붙인다.
    final paragraphLines = <String>[rawLine.trim()];
    i++;
    while (i < lines.length) {
      final next = lines[i].trim();
      if (next.isEmpty ||
          next == '---' ||
          next.startsWith('#') ||
          next.startsWith('>') ||
          RegExp(r'^(-|\d+\.)\s+').hasMatch(next) ||
          _isTableRow(next)) {
        break;
      }
      paragraphLines.add(next);
      i++;
    }
    blocks.add(_Paragraph(paragraphLines.join(' ')));
  }

  return blocks;
}

bool _isTableRow(String line) => line.startsWith('|') && line.endsWith('|');

bool _isTableSeparatorRow(String line) {
  final cells = _splitTableRow(line);
  return cells.isNotEmpty && cells.every((cell) => RegExp(r'^:?-+:?$').hasMatch(cell.trim()));
}

List<String> _splitTableRow(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
  return trimmed.split('|');
}

/// `**굵게**` 하나만 지원한다 — 본문 두 파일에서 실제로 쓰는 인라인
/// 서식이 이것뿐이다.
List<InlineSpan> _parseInline(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start), style: baseStyle));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: baseStyle.copyWith(fontWeight: FontWeight.w700),
    ));
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: baseStyle));
  }
  return spans;
}

class _Heading extends StatelessWidget {
  final String text;
  final int level;

  const _Heading(this.text, {required this.level});

  @override
  Widget build(BuildContext context) {
    final style = switch (level) {
      1 => const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
      2 => const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.3),
      _ => const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 0 : 20, bottom: 8),
      child: Text.rich(TextSpan(children: _parseInline(text, style))),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(TextSpan(children: _parseInline(text, style))),
    );
  }
}

class _Quote extends StatelessWidget {
  final List<String> lines;

  const _Quote(this.lines);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.textSecondary);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(left: BorderSide(color: AppColors.borderCard, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(TextSpan(children: _parseInline(line, style))),
            ),
        ],
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  final String marker;
  final String text;
  final int indent;

  const _ListItem({required this.marker, required this.text, required this.indent});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary);
    return Padding(
      padding: EdgeInsets.only(left: (indent * 4).toDouble(), bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(marker, style: style.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(child: Text.rich(TextSpan(children: _parseInline(text, style)))),
        ],
      ),
    );
  }
}

class _MarkdownTable extends StatelessWidget {
  final List<String> rawRows;

  const _MarkdownTable(this.rawRows);

  @override
  Widget build(BuildContext context) {
    final rows = rawRows.map(_splitTableRow).toList();
    // 두 번째 줄이 `|---|---|` 구분선이면(표준 GFM 표) 건너뛴다.
    final dataRows = rows.length > 1 && _isTableSeparatorRow(rawRows[1])
        ? [rows[0], ...rows.skip(2)]
        : rows;

    const headerStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    const cellStyle = TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderCard),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.borderCard)),
        columnWidths: const {0: IntrinsicColumnWidth()},
        children: [
          for (var r = 0; r < dataRows.length; r++)
            TableRow(
              decoration: BoxDecoration(color: r == 0 ? AppColors.backgroundLight : null),
              children: [
                for (final cell in dataRows[r])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text.rich(
                      TextSpan(children: _parseInline(cell.trim(), r == 0 ? headerStyle : cellStyle)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
