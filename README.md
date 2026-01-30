# actual-native

Native mobile app (iOS + Android) for Actual Budget.

## Goals (initial)
- Authenticate to a local Actual Budget server
- Sync budgets and transactions
- Simple, fast mobile UX

## Repo structure (initial)
```
apps/
  mobile/       # mobile app (TBD: React Native / Flutter / Swift+Kotlin)
packages/
  core/         # shared API client + models
  ui/           # shared UI primitives (if applicable)
```

## Next decisions
- Pick mobile stack (React Native vs Flutter vs native)
- Define API surface for Actual Budget (endpoints + auth)
- Target feature list for MVP
