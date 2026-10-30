# Code-Quality Review: Still To Do

Findings from the 2026-10-30 `/simplify` + altitude review of `lisp/`,
`bin/`, `modules/hell/` and (once rescoped) `sources/hell+/modules/` that
were deliberately **not** applied. What was applied is in
[review-done.md](review-done.md).

---

## Efficiency: redundant work during `bin/hell sync`

Skipped because `bin/hell sync` is already dominated by network downloads
and byte-compilation (minutes), so the actual speedup is unmeasurable, while
each fix adds real cache-invalidation surface in code that writes profile
files. Revisit only if sync's own overhead (not the downloads) is ever
actually measured as a problem.

1. **`hell-module-list` (`lisp/hell-modules.el`)** is recomputed from
   scratch (a full `maphash` + `sort`) on every call; it's called at least
   8 times with the same, unchanged module set within one sync
   (`lisp/hell-modules.el:374,671,690,386`, `lisp/hell-profiles.el:88,105,244,286`).
   Fix: cache the sorted orderings when modules are enabled
   (`hell--enable-modules`, invalidated on its `clrhash`).

2. **`hell-module-autoload-files` (`lisp/hell-modules.el`)** does a
   `file-exists-p` + `file-expand-wildcards` directory scan per module,
   called twice for the identical module set within one
   `hell-sync--write-profile` pass (`lisp/hell-profiles.el:108` and `:246`).
   Fix: compute the per-module autoload-file list once and thread it
   through, instead of recomputing in `hell-profile--module-autoloads`.

3. **`hell-profile--modules` (`lisp/hell-profiles.el`)** is computed twice
   back to back: once by `hell-sync--run` to log it, then again by
   `hell-sync--write-profile` right after, for `profile.eld`'s `:modules`
   field (`lisp/cli/sync.el:520` and `lisp/hell-profiles.el:448`).
   Fix: compute it once in `hell-sync--run` and pass it down.

## Simplification: `hell-module-enable`'s depth-fallback chain

`lisp/hell-modules.el`, the `i-depth`/`c-depth` bindings in
`hell-module-enable`: each falls back through 4 levels (specific arg →
general `depth` arg → `.hellmodule`'s own key → its general `depth` →
`0`), and the fallback chain is duplicated almost verbatim between the two.
Not wrong, just the densest line in the file. Minor, optional:

```elisp
(cl-flet ((pick (specific key) (or specific depth (alist-get key meta) meta-depth 0)))
  (let ((i-depth (pick init-depth 'init-depth))
        (c-depth (pick config-depth 'config-depth)))
    ...))
```

---

*For context: this review covered `lisp/`, `bin/`, `modules/hell/`,
`test/`, and (for the altitude pass only, at the user's request) the
`sources/hell+/modules/` catalog. A full reuse/simplification/efficiency
pass over the catalog itself was never run and would likely turn up more.*
