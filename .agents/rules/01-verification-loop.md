# Autonomous Verification Protocol

Every agent working on this codebase must autonomously self-verify before requesting human review or declaring completion.

---

## 1. Verification Gatekeeper
The primary gatekeeper command is:
```bash
./scripts/verify.sh
```

This runs two sub-second / fast tiers:
1. **Xcode Build Compilation**: Compiles the `Alcove` target with `xcodebuild build` targeting the iOS Simulator SDK. Catches Swift syntax, typing, and protocol conformance errors.
2. **Swift Unit Test Suite (`AlcoveTests`)**: Executes Swift Testing suites (`@Test`, `#expect(...)`) in headless simulator mode.

---

## 2. Thermal & Simulator Guard
- Xcode simulator processes consume substantial CPU and thermal budget.
- **Execution Scoping**:
  - **Required**: Run `./scripts/verify.sh` strictly after authoring or modifying Swift source code (`Alcove/`, `AlcoveTests/`, project config) prior to declaring task completion.
  - **Prohibited**: Do NOT run `./scripts/verify.sh` after markdown/docs updates, clean `git pull` operations, planning turns, or general queries.
- Test runner scripts and verification workflows MUST cleanly shut down simulators immediately after verification completes:
  ```bash
  xcrun simctl shutdown all 2>/dev/null || true
  ```
- Sub-second unit tests (`AlcoveTests`) are strictly partitioned from heavy UI benchmarks. Keep fast turns lightweight.

---

## 3. Autonomous Triage Procedure
If `./scripts/verify.sh` fails:
1. **Read the exact error stack trace**: Extract filename, line number, and Swift error code or test assertion message.
2. **Do not guess or apply shotgun fixes**: Inspect the broken line in context using targeted file reads.
3. **Fix the root cause**:
   - For compilation errors: check type mismatches, missing imports, or concurrency isolation warnings (`@MainActor`).
   - For test failures: verify if the test expectation or the domain implementation was incorrect.
4. **Re-run `./scripts/verify.sh`**: Confirm the fix resolves the issue with zero regressions.
5. **Only when all green**: Report outcome with evidence of verification.

---

## 4. Continuous Regression Testing
- Every bug fix or architectural capability must be accompanied by isolated unit tests in `AlcoveTests`.
- All tests must execute deterministically in sub-second intervals under headless execution.
