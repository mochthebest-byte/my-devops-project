# Graph Report - my-devops-project  (2026-07-01)

## Corpus Check
- 37 files · ~87,369 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 443 nodes · 902 edges · 45 communities (34 shown, 11 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 148 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `4e86b715`
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
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]

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

## Communities (45 total, 11 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.50
Nodes (3): healthz(), Gunicorn WSGI entrypoint with /healthz endpoint.  Imports the Flask app from the, Simple health check — returns OK if the app is running.

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (82): $a(), Aa(), ab(), Ad(), ae(), Af(), ba(), bb() (+74 more)

### Community 2 - "Community 2"
Cohesion: 0.13
Nodes (27): Sf(), Uf(), a(), at(), Ct(), e(), Et(), f() (+19 more)

### Community 3 - "Community 3"
Cohesion: 0.17
Nodes (23): Bc(), cb(), Cc(), cf(), dc(), Ga(), ha(), hb() (+15 more)

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (13): 1. What Terraform Creates, 2. Role ARN for GitHub Actions, 3. Setting Up a Service Repository, 4. Monorepo CI (Alternative), 5. ECR Cleanup, 6. Verification, 7. Troubleshooting, Architecture (+5 more)

### Community 5 - "Community 5"
Cohesion: 0.12
Nodes (16): author, dependencies, async, cookie-parser, express, method-override, pg, socket.io (+8 more)

### Community 6 - "Community 6"
Cohesion: 0.22
Nodes (8): Helm Releases (deployed via Terraform), IAM / OIDC, Infrastructure as Code — Terraform, Other Resources, Resources, Secrets, State, Usage

### Community 7 - "Community 7"
Cohesion: 0.31
Nodes (4): ConnectionMultiplexer, NpgsqlConnection, Program, Worker

### Community 8 - "Community 8"
Cohesion: 0.62
Nodes (5): tests.sh script, dump_diagnostics(), error(), http_get_with_retry(), info()

### Community 9 - "Community 9"
Cohesion: 0.54
Nodes (6): tunnel-all.sh script, add_ingress_rule(), clean(), die(), log(), verify_tunnel()

### Community 10 - "Community 10"
Cohesion: 0.25
Nodes (7): Architecture, Available Make Commands, CI (GitHub Actions — No AWS), Disable AWS Terraform, Local Voting-App Development — Zero AWS Dependencies, Port Conflict? (Port 80 in use), Quickstart

### Community 11 - "Community 11"
Cohesion: 0.25
Nodes (7): net7.0, net8.0, Newtonsoft.Json (13.0.1), Npgsql (4.1.9), RabbitMQ.Client (6.8.1), StackExchange.Redis (2.2.4), Microsoft.NET.Sdk

### Community 12 - "Community 12"
Cohesion: 0.29
Nodes (6): Architecture, CI/CD Pipelines — Centralized Workflows, Files, Monorepo CI (Alternative), Required Secrets, Troubleshooting

### Community 13 - "Community 13"
Cohesion: 0.62
Nodes (5): tunnel-pinggy.sh script, cleanup(), log(), update_ingress(), verify()

### Community 14 - "Community 14"
Cohesion: 0.29
Nodes (6): Architecture Overview, CI/CD Flow, Components, My DevOps Project, Prerequisites, Quick Start

### Community 18 - "Community 18"
Cohesion: 0.83
Nodes (3): get_rabbitmq(), get_redis(), hello()

### Community 22 - "Community 22"
Cohesion: 0.33
Nodes (5): Dependencies, Deployment via ArgoCD, Keycloak Helm Chart, Values, What it deploys

### Community 23 - "Community 23"
Cohesion: 0.33
Nodes (5): Dependencies, Features, How CI Updates This, Values, Vote Helm Chart

### Community 24 - "Community 24"
Cohesion: 0.33
Nodes (5): Helm Values, How It Works, Structure, Tests, Voting App — Result Service (Node.js)

### Community 25 - "Community 25"
Cohesion: 0.33
Nodes (5): Features, Helm Values, How It Works, Structure, Voting App — Worker Service (.NET)

### Community 26 - "Community 26"
Cohesion: 0.40
Nodes (4): Infra Bootstrap Helm Chart, Migration, Вміст, Деплой через ArgoCD

### Community 27 - "Community 27"
Cohesion: 0.25
Nodes (8): Dependencies, Files, Kubernetes Infrastructure Manifests, Kubernetes — legacy manifests, Migration status, Migration to Helm, Деплой, Файли

### Community 28 - "Community 28"
Cohesion: 0.40
Nodes (4): Integration, Keycloak — OIDC Provider, Dependencies, Structure

### Community 29 - "Community 29"
Cohesion: 0.40
Nodes (4): Features, Helm Values, Structure, Voting App — Vote Service (Python/Flask)

### Community 30 - "Community 30"
Cohesion: 0.50
Nodes (3): ArgoCD Applications — App-of-Apps, Structure, Sync Flow

### Community 31 - "Community 31"
Cohesion: 0.50
Nodes (3): Features, Result Helm Chart, Values

### Community 32 - "Community 32"
Cohesion: 0.50
Nodes (3): Features, Values, Worker Helm Chart

### Community 35 - "Community 35"
Cohesion: 0.13
Nodes (34): B(), bg(), $c(), $d(), Da(), db(), df(), ec() (+26 more)

### Community 39 - "Community 39"
Cohesion: 0.40
Nodes (4): Deploy Kafka via ArgoCD, Нотатки, Спосіб 1: Через ArgoCD (рекомендовано), Спосіб 2: Через Helm CLI напряму

### Community 43 - "Community 43"
Cohesion: 0.33
Nodes (5): Documentation, Installing the Chart, karpenter, Values, Verification

### Community 44 - "Community 44"
Cohesion: 0.05
Nodes (40): 0.1 Отримати новий Account ID, 0.2 Встановити GitHub variable, 0.3 Налаштувати AWS CLI для нового акаунта, 1.1 Account ID — 2 файли, 1.2 Terraform state backend, 1.3 ACM certificate (новий в новому акаунті), 1.4 EKS cluster endpoint, 1.5 GitHub org (якщо змінюється) (+32 more)

## Knowledge Gaps
- **141 isolated node(s):** `http`, `server`, `name`, `version`, `description` (+136 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `a()` connect `Community 2` to `Community 3`, `Community 1`, `Community 35`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `d()` connect `Community 35` to `Community 1`, `Community 2`, `Community 3`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `t()` connect `Community 2` to `Community 1`, `Community 3`, `Community 35`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `Cc()` (e.g. with `B()` and `Bc()`) actually correct?**
  _`Cc()` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 18 inferred relationships involving `B()` (e.g. with `Ad()` and `a()`) actually correct?**
  _`B()` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `d()` (e.g. with `bg()` and `$c()`) actually correct?**
  _`d()` has 22 INFERRED edges - model-reasoned connections that need verification._
- **What connects `http`, `server`, `name` to the rest of the system?**
  _143 weakly-connected nodes found - possible documentation gaps or missing edges._