#!/usr/bin/env python3
import json
import os

BOOKS = [
    ("GEN", 50), ("EXO", 40), ("LEV", 27), ("NUM", 36), ("DEU", 34), ("JOS", 24),
    ("JDG", 21), ("RUT", 4), ("1SA", 31), ("2SA", 24), ("1KI", 22), ("2KI", 25),
    ("1CH", 29), ("2CH", 36), ("EZR", 10), ("NEH", 13), ("EST", 10), ("JOB", 42),
    ("PSA", 150), ("PRO", 31), ("ECC", 12), ("SNG", 8), ("ISA", 66), ("JER", 52),
    ("LAM", 5), ("EZK", 48), ("DAN", 12), ("HOS", 14), ("JOL", 3), ("AMO", 9),
    ("OBA", 1), ("JON", 4), ("MIC", 7), ("NAM", 3), ("HAB", 3), ("ZEP", 3),
    ("HAG", 2), ("ZEC", 14), ("MAL", 4), ("MAT", 28), ("MRK", 16), ("LUK", 24),
    ("JHN", 21), ("ACT", 28), ("ROM", 16), ("1CO", 16), ("2CO", 13), ("GAL", 6),
    ("EPH", 6), ("PHP", 4), ("COL", 4), ("1TH", 5), ("2TH", 3), ("1TI", 6),
    ("2TI", 4), ("TIT", 3), ("PHM", 1), ("HEB", 13), ("JAS", 5), ("1PE", 5),
    ("2PE", 3), ("1JN", 5), ("2JN", 1), ("3JN", 1), ("JUD", 1), ("REV", 22),
]

NEW_TESTAMENT = [code for code, _ in BOOKS[BOOKS.index(("MAT", 28)):]]

OUTPUT = os.path.join(os.path.dirname(__file__), "..", "Berean", "Resources", "Plans")


def chapters(codes):
    return [(code, n) for code, count in BOOKS if code in codes for n in range(1, count + 1)]


def distribute(items, days):
    return [
        [f"{code} {chapter}" for code, chapter in items[day * len(items) // days:(day + 1) * len(items) // days]]
        for day in range(days)
    ]


PLANS = [
    ("bible-in-a-year", "The Bible in a Year", "Genesis to Revelation in 365 days",
     [code for code, _ in BOOKS], 365),
    ("new-testament-90", "The New Testament in 90 Days", "Matthew to Revelation",
     NEW_TESTAMENT, 90),
    ("gospels-30", "The Gospels in 30 Days", "Matthew, Mark, Luke and John",
     ["MAT", "MRK", "LUK", "JHN"], 30),
    ("psalms-30", "The Psalms in 30 Days", "Five psalms a day", ["PSA"], 30),
    ("proverbs-31", "Proverbs in a Month", "One chapter a day", ["PRO"], 31),
]


def main():
    assert len(chapters([code for code, _ in BOOKS])) == 1189
    os.makedirs(OUTPUT, exist_ok=True)
    for order, (plan_id, title, subtitle, codes, days) in enumerate(PLANS, start=1):
        schedule = distribute(chapters(codes), days)
        assert all(schedule), plan_id
        plan = {"id": plan_id, "order": order, "title": title, "subtitle": subtitle, "days": schedule}
        path = os.path.join(OUTPUT, f"plan-{plan_id}.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(plan, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        print(path, len(schedule), "days")


if __name__ == "__main__":
    main()
