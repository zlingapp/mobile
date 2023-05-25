import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
// import 'package:markdown/markdown.dart' as md;
// import 'package:flutter_markdown/flutter_markdown.dart';

Text latexToRT(Text code,
    {String delimiter = r'$', String displayDelimiter = r'$$'}) {
  final laTeXCode = code.data!;
  final defaultTextStyle = code.style;

  // Building [RegExp] to find any Math part of the LaTeX code by looking for the specified delimiters
  delimiter = delimiter.replaceAll(r'$', r'\$');
  displayDelimiter = displayDelimiter.replaceAll(r'$', r'\$');

  final String rawRegExp =
      '(($delimiter)([^$delimiter]*[^\\\\\\$delimiter])($delimiter)|($displayDelimiter)([^$displayDelimiter]*[^\\\\\\$displayDelimiter])($displayDelimiter))';
  List<RegExpMatch> matches =
      RegExp(rawRegExp, dotAll: true).allMatches(laTeXCode).toList();

  // If no single Math part found, returning the raw [Text] from code
  if (matches.isEmpty) return code;

  // Otherwise looping threw all matches and building a [RichText] from [TextSpan] and [WidgetSpan] widgets
  final List<InlineSpan> textBlocks = [];
  int lastTextEnd = 0;

  for (final laTeXMatch in matches) {
    // If there is an offset between the lat match (beginning of the [String] in first case), first adding the found [Text]
    if (laTeXMatch.start > lastTextEnd) {
      // textBlocks.add(TextSpan(children: [
      //   WidgetSpan(
      //     alignment: PlaceholderAlignment.middle,
      //     child: MarkdownBody(
      //       data: laTeXCode.substring(lastTextEnd, laTeXMatch.start),
      //       extensionSet: md.ExtensionSet(
      //           md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
      //         md.EmojiSyntax(),
      //         ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
      //       ]),
      //     ),
      //   ),
      //   const TextSpan(text: " ")
      // ]));
      textBlocks.add(
          TextSpan(text: laTeXCode.substring(lastTextEnd, laTeXMatch.start)));
    }
    // Adding the [CaTeX] widget to the children
    if (laTeXMatch.group(3) != null) {
      textBlocks.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            laTeXMatch.group(3)?.trim() ?? '',
            textStyle: defaultTextStyle,
          ),
        ),
      );
    } else {
      textBlocks.addAll([
        const TextSpan(text: '\n'),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: DefaultTextStyle.merge(
            child: Math.tex(
              laTeXMatch.group(6)?.trim() ?? '',
              textStyle: defaultTextStyle,
            ),
          ),
        ),
        const TextSpan(text: '\n')
      ]);
    }
    lastTextEnd = laTeXMatch.end;
  }

  // If there is any text left after the end of the last match, adding it to children
  if (lastTextEnd < laTeXCode.length) {
    // textBlocks.add(TextSpan(text: " ", children: [
    //   WidgetSpan(
    //       alignment: PlaceholderAlignment.middle,
    //       child: MarkdownBody(
    //         data: laTeXCode.substring(lastTextEnd),
    //         extensionSet: md.ExtensionSet(
    //             md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
    //           md.EmojiSyntax(),
    //           ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
    //         ]),
    //       )),
    // ]));
    textBlocks.add(TextSpan(text: laTeXCode.substring(lastTextEnd)));
  }

  // Returning a RichText containing all the [TextSpan] and [WidgetSpan] created previously while
  // obeying the specified style in code
  return Text.rich(
    TextSpan(children: textBlocks, style: defaultTextStyle),
    textAlign: code.textAlign,
    textDirection: code.textDirection,
    locale: code.locale,
    softWrap: code.softWrap,
    overflow: code.overflow,
    textScaleFactor: code.textScaleFactor,
    maxLines: code.maxLines,
    semanticsLabel: code.semanticsLabel,
  );
}
