# Graph Report - my-devops-project  (2026-06-07)

## Corpus Check
- 13 files · ~10,888 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 246 nodes · 718 edges · 22 communities (17 shown, 5 thin omitted)
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 148 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9c6071c9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]

## God Nodes (most connected - your core abstractions)
1. `p()` - 36 edges
2. `Cc()` - 27 edges
3. `B()` - 25 edges
4. `r()` - 25 edges
5. `d()` - 24 edges
6. `a()` - 22 edges
7. `G()` - 21 edges
8. `H()` - 20 edges
9. `Sf()` - 18 edges
10. `K()` - 17 edges

## Surprising Connections (you probably didn't know these)
- `Cc()` --calls--> `t()`  [INFERRED]
  voting-app-result/views/angular.min.js → voting-app-result/views/socket.io.js
- `cd()` --calls--> `t()`  [INFERRED]
  voting-app-result/views/angular.min.js → voting-app-result/views/socket.io.js
- `$d()` --calls--> `t()`  [INFERRED]
  voting-app-result/views/angular.min.js → voting-app-result/views/socket.io.js
- `ib()` --calls--> `t()`  [INFERRED]
  voting-app-result/views/angular.min.js → voting-app-result/views/socket.io.js
- `S()` --calls--> `t()`  [INFERRED]
  voting-app-result/views/angular.min.js → voting-app-result/views/socket.io.js

## Import Cycles
- None detected.

## Communities (22 total, 5 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.13
Nodes (41): B(), bg(), $c(), ce(), $d(), Da(), db(), de() (+33 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (32): $a(), Aa(), Ad(), ae(), bb(), cd(), ea(), eb() (+24 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (24): yf(), a(), at(), Ct(), e(), Et(), f(), G() (+16 more)

### Community 3 - "Community 3"
Cohesion: 0.17
Nodes (24): Bc(), cb(), Cc(), cf(), dc(), Ga(), ha(), hb() (+16 more)

### Community 4 - "Community 4"
Cohesion: 0.10
Nodes (5): Af(), ec(), pd(), qd(), Ta()

### Community 5 - "Community 5"
Cohesion: 0.12
Nodes (16): author, dependencies, async, cookie-parser, express, method-override, pg, socket.io (+8 more)

### Community 6 - "Community 6"
Cohesion: 0.22
Nodes (11): ab(), Kc(), le(), oc(), pc(), Qf(), u(), Vb() (+3 more)

### Community 7 - "Community 7"
Cohesion: 0.31
Nodes (4): ConnectionMultiplexer, NpgsqlConnection, Program, Worker

### Community 8 - "Community 8"
Cohesion: 0.62
Nodes (5): tests.sh script, dump_diagnostics(), error(), http_get_with_retry(), info()

### Community 9 - "Community 9"
Cohesion: 0.33
Nodes (7): ca(), gd(), hd(), lg(), rf(), xa(), xf()

### Community 10 - "Community 10"
Cohesion: 0.33
Nodes (7): hc(), Ja(), jg(), og(), qc(), tb(), ub()

### Community 11 - "Community 11"
Cohesion: 0.33
Nodes (5): net7.0, Newtonsoft.Json (13.0.1), Npgsql (4.1.9), StackExchange.Redis (2.2.4), Microsoft.NET.Sdk

### Community 12 - "Community 12"
Cohesion: 0.40
Nodes (5): ba(), fe(), gb(), Na(), sc()

### Community 13 - "Community 13"
Cohesion: 0.40
Nodes (5): Bd(), dd(), pg(), qg(), zd()

### Community 14 - "Community 14"
Cohesion: 0.60
Nodes (5): Ef(), he(), N(), Ob(), xb()

## Knowledge Gaps
- **25 isolated node(s):** `name`, `version`, `description`, `main`, `test` (+20 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `a()` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`, `Community 6`, `Community 14`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `d()` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 6`, `Community 10`, `Community 12`, `Community 14`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `t()` connect `Community 2` to `Community 0`, `Community 1`, `Community 3`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `Cc()` (e.g. with `B()` and `Bc()`) actually correct?**
  _`Cc()` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `B()` (e.g. with `Ad()` and `a()`) actually correct?**
  _`B()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `d()` (e.g. with `bg()` and `$c()`) actually correct?**
  _`d()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **What connects `name`, `version`, `description` to the rest of the system?**
  _25 weakly-connected nodes found - possible documentation gaps or missing edges._