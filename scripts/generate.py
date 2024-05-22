import os
import re
from typing import List

from nvim_doc_tools import (
    Vimdoc,
    VimdocSection,
    generate_md_toc,
    indent,
    parse_directory,
    read_section,
    render_md_api2,
    render_vimdoc_api2,
    replace_section,
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
        ["\n", "```lua\n", 'require("resession").setup({\n']
        + opt_lines
        + ["})\n", "```\n", "\n"],
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
    types = parse_directory(os.path.join(ROOT, "lua"))
    funcs = types.files["resession/init.lua"].functions
    doc.sections.extend(
        [
            get_options_vimdoc(),
            VimdocSection(
                "API", "resession-api", render_vimdoc_api2("resession", funcs, types)
            ),
        ]
    )

    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def update_md_api():
    types = parse_directory(os.path.join(ROOT, "lua"))
    funcs = types.files["resession/init.lua"].functions
    lines = ["\n"] + render_md_api2(funcs, types)
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
