import json
import os
import re
import subprocess
from typing import Any, Dict, Iterable, List, Tuple

from nvim_doc_tools.apidoc import parse_functions, render_api_md, render_api_vimdoc
from nvim_doc_tools.util import (
    MD_LINK_PAT,
    Vimdoc,
    VimdocSection,
    dedent,
    format_md_table,
    generate_md_toc,
    indent,
    leftright,
    md_create_anchor,
    read_section,
    replace_section,
    wrap,
)

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc")
VIMDOC = os.path.join(DOC, "resession.txt")



def update_config_options():
    config_file = os.path.join(ROOT, "lua", "resession", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    replace_section(
        README,
        r"^<!-- Setup -->$",
        r"^<!-- /Setup -->$",
        ['\n', '```lua\n', 'require("resession").setup({\n'] + opt_lines + ['})\n', '```\n', '\n'],
    )


def get_options_vimdoc() -> "VimdocSection":
    section = VimdocSection("options", "resession-options")
    config_file = os.path.join(ROOT, "lua", "resession", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    lines = ["\n", ">\n", '    require("resession").setup({\n']
    lines.extend(indent(opt_lines, 4))
    lines.extend(["    })\n", "<\n"])
    section.body = lines
    return section



def generate_vimdoc():
    doc = Vimdoc("resession.txt", "resession")
    funcs = parse_functions(os.path.join(ROOT, 'lua', 'resession', 'init.lua'))
    doc.sections.extend(
        [
            get_options_vimdoc(),
            VimdocSection("API", "resession-api", render_api_vimdoc('resession', funcs)),
        ]
    )

    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def update_md_api():
    funcs = parse_functions(os.path.join(ROOT, 'lua', 'resession', 'init.lua'))
    lines = ["\n"] + render_api_md(funcs) + ["\n"]
    replace_section(
        README,
        r"^<!-- API -->$",
        r"^<!-- /API -->$",
        lines,
    )


def update_md_toc(filename: str):
    toc = ["\n"] + generate_md_toc(filename) + ["\n"]
    replace_section(
        filename,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )


def add_md_link_path(path: str, lines: List[str]) -> List[str]:
    ret = []
    for line in lines:
        ret.append(re.sub(r"(\(#)", "(" + path + "#", line))
    return ret


def main() -> None:
    """Update the README"""
    update_config_options()
    update_md_api()
    update_md_toc(README)
    generate_vimdoc()