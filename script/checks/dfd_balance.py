#!/usr/bin/env python3
"""Check a data flow diagram's levels against the dfd skill's rules.

Python among bash siblings: the body is markdown and Mermaid parsing plus set
algebra over flow names.

Two classes of finding, neither visible to a linter. Balancing: a child
diagram's boundary-crossing flows match its parent process's exactly, and
level 0 names the same external entities as the context diagram. Drawing: a
process with no input is a miracle, one with no output a black hole, and a
flow between two passive elements is missing the process that transforms it.

Levels come from the process numbering, so adding one needs no change here:
`0` is the context, `N.0` is level 0, `N.M` decomposes `N.0`, and `N.M.K`
decomposes `N.M`. A diagram's own processes are its deepest-numbered ones;
shallower processes are neighbours drawn for reference.

Scope is the third class. Every claim in a DFD holds with no adversary in
the world, so vocabulary that only makes sense once there is one marks a
conclusion the threat model should reach on its own.
"""

import argparse
import pathlib
import re
import sys

DEFAULT_DOC = "docs/reference/data-flow.md"
ROOT = "0"

BLOCK = re.compile(r"```mermaid\n(.*?)```", re.S)
EDGE = re.compile(r"^\s*(\w+)\s*-->\|([^|]+)\|\s*(\w+)\s*$")
PROCESS = re.compile(r"^\s*(\w+)\(\s*(\d+(?:\.\d+)*)\s+[^)]*\)")
STORE = re.compile(r"^\s*(\w+)\[\(([^)]+)\)\]")
ENTITY = re.compile(r"^\s*(\w+)\[(?!\()([^\]]+)\]")
FENCE = re.compile(r"^\s*```")
# "threat model" itself stays legal: a DFD may say where the rest of the
# analysis lives, it just may not do it.
ANALYSIS = re.compile(
    r"\b(compromis\w*|attacker\w*|adversar\w*|blast radius|mitigat\w*|exfiltrat\w*|in the clear)\b",
    re.I,
)


class Malformed(Exception):
    """The document isn't shaped like a DFD, so no finding can be trusted."""


def depth(number):
    """0 for the context process, 1 for `N.0`, and one more per part below."""
    if number == ROOT:
        return 0
    parts = number.split(".")
    return 1 if len(parts) == 2 and parts[1] == "0" else len(parts)


def parent_of(number):
    parts = number.split(".")
    if len(parts) == 2 and parts[1] == "0":
        return ROOT
    if len(parts) == 2:
        return f"{parts[0]}.0"
    return ".".join(parts[:-1])


class Level:
    """One Mermaid block from the document."""

    def __init__(self, body):
        self.edges, self.processes, self.stores = [], {}, {}
        self.entities, self.boundaries = {}, {}
        enclosing = []
        for line in body.splitlines():
            stripped = line.strip()
            if match := re.match(r"subgraph\s+(\w+)", stripped):
                enclosing.append(match.group(1))
                self.boundaries[match.group(1)] = set()
                continue
            if stripped == "end":
                enclosing.pop()
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
                self.stores[node] = match.group(2)
            elif match := ENTITY.match(stripped):
                node = match.group(1)
                self.entities[node] = match.group(2)
            for boundary in enclosing if node else ():
                self.boundaries[boundary].add(node)

    def inflows(self, node):
        return {flow for _, flow, target in self.edges if target == node}

    def outflows(self, node):
        return {flow for source, flow, _ in self.edges if source == node}

    def crossing_in(self, inside):
        return {f for s, f, t in self.edges if s not in inside and t in inside}

    def crossing_out(self, inside):
        return {f for s, f, t in self.edges if s in inside and t not in inside}

    def depth(self):
        return max((depth(n) for n in self.processes.values()), default=None)

    def own(self):
        """The processes this diagram is about, deepest-numbered first."""
        deepest = self.depth()
        return {n: v for n, v in self.processes.items() if depth(v) == deepest}

    def parent_number(self):
        """The process this diagram opens up, or None for the context."""
        parents = {parent_of(v) for v in self.own().values() if v != ROOT}
        return parents.pop() if len(parents) == 1 else None

    def name(self):
        """How a finding refers to this diagram."""
        if self.depth() == 0:
            return "context"
        if self.depth() == 1:
            return "level 0"
        if parent := self.parent_number():
            return f"the {parent} decomposition"
        return "an unattached diagram"

    def system_boundary(self):
        """Nodes inside any subgraph holding one of this diagram's processes."""
        own = set(self.own())
        inside = set()
        for members in self.boundaries.values():
            if members & own:
                inside |= members
        return inside

    def outside(self):
        inside = self.system_boundary()
        return {n: lab for n, lab in self.entities.items() if n not in inside}


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
    contexts = [b for b in blocks if b.depth() == 0]
    if len(contexts) != 1:
        raise Malformed(f"expected one context diagram, found {len(contexts)}")
    tops = [b for b in blocks if b.depth() == 1]
    if len(tops) != 1:
        raise Malformed(f"expected one level 0 diagram, found {len(tops)}")
    return blocks, contexts[0], tops[0]


def check_context(context, top):
    outside = set(top.outside().values())
    if not outside:
        raise Malformed("level 0 has no external entities")
    named = set(context.entities.values())
    return [f"context: level 0 has {label!r}, context does not" for label in sorted(outside - named)] + [
        f"context: has {label!r}, level 0 does not" for label in sorted(named - outside)
    ]


def check_balance(blocks):
    # An unresolvable parent is a finding: a comparison skipped for want of a
    # parent reads as a balanced one.
    owners = {}
    for block in blocks:
        for node, number in block.own().items():
            owners[number] = (block, node)
    findings = []
    for block in blocks:
        if not block.processes or block.depth() == 0:
            continue
        number = block.parent_number()
        if number is None:
            findings.append(f"{block.name()} mixes parents")
            continue
        if number not in owners:
            findings.append(f"{block.name()} decomposes {number}, which no diagram draws")
            continue
        parent_block, parent = owners[number]
        # A store the parent diagram already draws sits outside the process
        # being opened up; one first drawn here is internal to it.
        known = set(parent_block.stores.values())
        inside = set(block.own()) | {n for n, lab in block.stores.items() if lab not in known}
        findings += compare(f"{number} inflow", parent_block.inflows(parent), block.crossing_in(inside))
        findings += compare(f"{number} outflow", parent_block.outflows(parent), block.crossing_out(inside))
    return findings


def check_drawing(blocks):
    findings = []
    for block in blocks:
        passive = set(block.stores) | set(block.entities)
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


def check_scope(source):
    findings = []
    fenced = False
    for number, line in enumerate(source.splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        for word in ANALYSIS.findall(line):
            findings.append(
                f"line {number}: {word!r} reasons about an adversary; "
                f"state the flow and leave the conclusion to the threat model"
            )
    return findings


def review(source):
    """Every finding in a document, or Malformed if it isn't a DFD."""
    blocks, context, top = parse(source)
    return check_context(context, top) + check_balance(blocks) + check_drawing(blocks) + check_scope(source)


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
