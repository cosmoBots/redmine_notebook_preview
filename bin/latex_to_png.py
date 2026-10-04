#!/usr/bin/env python3
"""Render LaTeX math to PNG with matplotlib's mathtext (no TeX installation).

stdin:  JSON list of {"id": str, "tex": str, "display": bool}
stdout: JSON object {id: base64 PNG, or null when the formula cannot be rendered}

mathtext covers the common subset (fractions, roots, sums, Greek letters,
sub/superscripts, \\mathbb, \\mathrm ...). Environments such as align or
matrix are not supported and come back as null.
"""
import argparse
import base64
import io
import json
import re
import sys

import matplotlib

matplotlib.use("Agg")
from matplotlib import pyplot as plt  # noqa: E402

matplotlib.rcParams["mathtext.fontset"] = "cm"

DISPLAY_SIZE = 14
INLINE_SIZE = 11


def normalize(tex):
    """Accept what TeX and MathJax accept but mathtext does not.

    TeX takes the single token after \\sqrt as the radicand, so \\sqrt(x) means
    the root of "(" followed by x). mathtext insists on braces.
    """
    tex = " ".join(tex.split())
    return re.sub(r"\\sqrt\s*(\\[A-Za-z]+|[^\s{\[\\])", r"\\sqrt{\1}", tex)


def render(tex, display, dpi):
    tex = normalize(tex)
    if not tex:
        return None
    fig = plt.figure(figsize=(0.01, 0.01))
    try:
        fig.text(0, 0, "$" + tex + "$", fontsize=DISPLAY_SIZE if display else INLINE_SIZE)
        buf = io.BytesIO()
        fig.savefig(
            buf,
            format="png",
            dpi=dpi,
            bbox_inches="tight",
            pad_inches=0.03,
            transparent=True,
        )
        return base64.b64encode(buf.getvalue()).decode("ascii")
    finally:
        plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dpi", type=int, default=220)
    args = parser.parse_args()

    formulas = json.load(sys.stdin)
    result = {}
    for item in formulas:
        try:
            result[item["id"]] = render(item["tex"], bool(item.get("display")), args.dpi)
        except Exception as error:  # an unsupported formula must not stop the rest
            print("%s: %s" % (item.get("id"), error), file=sys.stderr)
            result[item["id"]] = None
    json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
