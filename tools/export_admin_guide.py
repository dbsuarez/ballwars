"""Export the bundled in-app help into a readable Markdown reference.
Run from the repository root: python tools/export_admin_guide.py
The JSON catalog is the shared source; this script never changes skill data.
"""
import json
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail if the Markdown reference is out of date.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    data = json.loads((root / "assets/help/admin_guide.json").read_text(encoding="utf-8"))
    articles = data["articles"]
    titles = {article["id"]: article["title"] for article in articles}
    lines = ["# Ball Wars Admin Guide", "",
             "Generated from `assets/help/admin_guide.json`. Edit the catalog, then run `python tools/export_admin_guide.py` to refresh this reference.", "",
             "Open Admin Settings > General > Admin Guide, or Read full guide from a skill editor info dialog. Editor info dialogs link to the relevant topic. Help is read-only and preserves the draft beneath it.", ""]
    for tab, label in [("tutorials", "Tutorials"), ("how", "How it works"), ("parameters", "Parameter reference")]:
        lines += [f"## {label}", ""]
        for article in articles:
            if article["tab"] != tab:
                continue
            lines += [f'- [{article["title"]}](#{article["id"]})']
        lines.append("")
    for article in articles:
        lines += [f'<a id="{article["id"]}"></a>', f'## {article["title"]}', "", article["summary"], ""]
        if article.get("diagram"):
            lines += ["`Held item -> Casting -> Projectile -> Impact / zone`", "",
                      "This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.", ""]
        for section in article["sections"]:
            lines += [f'### {section["title"]}', ""]
            if section.get("where"):
                lines += [f'Where: {section["where"]}', ""]
            lines += [section["body"], ""]
            if section.get("example"):
                lines += [f'Example: {section["example"]}', ""]
            if section.get("check"):
                lines += [f'What to check: {section["check"]}', ""]
        if article.get("related"):
            lines += ["Related: " + ", ".join(f'[{titles[id]}](#{id})' for id in article["related"]), ""]
    output = root / "docs/ADMIN-GUIDE.md"
    rendered = "\n".join(lines)
    if args.check:
        if not output.exists() or output.read_text(encoding="utf-8") != rendered:
            raise SystemExit('Admin guide Markdown is stale. Run python tools/export_admin_guide.py')
        print('Admin guide Markdown is current.')
        return
    output.write_text(rendered, encoding="utf-8")
    print(f"Exported {len(articles)} topics to {output.name}")


if __name__ == "__main__":
    main()
