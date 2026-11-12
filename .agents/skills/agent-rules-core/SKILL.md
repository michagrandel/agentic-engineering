---
name: agent-rules-core
description: >
  The binding rule core for all agent roles (Dev, QA, Reviewer, Release) in the
  four-agent framework — the document cited as "Agent Rules: Common Core" with
  rule numbers 1-43. Contains only norms: design, code quality, documentation,
  typing, tests, TDD, API/data, and VCS process rules. Tool-specific procedures
  live in the role files and the agent-session-protocol skill.
version: 1.0
applies-to: [dev, qa, reviewer, release]
---

# Rules for Modern Programming — Agent Directives (Common Core)
*(language-independent, applicable to Python and C++; binding for ALL agent roles)*

> **Structure of this rule set:** This file contains only *norms* — rules that every role knows, follows, or audits against. Tool-specific *procedures* (Git/Perforce command sequences) live in the respective role descriptions (Dev Agent, Release Agent). Referenced roles: Dev (development), QA (local testing), Reviewer (quality audit), Release (push/submit).

## 1. Design & Architecture

1. **Prefer composition over inheritance.** Use inheritance only for a genuine *is-a* relationship that satisfies the Liskov Substitution Principle (LSP); otherwise delegate to components.
2. **Separate logic from side effects.** Pure functions (functional core) for business logic; side effects (I/O, files, network, time, randomness) only at the edges (imperative shell). The core may contain classes — but only as immutable value objects with pure query/computation methods. Methods with side effects (member mutation, I/O, global state) never belong in the core, regardless of their syntax.
3. **No premature abstraction.** Duplicating twice is fine; abstract only at the third occurrence (Rule of Three) — a wrong abstraction is more expensive than duplication.
4. **Small, focused units at a homogeneous level of abstraction.** A function does one thing; a class has one reason to change (Single Responsibility). Guideline: functions < ~30 lines. All statements in a function sit at the same level of detail — do not mix high and low abstraction levels; split them into separate functions instead.
5. **Program against interfaces, not implementations.** Define abstract interfaces at module boundaries (abstract base classes, concepts, templates); make dependencies injectable instead of hard-wired.
6. **Open/Closed Principle (OCP).** Extend behavior through new code, not by editing existing code. Growing `switch`/`if-elif` chains over types are a warning signal: replace them with strategy objects or polymorphic types — but only when the third case occurs (see Rule 3).
7. **Interface Segregation Principle (ISP).** Keep interfaces small and cohesive. Never force an implementation to provide methods it does not need — prefer several specific interfaces over one broad one.
8. **Know the important patterns — but introduce no pattern unless a problem demands it.** Strategy instead of conditional logic blocks, Factory only for genuine variability.

## 2. Code Quality

9. **Immutable first.** Avoid mutable, shared state; use constant/immutable data structures and pure transformations instead of in-place mutation (e.g. `const`/`constexpr` in C++, tuples/dataclasses instead of permanently mutated containers). **Value-object rule:** Pure data bundles (possibly with derived values) as immutable data structures (`@dataclass(frozen=True)` in Python, `struct`/aggregate in C++); types with invariants or dominant domain logic as regular classes with constructor validation (`class` with private members in C++). Rule of thumb: data structure when the object primarily *is* data; class when it *has* rules.
10. **Explicit error handling instead of silent fallbacks.** No empty `except`/empty `catch`, no suppressing return values (ignoring error codes), no glossing over failure as the normal case. Validate inputs at the system boundary.
11. **No magic numbers.** Named constants; no primitive strings/ints with implicit meaning (*stringly typed code*) — use descriptive enumeration types (enums) or dedicated types instead.
12. **Descriptive names that need no comments — no ad-hoc abbreviations.** `retry_delay_ms` instead of `d`; loop variables like `i`, `j` only in trivial, narrow counting loops. Comments explain *why*, not *what*. **Abbreviation rule:** An abbreviation is allowed only when it is more established among developers than the spelled-out word. Allowed: standard units as suffixes (`ms`, `s`, `kb`), universally known acronyms (`HTML`, `HTTP`, `JSON`, `URL`, `URI`, `ID`, `API`), and domain abbreviations canonized in the project context (record them in a glossary, then use them consistently). Forbidden: letter-stripping from single words (`svc`, `mgr`, `usr`, `cnt`) and inconsistent spellings (`cfg` alongside `config`). The capitalization of acronyms follows the language's naming convention and is applied uniformly across the project (e.g. `HTMLParser` style or `HtmlParser` style — but never mixed).
13. **No dead code, no commented-out corpses, no debug output in production.** Version control is your archive.
14. **Fail fast, fail loud.** Detect invalid states immediately (assertions, preconditions) and make invalid states unrepresentable in the type system (*"make illegal states unrepresentable"* — e.g. via unions/variants that force error states to be handled).
15. **Command-Query Separation (CQS).** A method either *does* something or *answers* something — never both. A query (`is_valid()`, `compute_total()`) has no side effects; a command (`save()`, `reset()`) does not return a queried result.
16. **Law of Demeter / Tell-Don't-Ask.** No train wrecks through foreign internals (`order.customer.address.city` instead of four chained `get_*()` calls). Talk to the object that concerns you and let it compose the answer itself — encapsulation instead of structure digging.
17. **No flag arguments, few parameters.** Boolean switch parameters (`pay(apply_discount=True)`) are forbidden — use two methods with descriptive names or two types instead. Guideline: at most ~3 parameters; beyond that, bundle data into a value object.
18. **No `null`/`None` as a normal return value.** Express missing values via optional types (`std::optional` in C++, `X | None` in Python with enforced handling); where absence is common, return special-case objects instead of forcing callers into null checks.

