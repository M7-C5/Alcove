# Autonomous Verification Loop

1. **Autonomous Verification Gatekeeper**:
   - Before requesting human review or declaring any milestone complete, always run `./scripts/verify.sh`.
   - Ensure clean compilation with zero warnings-as-errors and 100% test pass rate across all unit test suites in `AlcoveTests`.

2. **Thermal & Simulator Guard**:
   - Xcode simulator processes consume significant CPU and thermal budget.
   - Always shut down simulators cleanly immediately after running verification:
     ```bash
     xcrun simctl shutdown all 2>/dev/null || true
     ```

3. **Continuous Regression Testing**:
   - Every bug fix or architectural feature must be accompanied by isolated unit tests that execute in sub-second intervals under headless execution.
