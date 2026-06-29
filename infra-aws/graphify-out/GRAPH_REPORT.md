# Graph Report - infra-aws  (2026-06-29)

## Corpus Check
- 3 files · ~909 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 14 nodes · 11 edges · 3 communities (1 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `eb61e719`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]

## God Nodes (most connected - your core abstractions)
1. `Infrastructure as Code — Terraform` - 8 edges
2. `Statement` - 1 edges
3. `setup-eks-post.sh script` - 1 edges
4. `Resources` - 1 edges
5. `Other Resources` - 1 edges
6. `IAM / OIDC` - 1 edges
7. `Helm Releases (deployed via Terraform)` - 1 edges
8. `Secrets` - 1 edges
9. `State` - 1 edges
10. `Usage` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (3 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.22
Nodes (8): Helm Releases (deployed via Terraform), IAM / OIDC, Infrastructure as Code — Terraform, Other Resources, Resources, Secrets, State, Usage

## Knowledge Gaps
- **10 isolated node(s):** `Version`, `Statement`, `setup-eks-post.sh script`, `Resources`, `Other Resources` (+5 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `Version`, `Statement`, `setup-eks-post.sh script` to the rest of the system?**
  _10 weakly-connected nodes found - possible documentation gaps or missing edges._