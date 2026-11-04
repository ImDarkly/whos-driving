# Local compatibility patch

Base: EOSG 2.3.1, upstream commit
`56238973e2cd7ac9ac99ca14f88934465f0a8997`. Keep upstream licenses.

`heos/hplatform.gd` accepts `EOS.Result.AlreadyConfigured` when setting up the
platform and does not retry that initialization result. The SDK can remain
initialized after platform creation fails; a later setup attempt must still
reach platform creation. This does not emit a second initialization event.
No other addon behavior is patched.

Regression: `tests/check_recovery.gd` in the repository root. It uses real SDK
initialization and a scripted platform-creation failure, without product
credentials or authentication calls.
