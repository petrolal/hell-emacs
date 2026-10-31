# Code-Quality Review: Still To Do

All findings from the core review (`lisp/`, `bin/`, `modules/hell/`, `test/`)
have now been implemented and verified with `make compile`, `make checkdoc`,
and `make test` (56/56). See [review-done.md](review-done.md).

---

## Future Scope: Catalog-Wide Pass (`sources/hell+/modules/`)

The previous review covered `lisp/`, `bin/`, `modules/hell/`, `test/`, and
an altitude-only pass over `sources/hell+/modules/` to decouple core/tools from
language checkers and build markers.

A full reuse, simplification, and efficiency pass over the rest of the
`sources/hell+/modules/` catalog has not yet been conducted and remains as
future maintenance work.
