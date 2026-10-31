#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
from html.parser import HTMLParser


TEXT_ESCAPE_MAP = {
    "&": r"\&",
    "%": r"\%",
    "$": r"\$",
    "#": r"\#",
    "_": r"\_",
    "{": r"\{",
    "}": r"\}",
    "~": r"\textasciitilde{}",
    "^": r"\textasciicircum{}",
}

URL_ESCAPE_MAP = {
    "%": r"\%",
    "#": r"\#",
    "&": r"\&",
    "{": r"\{",
    "}": r"\}",
}


def escape_latex_text(text: str) -> str:
    pieces: list[str] = []
    i = 0

    while i < len(text):
        ch = text[i]

        # Preserve existing LaTeX commands and already-escaped characters.
        if ch == "\\":
            if i + 1 < len(text):
                nxt = text[i + 1]
                if nxt.isalpha():
                    j = i + 2
                    while j < len(text) and text[j].isalpha():
                        j += 1
                    pieces.append(text[i:j])
                    i = j
                    continue
                if nxt in TEXT_ESCAPE_MAP or nxt in ["\\", " ", "[", "]"]:
                    pieces.append(text[i:i + 2])
                    i += 2
                    continue

            pieces.append(r"\textbackslash{}")
            i += 1
            continue

        pieces.append(TEXT_ESCAPE_MAP.get(ch, ch))
        i += 1

    return "".join(pieces)


def escape_latex_url(url: str) -> str:
    pieces: list[str] = []
    i = 0
    while i < len(url):
        ch = url[i]
        if ch == "\\" and i + 1 < len(url) and url[i + 1] in {"%", "#", "&", "{", "}", "_"}:
            pieces.append(url[i : i + 2])
            i += 2
            continue
        if ch == "\\":
            pieces.append(r"\textbackslash{}")
        else:
            pieces.append(URL_ESCAPE_MAP.get(ch, ch))
        i += 1
    return "".join(pieces)


def resolve_image_filename(attr_map: dict[str, str | None]) -> str:
    direct_filename = attr_map.get("data-image-filename") or ""
    if direct_filename:
        return direct_filename

    src = (attr_map.get("src") or "").split("?", 1)[0]
    return os.path.basename(src)


def latex_image_path(finding_name: str, filename: str) -> str:
    if finding_name:
        return f"images/findings/{finding_name}/{filename}"
    return f"images/{filename}"


def make_figure_label(finding_name: str, filename: str, counter: int) -> str:
    stem = os.path.splitext(os.path.basename(filename))[0]
    raw_label = f"{finding_name}-{stem}-{counter}" if finding_name else f"{stem}-{counter}"
    cleaned = "".join(ch if ch.isalnum() else "-" for ch in raw_label).strip("-").lower()
    return cleaned or f"figure-{counter}"


class HtmlToLatexParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.pre_parts: list[str] = []
        self.in_pre = False
        self.in_inline_code = False
        self.in_figure = False
        self.in_figcaption = False
        self.figure_filename = ""
        self.figure_caption_parts: list[str] = []
        self.figure_counter = 0
        self.finding_name = os.environ.get("CPTC_FINDING_NAME", "")

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)

        if self.in_figure:
            if tag == "figcaption":
                self.in_figcaption = True
                return
            if tag == "img":
                self.figure_filename = self.figure_filename or resolve_image_filename(attr_map)
                return
            return

        match tag:
            case "figure":
                self.in_figure = True
                self.in_figcaption = False
                self.figure_filename = resolve_image_filename(attr_map)
                self.figure_caption_parts = []
            case "br":
                self.parts.append("\\bigskip\n")
            case "b":
                self.parts.append(r"\textbf{")
            case "strong":
                self.parts.append(r"\paragraph{")
            case "i" | "em":
                self.parts.append(r"\textit{")
            case "ul":
                self.parts.append("\\begin{itemize}\n")
            case "ol":
                self.parts.append("\\begin{enumerate}\n")
            case "li":
                self.parts.append("\\item ")
            case "pre":
                self.in_pre = True
                self.pre_parts = []
            case "code":
                if self.in_pre:
                    return
                self.in_inline_code = True
                self.parts.append(r"\texttt{\detokenize{")
            case "a":
                href = escape_latex_url(attr_map.get("href") or "")
                self.parts.append(f"\\href{{{href}}}{{")
        return

    def handle_endtag(self, tag: str) -> None:
        if self.in_figure:
            if tag == "figcaption":
                self.in_figcaption = False
                return
            if tag == "figure":
                if self.figure_filename:
                    self.figure_counter += 1
                    image_path = latex_image_path(self.finding_name, self.figure_filename)
                    caption = "".join(self.figure_caption_parts).strip()
                    if caption:
                        label = make_figure_label(self.finding_name, self.figure_filename, self.figure_counter)
                        self.parts.append(f"\n\\includeFigure{{{image_path}}}{{{caption}}}{{{label}}}\n")
                    else:
                        self.parts.append(f"\n\\includeEvidence{{{image_path}}}\n")
                self.in_figure = False
                self.in_figcaption = False
                self.figure_filename = ""
                self.figure_caption_parts = []
                return
            return

        match tag:
            case "div":
                self.parts.append("\n\n")
            case "b" | "strong" | "i" | "em" | "a":
                self.parts.append("}")
            case "ul":
                self.parts.append("\n\\end{itemize}")
            case "ol":
                self.parts.append("\n\\end{enumerate}")
            case "pre":
                content = "\n".join(self.pre_parts).strip("\n")
                self.parts.append("\\begin{verbatim}\n")
                self.parts.append(content)
                self.parts.append("\n\\end{verbatim}\n")
                self.in_pre = False
                self.pre_parts = []
            case "code":
                if not self.in_pre:
                    self.in_inline_code = False
                    self.parts.append("}}")

    def handle_data(self, data: str) -> None:
        data = data.replace("\xa0", " ")
        if self.in_pre:
            self.pre_parts.append(data)
            return
        if self.in_figure:
            if self.in_figcaption:
                self.figure_caption_parts.append(escape_latex_text(data))
            return
        if self.in_inline_code:
            self.parts.append(data)
            return
        self.parts.append(escape_latex_text(data))

    def get_output(self) -> str:
        rendered = "".join(self.parts)
        lines = [line.rstrip() for line in rendered.splitlines()]
        return "\n".join(lines).strip() + ("\n" if rendered else "")


def main() -> int:
    parser = HtmlToLatexParser()
    parser.feed(sys.stdin.read())
    parser.close()
    sys.stdout.write(parser.get_output())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
