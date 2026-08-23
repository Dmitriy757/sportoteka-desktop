import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

abstract class PostBlock {
  const PostBlock();

  factory PostBlock.text(String text) = TextBlock;
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
  const TextBlock(this.text);
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

    void addText(String t) {
      final s = _normalizeText(t);
      if (s.isEmpty) return;

      if (out.isNotEmpty && out.last is TextBlock) {
        final prev = out.removeLast() as TextBlock;
        out.add(TextBlock((prev.text + "\n\n" + s).trim()));
      } else {
        out.add(TextBlock(s));
      }
    }

    void addVideo({
      required String url,
      String title = "",
      String thumbnail = "",
    }) {
      final u = url.trim();
      if (u.isEmpty) return;
      if (addedVideoUrls.contains(u)) return;

      out.add(
        VideoBlock(
          url: u,
          title: title.trim(),
          thumbnail: thumbnail.trim(),
        ),
      );
      addedVideoUrls.add(u);
    }

    void walk(dom.Node node) {
      if (node is dom.Text) {
        addText(node.text);
        return;
      }

      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? "";

        if (tag == "img") {
          final src = (node.attributes["src"] ?? "").trim();
          if (src.isNotEmpty) {
            out.add(ImageBlock(src));
          }
          return;
        }

        if (tag == "a") {
          final href = (node.attributes["href"] ?? "").trim();
          final text = _normalizeText(node.text);
          final dataType =
              (node.attributes["data-type"] ?? "").trim().toLowerCase();

          if (href.isNotEmpty) {
            if (dataType == "video" ||
                _looksLikeDirectVideoUrl(href) ||
                _looksLikeExternalVideoPage(href)) {
              addVideo(
                url: href,
                title: text,
                thumbnail: "",
              );
            } else {
              out.add(
                LinkBlock(
                  url: href,
                  title: text,
                ),
              );
            }
          }
          return;
        }

        if (tag == "video") {
          final src = (node.attributes["src"] ?? "").trim();
          final poster = (node.attributes["poster"] ?? "").trim();

          if (src.isNotEmpty) {
            addVideo(
              url: src,
              title: "",
              thumbnail: poster,
            );
            return;
          }

          for (final ch in node.children) {
            if (ch.localName?.toLowerCase() == "source") {
              final s = (ch.attributes["src"] ?? "").trim();
              if (s.isNotEmpty) {
                addVideo(
                  url: s,
                  title: "",
                  thumbnail: poster,
                );
                return;
              }
            }
          }
        }

        if (tag == "br") {
          addText("\n");
          return;
        }

        if (tag == "p" ||
            tag == "div" ||
            tag == "section" ||
            tag == "article") {
          for (final ch in node.nodes) {
            walk(ch);
          }
          addText("\n\n");
          return;
        }

        for (final ch in node.nodes) {
          walk(ch);
        }
      }
    }

    for (final n in body.nodes) {
      walk(n);
    }

    final cleaned = <PostBlock>[];
    for (final b in out) {
      if (b is TextBlock) {
        final s = _normalizeText(b.text);
        if (s.isNotEmpty) cleaned.add(TextBlock(s));
      } else {
        cleaned.add(b);
      }
    }

    return cleaned;
  }

  static String blocksToHtml(List<PostBlock> blocks) {
    final buf = StringBuffer();

    for (final b in blocks) {
      if (b is TextBlock) {
        final t = b.text.trim();
        if (t.isEmpty) continue;

        final escaped = _escapeHtml(t)
            .replaceAll("\r\n", "\n")
            .replaceAll("\r", "\n")
            .split("\n")
            .map((line) => line.trimRight())
            .join("<br/>");

        buf.writeln("<p>$escaped</p>");
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
    var s = t.replaceAll("\u00A0", " ");
    s = s.replaceAll(RegExp(r"[ \t]+"), " ");
    s = s.replaceAll(RegExp(r"\n{3,}"), "\n\n");
    return s.trim();
  }

  static String _escapeHtml(String s) {
    return s
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
  }

  static String _escapeHtmlAttr(String s) {
    return _escapeHtml(s);
  }

  static bool _looksLikeDirectVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first.split('#').first;
    return clean.endsWith(".mp4") ||
        clean.endsWith(".mov") ||
        clean.endsWith(".m4v") ||
        clean.endsWith(".webm") ||
        clean.endsWith(".m3u8");
  }

  static bool _looksLikeExternalVideoPage(String url) {
    final u = url.toLowerCase();
    return u.contains("youtube.com/") ||
        u.contains("youtu.be/") ||
        u.contains("vimeo.com/") ||
        u.contains("rutube.ru/") ||
        u.contains("vkvideo.ru/") ||
        u.contains("vk.com/video") ||
        u.contains("dailymotion.com/") ||
        u.contains("tiktok.com/") ||
        u.contains("drive.google.com/") ||
        u.contains("dropbox.com/");
  }
}