---
name: helm-chart-test
description: Write, fix, and run helm-unittest tests for the spacelift-self-hosted chart. Applies this repo's helm-unittest conventions.
user_invocable: true
---

# /helm-chart-test [component]

Use this skill whenever the user asks to add, fix, or review helm-unittest tests, or when a change to `spacelift-self-hosted/` needs matching rendered-manifest tests.

## Scope

**This skill applies to the `spacelift-self-hosted/` chart.**

If the user asks for helm-unittest tests for another chart, check whether that chart has its own helm-unittest setup. If it does not, say so and ask whether they want one added before writing anything.

Paths in this document are relative to the repo root.

## Argument Handling

**During feature implementation**, infer the affected templates from the diff or the requested change. Add or update focused tests for the changed rendered behavior without pausing to ask about scope, unless the requested behavior is ambiguous.

**If `[component]` is given** (e.g. `vcs-gateway`, `server`, `drain`, `scheduler`), work on the templates with that prefix and the test files that cover them.

**If nothing is given for a standalone task**, ask which component or template the user wants covered.

## Feature Implementation Mode

When this skill runs as part of implementing a chart change:

1. Identify the affected templates, helpers, and values from the diff or the request.
2. Read `spacelift-self-hosted/templates/_helpers.tpl` for any helper the template calls.
3. Read the nearest existing test file and mirror its style.
4. Add or update focused tests for the new or changed behavior.
5. Cover the enabled/disabled branches, value propagation, selectors, labels, annotations, containers, volumes, and service wiring the change touches.
6. Run `make -C spacelift-self-hosted test`.

Ask the user only when there are multiple plausible semantics, or when the affected templates cannot be worked out from local context.

## Chart Layout

- `spacelift-self-hosted/Chart.yaml` - chart metadata.
- `spacelift-self-hosted/values.yaml` - defaults.
- `spacelift-self-hosted/values.schema.json` - JSON Schema validated on every render, including helm-unittest runs.
- `spacelift-self-hosted/templates/` - the templates, mostly named `<component>-<kind>.yaml`, e.g. `vcs-gateway-deployment.yaml`, `server-pdb.yaml`.
- `spacelift-self-hosted/tests/` - the test suites, one `<area>_test.yaml` file per behavior area. Extend an existing file when the behavior fits its suite; add a new file for a new area.
- `spacelift-self-hosted/tests/__snapshot__/` - snapshot output that `make test` writes. Empty while no suite uses snapshot assertions.

## helm-unittest Overview

Tests are YAML files in `spacelift-self-hosted/tests/` that assert on rendered Kubernetes manifests. Each `tests[].it` case renders independently with that case's value inputs. Keep tests focused and deterministic: one behavior per test, explicit value overrides, scoped assertions.

### Repo Conventions

- Start every test file with the schema comment:
  `# yaml-language-server: $schema=https://raw.githubusercontent.com/helm-unittest/helm-unittest/main/schema/helm-testsuite.json`
- Reference templates by their path relative to `templates/`, without a `templates/` prefix: `vcs-gateway-deployment.yaml`. The plugin accepts the prefix too, but this repo leaves it out.
- Set values with inline `set` blocks, so each test shows its own inputs. Do not add separate values files for tests unless the user asks.
- Tests run with `--strict`, so an unknown or misspelled field in a test file fails the run instead of being ignored.
- `values.schema.json` sets `additionalProperties: false` on its objects, so a `set` key that is not in the schema fails the render. If a test needs a new value, the schema must be updated too - and that is a chart change, not a test change, so flag it to the user.
- The plugin has a `--skip-schema-validation` flag. This repo does not pass it and should not start. A schema rejection means the test is setting something the chart does not accept, which is worth knowing.

### Test File Structure

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/helm-unittest/helm-unittest/main/schema/helm-testsuite.json
suite: <descriptive suite name>
templates:
  - vcs-gateway-deployment.yaml
tests:
  - it: <test case description>
    set:
      vcsGateway.enabled: true
      vcsGateway.domain: vcs-gateway.example.com
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: metadata.name
          value: spacelift-vcs-gateway
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: MY_VAR
            value: my-value