## 3. Documentation

19. **Every file (module), class, method, and function gets a docstring — no exceptions.** In Python consistently in **Google style** (`"""..."""` with `Args:`, `Returns:`, `Raises:`), in C++ as Doxygen comments (`///` or `/** */` with `@param`, `@return`, `@throws`). `__init__`, properties, abstract methods, and small helper functions are documented as well; private elements just like public ones.
20. **Docstrings document the complete contract:** every parameter (name, meaning, constraints, units) and the return value; for methods that can raise, also the raised exceptions/errors. In Google style:

    ```python
    def compute_discount(cart_total: float, customer_type: CustomerType) -> float:
        """Computes the total discount for an order.

        Args:
            cart_total: Net sum of the order in euros, >= 0.
            customer_type: The customer's discount tier.

        Returns:
            The discounted total amount in euros.

        Raises:
            ValueError: If cart_total is negative.
        """
    ```

    Since types already appear in the signatures (Rule 22), the docstring describes *meaning, units, and boundary conditions* — not the obvious implementation. If the project style mandates repeating types in the docstring, that convention takes precedence.
21. **Docstrings are living contracts.** With every signature or behavior change, the docstring changes along; an outdated or wrong docstring is a defect like wrong code. Deleted elements need no comment residue.

## 4. Typing & Language Use

22. **Use the strongest safety net the language provides.** In Python: complete type hints and strict static type checking, no unchecked casts; in C++: `const` correctness, `nullptr` checks or references/`std::optional` instead of raw pointers, no `reinterpret_cast` without compelling reason.
23. **Types document contracts, not just structure.** Model disjoint states as distinct types (e.g. a result type with success/failure variants) instead of boolean flag fields; in C++ `std::variant` and rejection of zombie objects; in Python, no "return `None` somehow when it could also raise".
24. **Use modern, idiomatic language features** instead of legacy style: structured concurrency (coroutines/`async` in Python, C++20 coroutines or tasks) instead of raw callback nesting; range-based iteration instead of index loops; RAII and destructors instead of manual resource release (C++) or context managers instead of try/finally (Python).
25. **Write resource-conscious code:** streaming/generative processing of large data sets instead of loading everything into memory; timeouts and cancellation mechanisms for every network/I/O call; no unnecessary copies (move semantics in C++, iterators/generators in Python).

## 5. Tests

26. **Test behavior, not implementation details.** Pure core logic has unit tests; critical paths have integration tests. Test existence is mandatory — the order of writing is governed by TDD (Rule 29).
27. **One test = one behavioral aspect, deterministic, isolated.** No test interdependence, no mocking of what is not under test (mock only at the module boundary, never at your own core; in C++ mock virtual interfaces instead of concrete classes, in Python inject dependencies instead of monkey-patching).
28. **Every bug fix first gets a test that reproduces it.**

## 6. TDD (Test-Driven Development)

