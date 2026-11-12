#!/usr/bin/env python3
import argparse
import json
import re
import sys

QUESTION = re.compile(r"^Q\.?\s*(\d+)[.:)]?\s*(.*)$")
ANSWER = re.compile(r"^A[.:)]\s*(.*)$")
NUMBERED = re.compile(r"^\[([^\]]+)\]\s*(.*)$")


class Sections:
    def __init__(self):
        self.items = []
        self.current = None

    def start(self, title=None):
        self.current = {"blocks": []}
        if title:
            self.current["title"] = title
        self.items.append(self.current)

    def add(self, block):
        if self.current is None:
            self.start()
        self.current["blocks"].append(block)
        return block


def proofs(line):
    return [item.strip() for item in line[2:].split(";") if item.strip()]


def parse_qa(text):
    sections = Sections()
    block = None
    field = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("## "):
            sections.start(line[3:].strip())
            block = field = None
            continue
        question = QUESTION.match(line)
        if question:
            block = sections.add({
                "type": "qa",
                "number": int(question.group(1)),
                "question": question.group(2).strip(),
                "answer": "",
            })
            field = "question"
            continue
        if block is None:
            continue
        if line.startswith("P:"):
            block["proofs"] = proofs(line)
            field = None
            continue
        answer = ANSWER.match(line)
        if answer:
            block["answer"] = answer.group(1).strip()
            field = "answer"
        elif field:
            block[field] = f"{block[field]} {line}".strip()
    for section in sections.items:
        for block in section["blocks"]:
            if not block["answer"]:
                sys.exit(f"question {block['number']} has no answer")
    return sections.items


def parse_prose(text):
    sections = Sections()
    paragraph = []
    number = None
    last = None

    def flush():
        nonlocal paragraph, number, last
        if paragraph:
            block = {"type": "paragraph", "text": " ".join(paragraph)}
            if number:
                block["number"] = number
            last = sections.add(block)
        paragraph, number = [], None

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            flush()
        elif line.startswith("## "):
            flush()
            sections.start(line[3:].strip())
            last = None
        elif line.startswith("# "):
            continue
        elif line.startswith("P:"):
            flush()
            if last is not None:
                last["proofs"] = proofs(line)
        else:
            if not paragraph:
                match = NUMBERED.match(line)
                if match:
                    number, line = match.group(1), match.group(2)
            paragraph.append(line)
    flush()
    return sections.items


def main():
    parser = argparse.ArgumentParser(
        description="Convert plain text into a Berean library JSON document."
    )
    parser.add_argument("mode", choices=["qa", "prose"])
    parser.add_argument("input")
    parser.add_argument("--id", required=True)
    parser.add_argument("--kind", required=True)
    parser.add_argument("--language", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--subtitle")
    parser.add_argument("--tradition")
    parser.add_argument("--source")
    parser.add_argument("--license")
    parser.add_argument("--order", type=int)
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as handle:
        text = handle.read()
    sections = parse_qa(text) if args.mode == "qa" else parse_prose(text)
    if not sections:
        sys.exit("no content found")

    document = {"id": args.id, "kind": args.kind, "language": args.language}
    for key in ("order", "title", "subtitle", "tradition", "source", "license"):
        value = getattr(args, key)
        if value is not None:
            document[key] = value
    document["sections"] = sections
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
