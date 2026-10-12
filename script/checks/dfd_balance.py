#!/usr/bin/env python3
"""Check a data flow diagram against the dfd skill's rules.

Three classes of finding:

- Balancing: a child diagram's boundary-crossing flows match its parent
  process's exactly, and level 0 names the context diagram's entities.
- Drawing: a process with no input is a miracle, one with no output a black
  hole, and a flow between two passive elements lacks its process.
- Scope: a DFD's claims hold with no adversary, so prose that needs one draws
  a conclusion belonging to the threat model.

Levels come from process numbering, so a new level needs no change here.
"""

import argparse
import pathlib
import re
import sys
from typing import NamedTuple

DEFAULT_DOC = "docs/reference/data-flow.md"
ROOT = "0"

BLOCK = re.compile(r"```mermaid\n(.*?)```", re.S)
EDGE = re.compile(r"^\s*(\w+)\s*-->\|([^|]+)\|\s*(\w+)\s*$")
PROCESS = re.compile(r"^\s*(\w+)\(\s*(\d+(?:\.\d+)*)\s+[^)]*\)")
STORE = re.compile(r"^\s*(\w+)\[\(([^)]+)\)\]")
ENTITY = re.compile(r"^\s*(\w+)\[(?!\()([^\]]+)\]")
FENCE = re.compile(r"^\s*```")
# Leaves out "threat model": a DFD may point at the threat model, not do its
# work.
ANALYSIS = re.compile(
    r"\b(compromis\w*|attacker\w*|adversar\w*|blast radius|mitigat\w*|exfiltrat\w*|in the clear)\b",
    re.I,
)


class Malformed(Exception):
    """The document isn't shaped like a DFD, so no finding can be trusted."""


class ProcessNumber(str):
    """`0` is the context, `N.0` level 0, `N.M` decomposes `N.0`, and so on."""

    def _parts(self):
        return self.split(".")

    def _is_level_zero(self):
        parts = self._parts()
        return len(parts) == 2 and parts[1] == "0"

    @property
    def depth(self):
        if self == ROOT:
            return 0
        return 1 if self._is_level_zero() else len(self._parts())

    @property
    def parent(self):
        """The process this one decomposes, or None for the context."""
        if self == ROOT:
            return None
        if self._is_level_zero():
            return ProcessNumber(ROOT)
        parts = self._parts()
        if len(parts) == 2:
            return ProcessNumber(f"{parts[0]}.0")
        return ProcessNumber(".".join(parts[:-1]))


class Flow(NamedTuple):
    source: str
    name: str
    target: str


class Diagram:
    """One Mermaid block from the document."""

    def __init__(self, body):
        self.flows, self.processes, self.stores = [], {}, {}
        self.entities, self.boundaries = {}, {}
        enclosing = []
        for line in body.splitlines():
            stripped = line.strip()
            if match := re.match(r"subgraph\s+(\w+)", stripped):
                enclosing.append(match.group(1))
                self.boundaries[match.group(1)] = set()
            elif stripped == "end":
                enclosing.pop()
            elif match := EDGE.match(line):
                self.flows.append(Flow(match.group(1), match.group(2).strip(), match.group(3)))
            elif node := self._declare(stripped):
                for boundary in enclosing:
                    self.boundaries[boundary].add(node)

    def _declare(self, line):
        """Record a node declaration; return its id, or None for any other line."""
        if match := PROCESS.match(line):
            self.processes[match.group(1)] = ProcessNumber(match.group(2))
        elif match := STORE.match(line):
            self.stores[match.group(1)] = match.group(2)
        elif match := ENTITY.match(line):
            self.entities[match.group(1)] = match.group(2)
        return match.group(1) if match else None

    def flows_into(self, nodes):
        return {f.name for f in self.flows if f.source not in nodes and f.target in nodes}

    def flows_out_of(self, nodes):
        return {f.name for f in self.flows if f.source in nodes and f.target not in nodes}

    def depth(self):
        return max((n.depth for n in self.processes.values()), default=None)

    def subjects(self):
        """The processes this diagram is about: its deepest-numbered ones.
        Shallower processes are neighbours drawn for reference."""
        deepest = self.depth()
        return {n: v for n, v in self.processes.items() if v.depth == deepest}

    def parent_number(self):
        """The process this diagram opens up, or None for the context."""
        parents = {v.parent for v in self.subjects().values()}
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
        """Nodes inside any subgraph holding one of this diagram's subjects."""
        subjects = set(self.subjects())
        inside = set()
        for members in self.boundaries.values():
            if members & subjects:
                inside |= members
        return inside

    def outside(self):
        inside = self.system_boundary()
        return {n: lab for n, lab in self.entities.items() if n not in inside}

    def interior(self, parent):
        """The nodes inside the process this diagram opens up. A store the
        parent diagram already draws sits outside it; one first drawn here
        is internal."""
        known = set(parent.stores.values())
        return set(self.subjects()) | {n for n, lab in self.stores.items() if lab not in known}


