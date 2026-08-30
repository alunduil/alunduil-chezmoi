#!/usr/bin/env python3
"""Check a data flow diagram's levels against the dfd skill's rules.

Python among bash siblings: the body is markdown and Mermaid parsing plus set
algebra over flow names.

Two classes of finding, neither visible to a linter. Balancing: a child
diagram's boundary-crossing flows match its parent process's exactly, and the
context level, which names systems rather than flows, matches level 0's
external entities. Drawing: a process with no input is a miracle, one with no
output a black hole, and a flow between two passive elements is missing the
process that transforms it.

Levels come from the process numbering, so adding one needs no change here:
`N.0` is level 0, `N.M` decomposes `N.0`.
"""

import argparse
import pathlib
import re
import sys

DEFAULT_DOC = "docs/explanation/data-flow.md"
TOP = ".0"

BLOCK = re.compile(r"```mermaid\n(.*?)```", re.S)
EDGE = re.compile(r"^\s*(\w+)\s*-->\|([^|]+)\|\s*(\w+)\s*$")
PROCESS = re.compile(r"^\s*(\w+)\(\s*(\d+(?:\.\d+)+)\s+[^)]*\)")
STORE = re.compile(r"^\s*(\w+)\[\(")
ENTITY = re.compile(r"^\s*(\w+)\[(?!\()([^\]]+)\]")
NAMED = re.compile(r"^- \*\*([^*]+)\*\*", re.M)
CONTEXT = re.compile(r"## Context\n(.*?)\n## ", re.S)


class Malformed(Exception):
    """The document isn't shaped like a DFD, so no finding can be trusted."""


class Level:
    """One Mermaid block from the document."""

    def __init__(self, body):
        self.edges, self.processes, self.stores = [], {}, set()
        self.entities, self.boundaries = {}, {}
        current = None
        for line in body.splitlines():
            stripped = line.strip()
            if match := re.match(r"subgraph\s+(\w+)", stripped):
                current = match.group(1)
                self.boundaries[current] = set()
                continue
            if stripped == "end":
                current = None
                continue
            if match := EDGE.match(line):
                self.edges.append((match.group(1), match.group(2).strip(), match.group(3)))
                continue
            node = None
            if match := PROCESS.match(stripped):
                node = match.group(1)
                self.processes[node] = match.group(2)
            elif match := STORE.match(stripped):
                node = match.group(1)
                self.stores.add(node)
            elif match := ENTITY.match(stripped):
                node = match.group(1)
                self.entities[node] = match.group(2)
            if node and current:
                self.boundaries[current].add(node)

    def inflows(self, node):
        return {flow for _, flow, target in self.edges if target == node}

    def outflows(self, node):
        return {flow for source, flow, _ in self.edges if source == node}

    def crossing_in(self, inside):
        return {f for s, f, t in self.edges if s not in inside and t in inside}

    def crossing_out(self, inside):
        return {f for s, f, t in self.edges if s in inside and t not in inside}

    def children(self):
        """Processes decomposing a parent."""
        return {n: v for n, v in self.processes.items() if not v.endswith(TOP)}

    def is_top(self):
        return bool(self.processes) and not self.children()

    def parent_number(self):
        """The level 0 process this diagram opens up."""
        parents = {v.split(".")[0] + TOP for v in self.children().values()}
        return parents.pop() if len(parents) == 1 else None

    def name(self):
        """How a finding refers to this diagram."""
        if self.is_top():
            return "level 0"
        if parent := self.parent_number():
            return f"the {parent} decomposition"
        return "an unattached diagram"

    def system_boundary(self):
        """The subgraph holding the processes — everything else is outside."""
        for members in self.boundaries.values():
            if members & set(self.processes):
                return members
        return set()

    def outside(self):
        inside = self.system_boundary()
        return {n: lab for n, lab in self.entities.items() if n not in inside}


