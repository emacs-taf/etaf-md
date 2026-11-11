#!/usr/bin/env python3
"""Render every mermaid fixture through the preview's own configuration.

The preview draws a diagram with mermaid-cli and a JSON configuration that the
package generates from the page's colors.  A batch Emacs has no frame, so the
configuration is produced here the way a batch session produces it, and only
the geometry and the colours it renders are asserted; appearance is judged in a
graphical session.

Run it with `make mermaid-check`.  `--keep DIR` writes the pictures there so a
person can look at them.
"""
import sys

sys.dont_write_bytecode = True

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "fixtures" / "mermaid"
PROVIDERS = ("etaf", "etaf-ui", "ebox", "ecss")

# Every diagram kind the preview turns into a picture, with the page palettes
# the package ships.  A kind is a fixture file name.
PALETTES = ("dark", "light", "sepia")
PAGES = {"dark": "#191a1c", "light": "#ffffff", "sepia": "#f5ecd9"}

# A category fill has to carry the page's ink, and to be visible on the page at
# all: mermaid derives both from the box colour by darkening it, which turns
# every slice, branch and period black on a dark page.
LABEL_CONTRAST = 4.5
FILL_CONTRAST = 1.25

CONFIG_PROGRAM = """
(progn
  (require 'etaf-md-preview)
  (princ (etaf-md-preview--mermaid-config (list :theme (quote {palette})))))
"""

OVERRIDE_COLOURS = {
    "override-init": "#ff00aa",
    "override-frontmatter": "#00aaff",
}


def luminance(colour):
    def channel(value):
        value = value / 255.0
        return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4

    red, green, blue = (channel(part) for part in colour)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[index : index + 2], 16) for index in (0, 2, 4))


def emacs_config(emacs, palette, directory):
    """Return the configuration the package generates for PALETTE."""
    load_path = ["-L", str(ROOT / "lisp")]
    for name in PROVIDERS:
        load_path += ["-L", str(ROOT.parent / name)]
    command = [emacs, "-Q", "--batch", *load_path, "-L", str(ROOT),
               "--eval", "(setq load-prefer-newer t)",
               "--eval", CONFIG_PROGRAM.format(palette=palette)]
    run = subprocess.run(command, capture_output=True, text=True, timeout=300)
    if run.returncode != 0:
        raise SystemExit("Emacs could not build the %s configuration:\n%s"
                         % (palette, run.stderr.strip()))
    config = json.loads(run.stdout)
    path = directory / ("%s.json" % palette)
    path.write_text(run.stdout)
    return config, path


def render(mmdc, source, config, page, out):
    run = subprocess.run(
        [mmdc, "-i", str(source), "-o", str(out), "-c", str(config),
         "-b", page, "-s", "2", "-q"],
        capture_output=True, text=True, timeout=600)
    return run


def ink(image):
    """Return the width and height of everything that is not the page colour."""
    flat = image.convert("RGB")
    page = Image.new("RGB", flat.size, flat.getpixel((0, 0)))
    box = ImageChops.difference(flat, page).getbbox()
    return None if box is None else (box[2] - box[0], box[3] - box[1])


def check_colours(palette, config, page):
    """Return the problems with the configuration's categorical colours."""
    variables = config["themeVariables"]
    ink_colour = rgb(variables["textColor"])
    problems = []
    fills = []
    for index in range(6):
        fill = rgb(variables["cScale%d" % index])
        hue = rgb(variables["cScaleInv%d" % index])
        label = rgb(variables["cScaleLabel%d" % index])
        fills.append(fill)
        if contrast(label, fill) < LABEL_CONTRAST:
            problems.append("%s: cScale%d label reads %.1f:1 on its fill"
                            % (palette, index, contrast(label, fill)))
        if contrast(fill, rgb(page)) < FILL_CONTRAST:
            problems.append("%s: cScale%d fill is the page" % (palette, index))
        if contrast(hue, rgb(page)) < FILL_CONTRAST:
            problems.append("%s: cScaleInv%d line is the page" % (palette, index))
        for other in ("pie%d" % (index + 1), "git%d" % index):
            if rgb(variables[other]) != fill:
                problems.append("%s: %s left the categorical series"
                                % (palette, other))
        if rgb(variables["cScaleLabel%d" % index]) != ink_colour:
            problems.append("%s: cScaleLabel%d is not the page ink"
                            % (palette, index))
    for index, fill in enumerate(fills[1:], start=1):
        if fill == fills[index - 1]:
            problems.append("%s: cScale%d repeats the previous fill"
                            % (palette, index - 1))
    return problems


def check_override(name, colour, image):
    """Return the problems with a document that sets its own diagram colour."""
    wants = rgb(colour)
    flat = image.convert("RGB")
    page = flat.getpixel((0, 0))
    drawn = [(count, pixel) for count, pixel in flat.getcolors(1 << 24)
             if pixel != page]
    if not drawn:
        return ["%s: nothing drawn" % name]
    common = max(drawn)[1]
    if common != wants:
        return ["%s: document colour %s lost to %s"
                % (name, colour, "#%02x%02x%02x" % common)]
    return []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emacs", default=os.environ.get("EMACS", "emacs"))
    parser.add_argument("--mmdc", default="mmdc")
    parser.add_argument("--only", nargs="*", help="fixture names to render")
    parser.add_argument("--keep", help="write the pictures to this directory")
    parser.add_argument("--list", action="store_true", help="print the fixtures")
    arguments = parser.parse_args()

    fixtures = sorted(FIXTURES.glob("*.mmd"))
    if arguments.only:
        fixtures = [path for path in fixtures if path.stem in arguments.only]
    if arguments.list:
        for path in fixtures:
            print(path.stem)
        return 0
    if not shutil.which(arguments.mmdc):
        raise SystemExit("%s is not installed; install mermaid-cli" % arguments.mmdc)

    failures = []
    with tempfile.TemporaryDirectory(prefix="mermaid-check-") as temporary:
        directory = Path(temporary)
        kept = Path(arguments.keep) if arguments.keep else None
        if kept:
            kept.mkdir(parents=True, exist_ok=True)
        for palette in PALETTES:
            config, path = emacs_config(arguments.emacs, palette, directory)
            page = PAGES[palette]
            problems = check_colours(palette, config, page)
            for problem in problems:
                print("FAIL %s" % problem)
            failures += problems
            for fixture in fixtures:
                name = "%s/%s" % (palette, fixture.stem)
                out = directory / ("%s-%s.png" % (palette, fixture.stem))
                run = render(arguments.mmdc, fixture, path, page, out)
                if not out.exists():
                    failures.append(name)
                    print("FAIL %s: %s" % (name, run.stderr.strip().splitlines()[0]))
                    continue
                image = Image.open(out)
                box = ink(image)
                if image.size[0] < 100 or image.size[1] < 60:
                    failures.append(name)
                    print("FAIL %s: degenerate %dx%d" % (name, *image.size))
                elif box is None or box[0] < 8 or box[1] < 8:
                    failures.append(name)
                    print("FAIL %s: nothing drawn" % name)
                else:
                    print("ok   %-26s %4dx%-4d ink %4dx%-4d"
                          % (name, *image.size, box[0], box[1]))
                if kept:
                    shutil.copyfile(out, kept / out.name)
                if fixture.stem in OVERRIDE_COLOURS:
                    problems = check_override(name, OVERRIDE_COLOURS[fixture.stem],
                                              image)
                    failures += problems
                    for problem in problems:
                        print("FAIL %s" % problem)
    if failures:
        print("\n%d mermaid checks failed" % len(failures))
        return 1
    print("\nmermaid matrix ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