```

Note `fullnameOverride` defaults to `spacelift`, so rendered names are `spacelift-*` rather than `RELEASE-NAME-*`. Only set `release.name` when the template actually reads `.Release.Name`.

### Scope, Precedence, and Targeting

- Value precedence: chart `values.yaml` < suite `values` < suite `set` < test `values` < test `set`.
- Template scope precedence: suite `templates` narrowed by test `template` / `templates`, then by assertion-level `template`.
- Document targeting precedence: assertion `documentSelector` / `documentIndex` overrides the test-level selector or index.
- Use `documentSelector` for multi-document templates instead of a brittle numeric `documentIndex`.
- `hasDocuments` ignores selectors by default; set `filterAware: true` to count only selector/index-filtered documents.
- `documentSelector` fields: `path` (required), `value` (optional - omit it to filter on path existence alone), `matchMany` (allow more than one match), `skipEmptyTemplates` (tolerate templates that rendered nothing).
- A selector that matches in some of the suite's templates but not others is fine as is. A selector that matches **nothing at all** fails the assertion with `document not found`, even when the assertion is `hasDocuments: {count: 0, filterAware: true}`. That is the case `skipEmptyTemplates: true` fixes - reach for it when testing that a component renders nothing.

### Suite and Test Options

- `release`: for behavior that depends on `.Release` (`name`, `namespace`, `revision`, `upgrade`).
- `capabilities`: pin Kubernetes versions/APIs for branches guarded by `.Capabilities.*`.
- `chart`: override `.Chart.version` / `.Chart.appVersion` when output depends on them.
- `excludeTemplates`: narrow broad template globs to keep unrelated documents out of a suite.
- `skip`: only for temporary or unreleased behavior; prefer active assertions over skipped tests.

## Assertion Guidance

Grouped by what they inspect. Every assertion also takes `not`, `template`, `documentIndex`, and `documentSelector` at its root.

**Documents**

| Assertion | Purpose |
|---|---|
| `hasDocuments` | Number of documents rendered; takes `filterAware` |
| `containsDocument` | A document with this `kind` and `apiVersion` exists; takes optional `name` and `namespace` |
| `isKind` | Kind of the selected document |
| `isAPIVersion` | API version of the selected document |

**Values**

| Assertion | Purpose |
|---|---|
| `equal` / `notEqual` | Exact match at a path; takes `decodeBase64` |
| `exists` / `notExists` | Path is present or absent |
| `isEmpty` / `isNotEmpty` | Value is empty or not |
| `isNullOrEmpty` / `isNotNullOrEmpty` | Value is null/empty, or present with content |
| `isType` / `isNotType` | Value type: `string`, `int`, `bool`, ... |

**Arrays and maps**

| Assertion | Purpose |
|---|---|
| `contains` / `notContains` | Entry membership; takes `count` and `any` |
| `lengthEqual` / `notLengthEqual` | Length equals expected count; takes `paths` to check several at once |
| `isSubset` / `isNotSubset` | Expected object is contained in the rendered one |

**Comparisons**

| Assertion | Purpose |
|---|---|
| `greaterOrEqual` / `notGreaterOrEqual` | Numeric or string comparison |
| `lessOrEqual` / `notLessOrEqual` | Numeric or string comparison |

**Strings**

| Assertion | Purpose |
|---|---|
| `matchRegex` / `notMatchRegex` | Regex against a string value; takes `decodeBase64` |

**Rendering**

| Assertion | Purpose |
|---|---|
| `failedTemplate` | Render fails; match the message with `errorMessage` or `errorPattern` |
| `notFailedTemplate` | Render succeeds |

`equalRaw` / `notEqualRaw` / `matchRegexRaw` / `notMatchRegexRaw` exist to assert on `templates/NOTES.txt`, which we do not test. Do not use them.

### Snapshots

`make test` always passes `-u`, so `matchSnapshot` / `matchSnapshotRaw` work without extra setup. With `-u`, a snapshot assertion never fails:

- On the first run, it writes the snapshot to `tests/__snapshot__/`.
- When the rendered output changes, it rewrites the snapshot and passes.

So a snapshot shows a change only as a diff in `tests/__snapshot__/`. Review that diff and commit it together with the chart change. CI runs `make test` with `-u` as well, so a stale snapshot in the repo is rewritten in CI and does not fail the build.

Do not add snapshot assertions to a suite unless the user asks for them. When a suite already has them, keep them, and review the snapshot diff your change causes. Either way, keep the specific assertions: those are what fail when behavior breaks.

Use `decodeBase64: true` on `equal` / `notEqual` / `matchRegex` when asserting on a Secret's `data`, which Helm renders base64-encoded. Values under `stringData` need no decoding.

Use antonym assertions (`notEqual`, `notContains`) instead of `not: true` unless `not: true` is clearer.

Prefer `equal`, `contains`, and specific negative assertions over broad `exists` checks. Specific assertions catch regressions.

Several templates guard values with `required`, e.g. `vcsGateway.domain` and `vcsGateway.gateway.gatewayClassName`. Cover those with `failedTemplate` and the exact message.

`contains` takes `count` for how many times the entry must appear, and `any: true` to match a subset of an element's fields rather than the whole element. Use `any` when you care that one key is set and not about everything else on that entry:

```yaml
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: SPACELIFT_VERSION
          any: true
```

### Assertion Scoping Patterns

```yaml
  - it: targets one Deployment by name
    templates:
      - server-deployment.yaml
      - drain-deployment.yaml
    asserts:
      - equal:
          path: spec.replicas
          value: 1
        documentSelector:
          path: metadata.name
          value: spacelift-server