def describes(node, label, name):
    """Whether a context entry names this level 0 entity."""
    return node.lower() in name.replace(" ", "") or label.lower() == name


def compare(subject, parent, child):
    return [f"{subject}: parent has {flow!r}, decomposition does not" for flow in sorted(parent - child)] + [
        f"{subject}: decomposition has {flow!r}, parent does not" for flow in sorted(child - parent)
    ]


def parse(source):
    blocks = [Level(b) for b in BLOCK.findall(source)]
    # Guard the silent pass: a parser that matches nothing reports no findings,
    # which reads identically to a clean document.
    if not blocks:
        raise Malformed("no mermaid blocks found")
    tops = [b for b in blocks if b.is_top()]
    if len(tops) != 1:
        raise Malformed(f"expected one level 0 diagram, found {len(tops)}")
    return blocks, tops[0]


def context_systems(source):
    section = CONTEXT.search(source)
    if not section:
        raise Malformed("no '## Context' section found")
    named = {m.lower().rstrip(".") for m in NAMED.findall(section.group(1))}
    if not named:
        raise Malformed("context section names no systems")
    return named


def check_context(top, named):
    outside = top.outside()
    if not outside:
        raise Malformed("level 0 has no external entities")
    findings = []
    for node, label in sorted(outside.items()):
        if not any(describes(node, label, n) for n in named):
            findings.append(f"context: level 0 has {label!r}, context describes no such system")
    for name in sorted(named):
        if not any(describes(n, lab, name) for n, lab in outside.items()):
            findings.append(f"context: describes {name!r}, level 0 has no such entity")
    return findings


def check_balance(blocks, top):
    # A parent is a level 0 process by definition, so an unresolvable one is a
    # finding: a comparison skipped for want of a parent reads as a balanced one.
    parents = {number: node for node, number in top.processes.items()}
    findings = []
    for block in blocks:
        if block.is_top() or not block.children():
            continue
        number = block.parent_number()
        if number is None:
            findings.append(f"{block.name()} mixes parents")
            continue
        parent = parents.get(number)
        if parent is None:
            findings.append(f"{block.name()} decomposes {number}, which level 0 does not have")
            continue
        kids = set(block.children())
        findings += compare(f"{number} inflow", top.inflows(parent), block.crossing_in(kids))
        findings += compare(f"{number} outflow", top.outflows(parent), block.crossing_out(kids))
    return findings


def check_drawing(blocks):
    findings = []
    for block in blocks:
        passive = block.stores | set(block.entities)
        for node in sorted(block.processes):
            number = block.processes[node]
            if not block.inflows(node):
                findings.append(f"{block.name()}: {number} has no input (miracle)")
            if not block.outflows(node):
                findings.append(f"{block.name()}: {number} has no output (black hole)")
        for source, flow, target in block.edges:
            if source in passive and target in passive:
                findings.append(
                    f"{block.name()}: {flow!r} runs between two passive elements "
                    f"({source} to {target}); a process belongs between them"
                )
    return findings


def review(source):
    """Every finding in a document, or Malformed if it isn't a DFD."""
    blocks, top = parse(source)
    named = context_systems(source)
    return check_context(top, named) + check_balance(blocks, top) + check_drawing(blocks)


def main():
    parser = argparse.ArgumentParser(
        description="Check a data flow diagram's levels balance and obey the drawing rules.",
    )
    parser.add_argument(
        "doc",
        nargs="?",
        default=DEFAULT_DOC,
        type=pathlib.Path,
        help=f"markdown document holding the diagram (default: {DEFAULT_DOC})",
    )
    args = parser.parse_args()

    if not args.doc.is_file():
        parser.error(f"no such document: {args.doc}")

    try:
        findings = review(args.doc.read_text())
    except Malformed as problem:
        parser.error(f"{args.doc}: {problem}")

    if findings:
        for finding in findings:
            print(f"{args.doc}: {finding}", file=sys.stderr)
        return 1
    print(f"OK: {args.doc}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
