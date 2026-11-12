
#!/usr/bin/env python3
import argparse
import re
import sys

QUESTION = re.compile(r"^(\d+)\.\s*(.*)$")
ANSWER = re.compile(r"^Resposta\.\s*(.*)$", re.IGNORECASE)


def preprocess(text):
    output = []
    field = None

    for raw in text.splitlines():
        line = raw.strip()

        if not line:
            continue

        question = QUESTION.match(line)
        if question:
            output.append(f"Q{question.group(1)}. {question.group(2)}")
            field = "question"
            continue

        answer = ANSWER.match(line)
        if answer:
            output.append(f"A. {answer.group(1)}")
            field = "answer"
            continue

        if field == "question":
            output.append(f"A. {line}")
            field = "answer"
        elif field == "answer":
            output.append(f"P: {line}")
            field = None

    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as file:
        text = file.read()

    sys.stdout.write(preprocess(text))


if __name__ == "__main__":
    main()