29. **TDD graduated — not dogma, but three zones.** Test *existence* is mandatory everywhere (Rule 26); the test *order* depends on the zone:

    - **Functional core: test-first encouraged.** Red-Green-Refactor is the fastest path here — pure functions are deterministic and testable in seconds. First write a failing test that fixes the next desired behavior; then minimal implementation; then refactoring (an integral cycle step, not an appendix).
    - **Imperative shell / infrastructure: tests required, but deferred.** No test-first mandate for DB wrappers, HTTP handlers, glue code. Instead, integration tests against real dependencies (Rule 26).
    - **Exploratory code: spike path allowed.** Sketching first, then testing, then building cleanly is legitimate — as long as the core ends up tested.

30. **TDD discipline: do not invent abstraction test-first.** Test-driven does not mean interface-first: abstractions only at the third concrete case (Rule 3). Do not write tests against implementation details just to get green — test the public surface; tests on the wrong abstraction are more expensive to discard than code alone.
31. **Every Red-Green-Refactor cycle is small.** One cycle covers exactly one behavioral aspect (Rule 27); if a test checks two aspects or the implementation grows beyond the sketch, reset and start smaller. Refactor only on green — never leave a red state standing.

## 7. API & Data

32. **Validate at the boundaries, trust on the inside.** External inputs (HTTP, files, user interaction) are checked upon entry and converted into well-defined internal types.
33. **Version APIs and change them backward-compatibly.** Breaking changes only in a new major version; communicate deprecations actively.
34. **Secrets never belong in code, logs, or comments.** Environment variables/secret storage; no hardcoded tokens or passwords.

## 8. Process & Version Control (Norms for All Roles)

*(Tool-neutral: "commit" = commit in Git or submitted changelist in Perforce; "branch" = branch or stream/task branch; "shelve/stash" = shelved changelist or git stash/WIP branch. The concrete command sequences live in the role descriptions.)*

35. **Plan in commit/submit units before you start.** Before every larger task: break the work into individually completable, individually committable sub-steps (work plan). Each sub-step compiles/is testable on its own and has its own meaning. Only then implement — and proceed in exactly this granularity.
36. **Work iteratively in commit cadences, not in a big bang.** After every completed sub-step, commit or finalize the changelist — in particular: after every green Red-Green cycle (red+green together as a behavior commit, the refactoring as its own commit). Never accumulate several sub-tasks and dump them into one large change set at the end. A work step always ends with a commit or a finished changelist or an explicit shelve — never with an open, pending workspace.
37. **One commit = exactly one concern.** Never mix: feature, refactoring, formatting, renames, dependency updates, and test fixtures are separate commits. Alarm-threshold guidelines: a commit with more than ~400 changed lines or more than ~10 files must be split (unless it is formally indivisible, e.g. a rename rollout).
38. **Every commit leaves the system in a valid state.** Build compiles, tests green, no dead intermediate state ("fix later") — the history must be checkable and usable at any point.
39. **Commit/changelist messages are contracts** (Conventional Commits or project convention): a short statement about the *why/what*; for non-trivial changes, a rationale in the body. No messages like "stuff", "update", "final fix v2". Branch/changelist names describe the concern meaningfully (convention e.g. `feature/x`, `fix/y`, `refactor/z` — never `wip`, `tmp`, `work`).
40. **VCS governance — two inviolable invariants:**
    - **(a) Transfer monopoly:** Push (Git) and submit (Perforce) are permitted *exclusively* to the Release Agent. No Dev, QA, or Reviewer agent ever transfers changes to the remote/depot — not even "helpfully", "for safety", or on assumption.
    - **(b) Verify instead of sync:** Before every VCS operation (edit, commit, push, submit), the sync and collision status is verified. If there is a lag or conflict (remote commits missing locally; files with open changes in changelists), **abort and report to the user** — never automatically pull, merge, rebase, or force-sync. Synchronization decisions belong to the user alone.
41. **Linters and formatters are settled and not up for debate.** Project mandates (e.g. Ruff/mypy for Python, clang-format/clang-tidy for C++) take precedence over personal preferences.
42. **Boy Scout Rule with style respect.** Leave code you touch cleaner than you found it — small local improvements with every touch. But: local project style beats global; no cosmetic mass refactorings in team ownership and in pull requests that are actually about something else.
43. **Do not overdo it.** YAGNI: build features and abstractions only when a concrete need exists — but name technical debt explicitly instead of leaving it silently.
