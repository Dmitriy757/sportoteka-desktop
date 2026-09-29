import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

abstract class PostBlock {
  const PostBlock();

  factory PostBlock.text(String text) => TextBlock(text);
  factory PostBlock.image(String url) = ImageBlock;
  factory PostBlock.link({
    required String url,
    String title,
  }) = LinkBlock;
  factory PostBlock.video({
    required String url,
    String title,
    String thumbnail,
  }) = VideoBlock;
}

class TextBlock extends PostBlock {
  final String text;
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String align;
  final int colorValue;

  const TextBlock(
    this.text, {
    this.fontSize = 14,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.align = 'left',
    this.colorValue = 0xFF111827,
  });

  TextBlock copyWith({
    String? text,
    double? fontSize,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? align,
    int? colorValue,
  }) {
    return TextBlock(
      text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      align: align ?? this.align,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

class ImageBlock extends PostBlock {
  final String url;
  const ImageBlock(this.url);
}

class LinkBlock extends PostBlock {
  final String url;
  final String title;

  const LinkBlock({
    required this.url,
    this.title = "",
  });
}

class VideoBlock extends PostBlock {
  final String url;
  final String title;
  final String thumbnail;

  const VideoBlock({
    required this.url,
    this.title = "",
    this.thumbnail = "",
  });
}

class PostHtmlParser {
  static List<PostBlock> htmlToBlocks(String html) {
    final input = html.trim();
    if (input.isEmpty) return [];

    final doc = html_parser.parse(input);
    final body = doc.body;
    if (body == null) return [];

    final out = <PostBlock>[];
    final addedVideoUrls = <String>{};

    void addPlainText(String t) {
      final s = _normalizeText(t);
      if (s.isEmpty) return;
      out.add(TextBlock(s));
    }

    void addVideo({
      required String url,
      String title = "",
      String thumbnail = "",
    }) {
      final u = url.trim();
      if (u.isEmpty || addedVideoUrls.contains(u)) return;
      out.add(
        VideoBlock(
          url: u,
          title: title.trim(),
          thumbnail: thumbnail.trim(),
        ),
      );
      addedVideoUrls.add(u);
    }

    bool isOnlyElement(dom.Element node, String tag) {
      final children = node.children;
      final nonWhitespaceText = node.nodes
          .whereType<dom.Text>()
          .map((e) => e.text.trim())
          .where((e) => e.isNotEmpty)
          .isNotEmpty;
      return !nonWhitespaceText &&
          children.length == 1 &&
          children.first.localName?.toLowerCase() == tag;
    }

    void walk(dom.Node node) {
      if (node is dom.Text) {
        addPlainText(node.text);
        return;
      }

      if (node is! dom.Element) return;
      final tag = node.localName?.toLowerCase() ?? '';

      if (tag == 'img') {
        final src = (node.attributes['src'] ?? '').trim();
        if (src.isNotEmpty) out.add(ImageBlock(src));
        return;
      }

      if (tag == 'a') {
        final href = (node.attributes['href'] ?? '').trim();
        final text = _normalizeText(node.text);
        final dataType =
            (node.attributes['data-type'] ?? '').trim().toLowerCase();
        if (href.isNotEmpty) {
          if (dataType == 'video' ||
              _looksLikeDirectVideoUrl(href) ||
              _looksLikeExternalVideoPage(href)) {
            addVideo(url: href, title: text);
          } else {
            out.add(LinkBlock(url: href, title: text));
          }
        }
        return;
      }

      if (tag == 'video') {
        final src = (node.attributes['src'] ?? '').trim();
        final poster = (node.attributes['poster'] ?? '').trim();
        if (src.isNotEmpty) {
          addVideo(url: src, thumbnail: poster);
          return;
        }
        for (final ch in node.children) {
          if (ch.localName?.toLowerCase() == 'source') {
            final s = (ch.attributes['src'] ?? '').trim();
            if (s.isNotEmpty) {
              addVideo(url: s, thumbnail: poster);
              return;
            }
          }
        }
        return;
      }

      final blockTag = tag == 'p' ||
          tag == 'div' ||
          tag == 'section' ||
          tag == 'article' ||
          RegExp(r'^h[1-6]$').hasMatch(tag);

      if (blockTag) {
        if (isOnlyElement(node, 'img') ||
            isOnlyElement(node, 'a') ||
            isOnlyElement(node, 'video')) {
          walk(node.children.first);
          return;
        }

        final text = _normalizeText(_elementTextWithBreaks(node));
        if (text.isNotEmpty) {
          out.add(_textBlockFromElement(node, text));
          return;
        }
      }

      for (final ch in node.nodes) {
        walk(ch);
      }
    }

    for (final n in body.nodes) {
      walk(n);
    }

    return out.where((b) {
      if (b is TextBlock) return b.text.trim().isNotEmpty;
      return true;
    }).toList();
  }

  static TextBlock _textBlockFromElement(dom.Element node, String text) {
    final tag = node.localName?.toLowerCase() ?? '';
    final style = (node.attributes['style'] ?? '').toLowerCase();

    double fontSize = 14;
    final fontSizeMatch = RegExp(r'font-size\s*:\s*([0-9.]+)\s*(px|pt)?')
        .firstMatch(style);
    if (fontSizeMatch != null) {
      final raw = double.tryParse(fontSizeMatch.group(1) ?? '');
      final unit = fontSizeMatch.group(2) ?? 'px';
      if (raw != null) {
        fontSize = unit == 'pt' ? raw * 1.333333 : raw;
      }
    } else if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
      const headingSizes = <String, double>{
        'h1': 28,
        'h2': 24,
        'h3': 20,
        'h4': 18,
        'h5': 16,
        'h6': 14,
      };
      fontSize = headingSizes[tag] ?? 14;
    }

    final alignMatch =
        RegExp(r'text-align\s*:\s*(left|center|right|justify)').firstMatch(style);
    final align = alignMatch?.group(1) ?? 'left';

    final weightMatch =
        RegExp(r'font-weight\s*:\s*([a-z]+|[0-9]+)').firstMatch(style);
    final weight = weightMatch?.group(1) ?? '';
    final boldFromWeight = weight == 'bold' ||
        weight == 'bolder' ||
        ((int.tryParse(weight) ?? 0) >= 600);

    final wholeStrong = _wholeTextWrappedBy(node, const <String>{'strong', 'b'});
    final wholeItalic = _wholeTextWrappedBy(node, const <String>{'em', 'i'});
    final wholeUnderline = _wholeTextWrappedBy(node, const <String>{'u'});
    final wholeStrike =
        _wholeTextWrappedBy(node, const <String>{'s', 'strike', 'del'});

    final bold = boldFromWeight ||
        RegExp(r'^h[1-6]$').hasMatch(tag) ||
        wholeStrong;
    final italic = style.contains('font-style:italic') || wholeItalic;
    final decoration = style.replaceAll(' ', '');
    final underline = decoration.contains('text-decoration:underline') ||
        decoration.contains('text-decoration-line:underline') ||
        wholeUnderline;
    final strike = decoration.contains('line-through') || wholeStrike;

    final color = _parseColor(style) ?? 0xFF111827;

    return TextBlock(
      text,
      fontSize: fontSize.clamp(10, 40).toDouble(),
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      align: align,
      colorValue: color,
    );
  }

  static bool _wholeTextWrappedBy(dom.Element node, Set<String> tags) {
    dom.Element current = node;
    while (current.children.length == 1 &&
        current.nodes.whereType<dom.Text>().every((t) => t.text.trim().isEmpty)) {
      final child = current.children.first;
      final tag = child.localName?.toLowerCase() ?? '';
      if (tags.contains(tag)) return true;
      current = child;
    }
    return false;
  }

  static int? _parseColor(String style) {
    final hex = RegExp(r'color\s*:\s*#([0-9a-f]{6})').firstMatch(style);
    if (hex != null) {
      return int.tryParse('FF${hex.group(1)}', radix: 16);
    }
    final shortHex = RegExp(r'color\s*:\s*#([0-9a-f]{3})(?:;|$)')
        .firstMatch(style);
    if (shortHex != null) {
      final h = shortHex.group(1)!;
      final expanded = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
      return int.tryParse('FF$expanded', radix: 16);
    }
    return null;
  }

  static String _elementTextWithBreaks(dom.Element node) {
    final buf = StringBuffer();

    void read(dom.Node n) {
      if (n is dom.Text) {
        buf.write(n.text);
        return;
      }
      if (n is! dom.Element) return;
      final tag = n.localName?.toLowerCase() ?? '';
      if (tag == 'br') {
        buf.write('\n');
        return;
      }
      for (final child in n.nodes) {
        read(child);
      }
    }

    for (final child in node.nodes) {
      read(child);
    }
    return buf.toString();
  }

  static String blocksToHtml(List<PostBlock> blocks) {
    final buf = StringBuffer();

    for (final b in blocks) {
      if (b is TextBlock) {
        final t = b.text.trim();
        if (t.isEmpty) continue;

        var content = _escapeHtml(t)
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')
            .map((line) => line.trimRight())
            .join('<br/>');

        if (b.bold) content = '<strong>$content</strong>';
        if (b.italic) content = '<em>$content</em>';
        if (b.underline) content = '<u>$content</u>';
        if (b.strike) content = '<s>$content</s>';

        final color = b.colorValue & 0xFFFFFF;
        final colorHex = color.toRadixString(16).padLeft(6, '0').toUpperCase();
        final align = const <String>{'left', 'center', 'right', 'justify'}
                .contains(b.align)
            ? b.align
            : 'left';
        final size = b.fontSize.clamp(10, 40).toStringAsFixed(
              b.fontSize % 1 == 0 ? 0 : 1,
            );

        buf.writeln(
          '<p style="font-size:${size}px;text-align:$align;color:#$colorHex;">$content</p>',
        );
      }

      if (b is ImageBlock) {
        final u = b.url.trim();
        if (u.isEmpty) continue;
        buf.writeln('<p><img src="${_escapeHtmlAttr(u)}" /></p>');
      }

      if (b is LinkBlock) {
        final u = b.url.trim();
        if (u.isEmpty) continue;
        final title = b.title.trim().isEmpty ? b.url.trim() : b.title.trim();
        buf.writeln(
          '<p><a href="${_escapeHtmlAttr(u)}" target="_blank">${_escapeHtml(title)}</a></p>',
        );
      }

      if (b is VideoBlock) {
        final u = b.url.trim();
        if (u.isEmpty) continue;

        final title = b.title.trim();
        final poster = b.thumbnail.trim();

        if (_looksLikeDirectVideoUrl(u)) {
          if (poster.isNotEmpty) {
            buf.writeln(
              '<p><video controls preload="metadata" poster="${_escapeHtmlAttr(poster)}"><source src="${_escapeHtmlAttr(u)}" /></video></p>',
            );
          } else {
            buf.writeln(
              '<p><video controls preload="metadata"><source src="${_escapeHtmlAttr(u)}" /></video></p>',
            );
          }
        } else {
          final linkText = title.isEmpty ? u : title;
          buf.writeln(
            '<p><a href="${_escapeHtmlAttr(u)}" data-type="video" target="_blank">${_escapeHtml(linkText)}</a></p>',
          );
        }
      }
    }

    return buf.toString().trim();
  }

  static String _normalizeText(String t) {
    var s = t.replaceAll('\u00A0', ' ');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _escapeHtmlAttr(String s) => _escapeHtml(s);

  static bool _looksLikeDirectVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.m4v') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.m3u8');
  }

  static bool _looksLikeExternalVideoPage(String url) {
    final u = url.toLowerCase();
    return u.contains('youtube.com/') ||
        u.contains('youtu.be/') ||
        u.contains('vimeo.com/') ||
        u.contains('rutube.ru/') ||
        u.contains('vkvideo.ru/') ||
        u.contains('vk.com/video') ||
        u.contains('dailymotion.com/') ||
        u.contains('tiktok.com/') ||
        u.contains('drive.google.com/') ||
        u.contains('dropbox.com/');
  }
}