def compare(subject, parent, child):
    return [f"{subject}: parent has {flow!r}, decomposition does not" for flow in sorted(parent - child)] + [
        f"{subject}: decomposition has {flow!r}, parent does not" for flow in sorted(child - parent)
    ]


def parse(source):
    """The diagrams, the context, and level 0, or Malformed when the document
    lacks the shape every check below assumes."""
    diagrams = [Diagram(b) for b in BLOCK.findall(source)]
    # Guard the silent pass: a parser that matches nothing reports no findings,
    # which reads identically to a clean document.
    if not diagrams:
        raise Malformed("no mermaid blocks found")
    contexts = [d for d in diagrams if d.depth() == 0]
    if len(contexts) != 1:
        raise Malformed(f"expected one context diagram, found {len(contexts)}")
    tops = [d for d in diagrams if d.depth() == 1]
    if len(tops) != 1:
        raise Malformed(f"expected one level 0 diagram, found {len(tops)}")
    if not tops[0].outside():
        raise Malformed("level 0 has no external entities")
    return diagrams, contexts[0], tops[0]


def check_context(context, top):
    outside = set(top.outside().values())
    named = set(context.entities.values())
    return [f"context: level 0 has {label!r}, context does not" for label in sorted(outside - named)] + [
        f"context: has {label!r}, level 0 does not" for label in sorted(named - outside)
    ]


def check_balance(diagrams):
    owners = {number: (diagram, node) for diagram in diagrams for node, number in diagram.subjects().items()}
    findings = []
    for diagram in diagrams:
        if diagram.depth() in (None, 0):
            continue
        # An unresolvable parent is a finding: a comparison skipped for want
        # of a parent reads as a balanced one.
        number = diagram.parent_number()
        if number is None:
            findings.append(f"{diagram.name()} mixes parents")
            continue
        if number not in owners:
            findings.append(f"{diagram.name()} decomposes {number}, which no diagram draws")
            continue
        parent, node = owners[number]
        inside = diagram.interior(parent)
        findings += compare(f"{number} inflow", parent.flows_into({node}), diagram.flows_into(inside))
        findings += compare(f"{number} outflow", parent.flows_out_of({node}), diagram.flows_out_of(inside))
    return findings


def check_drawing(diagrams):
    findings = []
    for diagram in diagrams:
        passive = set(diagram.stores) | set(diagram.entities)
        for node, number in sorted(diagram.processes.items()):
            if not diagram.flows_into({node}):
                findings.append(f"{diagram.name()}: {number} has no input (miracle)")
            if not diagram.flows_out_of({node}):
                findings.append(f"{diagram.name()}: {number} has no output (black hole)")
        for flow in diagram.flows:
            if flow.source in passive and flow.target in passive:
                findings.append(
                    f"{diagram.name()}: {flow.name!r} runs between two passive elements "
                    f"({flow.source} to {flow.target}); a process belongs between them"
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
    diagrams, context, top = parse(source)
    return check_context(context, top) + check_balance(diagrams) + check_drawing(diagrams) + check_scope(source)


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
