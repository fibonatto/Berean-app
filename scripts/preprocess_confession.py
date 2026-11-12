#!/usr/bin/env python3
import argparse
import re
import sys

CHAPTER = re.compile(r"^CAPÍTULO\s+([IVXLCDM]+)\s*$", re.IGNORECASE)
PARAGRAPH = re.compile(r"^([IVXLCDM]+)\s*\.\s*(.+)$", re.IGNORECASE)
PARAGRAPH_NO_DOT = re.compile(r"^([IVXLCDM]+)\s+(Pela presença\b.+)$", re.IGNORECASE)
VERSE_REFERENCE = re.compile(r"\b\d{1,3}\s*:\s*\d{1,3}\b")


def is_reference(line):
    return bool(VERSE_REFERENCE.search(line))


def is_chapter_title(line):
    return any(char.isalpha() for char in line) and line == line.upper()


def preprocess(text):
    output = []
    in_chapter = False
    waiting_for_title = False
    title_parts = []
    paragraph = []

    def flush_paragraph():
        nonlocal paragraph
        if paragraph:
            output.append("[{}] {}".format(paragraph[0][0], " ".join(part[1] for part in paragraph)))
            paragraph = []

    def flush_title():
        nonlocal title_parts, waiting_for_title
        if title_parts:
            output.append("## " + " ".join(title_parts))
            title_parts = []
        waiting_for_title = False

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        chapter = CHAPTER.match(line)
        if chapter:
            flush_paragraph()
            flush_title()
            in_chapter = True
            waiting_for_title = True
            title_parts = [f"CAPÍTULO {chapter.group(1).upper()}"]
            continue

        if not in_chapter:
            continue

        if line.casefold() == "apêndice":
            flush_paragraph()
            in_chapter = False
            waiting_for_title = False
            title_parts = []
            continue

        if line.casefold() == "nota histórica":
            flush_paragraph()
            break

        if waiting_for_title and is_chapter_title(line):
            title_parts.append(line)
            continue

        if waiting_for_title:
            flush_title()

        if is_reference(line) and paragraph:
            flush_paragraph()
            output.append("P: " + line)
            continue

        numbered = PARAGRAPH.match(line)
        if numbered is None:
            numbered = PARAGRAPH_NO_DOT.match(line)

        if numbered:
            flush_paragraph()
            paragraph = [(numbered.group(1).upper(), numbered.group(2).strip())]
        elif paragraph:
            paragraph.append((paragraph[0][0], line))

    flush_paragraph()
    flush_title()

    if not output:
        raise ValueError("no confession chapters or paragraphs found")

    return "\n\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Prepare a Westminster Confession text for the Berean prose importer."
    )
    parser.add_argument("input", help="Source .txt file")
    args = parser.parse_args()

    try:
        with open(args.input, encoding="utf-8") as source:
            sys.stdout.write(preprocess(source.read()))
    except (OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
