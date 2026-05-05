# CISS Mobile Project Instructions

## Think Before Coding
- State assumptions explicitly before implementing.
- Surface tradeoffs and present multiple interpretations instead of picking one silently.
- Stop and ask for clarification if any part of the request is unclear.
- Suggest simpler approaches if they exist.

## Simplicity First
- Write the **minimum code** required to solve the problem.
- Avoid speculative features, "flexibility," or configurability that wasn't requested.
- Do not create abstractions for single-use code.
- If a solution is overcomplicated (e.g., 200 lines when 50 would suffice), rewrite it.

## Surgical Changes
- **Scope:** Touch only the code necessary for the task.
- **Style:** Match the existing codebase's style (Riverpod, GoRouter, Vanilla CSS/Theme, etc.), even if it differs from personal preference.
- **Cleanup:** Only clean up your own mess (imports/variables/functions made unused by your specific changes). Do not refactor unrelated code or delete pre-existing dead code unless explicitly asked.

## Goal-Driven Execution
- **Success Criteria:** Transform tasks into verifiable goals (e.g., "Write tests for invalid inputs, then make them pass").
- **Multi-step Tasks:** Create a brief plan with explicit verification steps for each stage.
- **Verification Loop:** Implementation is considered incomplete until it is verified against the defined success criteria.
- **Test-Driven Approach:** For bugs, write a reproduction test first. For features, write validation tests first.
- **Traceability:** Every changed line should be directly traceable to the user's request.

## Development Workflow
- **Build/Run:** `flutter run`
- **Test:** `flutter test`
- **Analyze:** `flutter analyze`
- **Formatting:** `flutter format .`
- **Environment:** Use `mobile.env` with `--dart-define-from-file`.