```

```yaml
  - it: counts only selected docs
    template: extra-manifests.yaml
    documentSelector:
      path: kind
      value: ConfigMap
      matchMany: true
    asserts:
      - hasDocuments:
          count: 2
          filterAware: true
```

### Multi-Template Safety

When a suite lists several templates, set `template` on every assertion unless the test intentionally targets all of them.

Put `template` at the assertion root, not inside the assertion parameters.

Wrong:

```yaml
      - notContains:
          template: server-deployment.yaml
          path: spec.template.spec.containers
          content:
            name: cloud-sql-proxy
```

Correct:

```yaml
      - template: server-deployment.yaml
        notContains:
          path: spec.template.spec.containers
          content:
            name: cloud-sql-proxy
```

### Path and jsonPath Guidance

- Prefer precise paths over broad existence checks.
- When map keys contain dots or slashes, use jsonPath bracket syntax.
- Keep escaping consistent to avoid false negatives.

```yaml
  - equal:
      path: metadata.annotations["kubernetes.io/ingress.class"]
      value: nginx
```

### Conditional Rendering Tests

```yaml
  - it: renders nothing when disabled
    set:
      vcsGateway.enabled: false
    asserts:
      - hasDocuments:
          count: 0
```

### Testing with Release Values

```yaml
  - it: uses the release name
    release:
      name: example-release
    asserts:
      - equal:
          path: metadata.name
          value: example-release-credentials
```

## Writing Workflow

1. Read the template under test. Understand every conditional, value reference, helper call, and document it emits.
2. Read `templates/_helpers.tpl` for the helpers that template uses.
3. Read `values.yaml` for defaults, and `values.schema.json` for what `set` keys are allowed.
4. Work out whether the template emits zero, one, or many documents, and which selector is stable.
5. Write tests for default rendering, each significant conditional branch, `required` failures, selector behavior, and multi-template scoping.
6. Run the tests.
7. Fix failures by adjusting assertions to match the actual rendered output.
8. Repeat until the file passes.

## Running Tests

Tests run in Docker through the chart's own Makefile. Run the whole suite:

```bash
make -C spacelift-self-hosted test
```

Run one test file:

```bash
make -C spacelift-self-hosted test HELM_UNITTEST_FILE='tests/vcs_gateway_test.yaml'
```

`HELM_UNITTEST_FILE` is a glob relative to the chart directory; it defaults to `tests/**/*.yaml`.

The Makefile always passes `--strict` and `-u` (update snapshots, see "Snapshots"). Do not call `docker run` by hand to pass plugin flags the Makefile does not expose; if a test needs such a flag, the test is wrong.

CI runs the same target on every pull request.

### Running in Parallel

Each `make test` run is a fresh `--rm` container. While no suite uses snapshot assertions, a run writes nothing to the chart, so several runs can go at once, from one checkout or from separate git worktrees. Once snapshots exist, two runs in one checkout can write the same snapshot file, so give each run its own worktree. Agents that edit the chart in parallel still need one git worktree each. In a shared checkout, one agent's half-done edit to `values.schema.json` or a template fails every other agent's tests.

### Image Version

The image tag comes from `HELM_UNITTEST_TAG` in `spacelift-self-hosted/Makefile`, and Renovate bumps it. Read the tag from the Makefile instead of assuming one.

Upstream docs on the `main` branch can run ahead of the plugin version in that tag. Check any feature you read about there against the image the Makefile uses before relying on it:

```bash
docker run --rm "helmunittest/helm-unittest:$(sed -n 's/^HELM_UNITTEST_TAG := //p' spacelift-self-hosted/Makefile)" --help
```

## Rules

- Only create or edit `.yaml` files under `spacelift-self-hosted/tests/` when this skill is used to write tests.
- Do not modify templates, `values.yaml`, `values.schema.json`, or `Chart.yaml` as part of a test-writing task unless the user explicitly widens the scope.
- Never run destructive shell commands.
- Always run the relevant test command after writing tests.
- Reference templates by their path relative to `templates/`, without the `templates/` prefix.
- Assert on `spacelift-*` names by default; `fullnameOverride` is `spacelift`.
- Set enable flags explicitly instead of relying on defaults when a template renders conditionally.
- If a test needs a value that `values.schema.json` rejects, stop and tell the user - the schema change is a chart change.
- Prefer `documentSelector` over a hardcoded `documentIndex` for templates that can reorder output.
- Use `hasDocuments.filterAware: true` when asserting counts under selector or index filtering.
- Use `template` / `templates` at test or assertion level to stop assertions bleeding across templates.
- For negative paths, assert absence with `notExists` or `notContains`.
- Do not test `templates/NOTES.txt`.
- Do not add snapshot assertions unless the user asks for them. See "Snapshots".
- Do not add a `.yaml` file under `tests/` that is not a test suite. The glob runs everything it finds.
