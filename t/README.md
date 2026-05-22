# Webmin test suite

Two kinds of tests live under this tree:

- Repo-root `t/` for core code (`miniserv.pl`, `web-lib-funcs.pl`, top-level
  scripts, `bin/`).
- Per-module `t/` for module-internal coverage (see `nftables/t/` for the
  established pattern: `perlcritic.t` plus a `run-tests.t` smoke harness).

## Running tests

```sh
prove -lr                                # everything, including modules t/
prove -lr t                              # everything under repo-root t/
prove t/compile.t                        # one test file
WEBMIN_COMPILE_T_FILTER='^\./acl/' prove t/compile.t   # one module
```

`prove` and Test::More are core, though on RPM-based distros, you need
`perl-Test-Harness`.

## Coverage reports

```sh
HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr
cover
```

You need Devel::Cover installed.

## What's here

| File | What it checks |
| --- | --- |
| `compile.t` | Every `.pl`, `.cgi`, and shebang-perl script in `bin/` parses cleanly (`perl -c`). Catches breakage from bulk refactors without browsing every page. ~12s for the full tree. |
| `miniserv.t` | Contract test for `miniserv.pl` functions — status codes, headers, body rendering, log behaviour. Demonstrates the require-and-stub pattern below. |

## The require-and-stub pattern

Many Webmin scripts mix sub definitions with a main body that opens sockets,
reads `/etc/webmin/*`, or spawns CGIs. To test individual subs in isolation
we need to `require` the script as a library without running the main body.

Two complementary idioms can be used. Both work; they look different because
the underlying script does.

### Block wrap (main body precedes sub definitions)

Used by `miniserv.pl`. The executable preamble runs at file scope (so any 
`my` vars stay file-scoped for the subs below); the main body wraps in
`unless (caller)`:

```perl
#!/usr/bin/perl
use Foo;            # use lines and pragmas stay outside the guard

unless (caller) {

# main body: arg parsing, setup, the actual work
...

} # end of unless (caller)

sub helper { ... }
sub other_helper { ... }
```

### One-liner (sub definitions precede the main call)

Used by most `bin/` CLI tools, which already define `sub main` and dispatch
to it at the bottom:

```perl
#!/usr/bin/env perl
use strict; use warnings;

sub main {
    ...
    return 0;
}
exit main(\@ARGV) if !caller(0);

sub helper { ... }
```

`!caller(0)` is true at script invocation (depth-0 frame absent) and false
under `require`.

## Sub-stubbing in tests

`miniserv.t` is the canonical example. The pattern:

1. `require` the script. The guard skips its main body.
2. Replace side-effecting subs (socket I/O, logging, disk reads) with
   capture-buffer overrides under `no warnings 'redefine'`.
3. Populate package globals (`%miniserv::config`, `@miniserv::roots`, etc.)
   yourself instead of running the config loader.
4. Call the sub under test. Assert on contract (status code, presence of
   required headers, structural balance of emitted markup) — not on
   cosmetics like exact wording or class names.

Tying tests to the contract rather than the rendering lets the UI evolve
without breaking the test, while still catching real regressions.

## Tiered coverage policy

Not all 268 modules deserve the same investment.

- **Tier 1 — security-critical, network-facing.** `miniserv.pl`,
  `web-lib-funcs.pl`, `acl/`, auth, file upload paths. Comprehensive
  contract tests; mock filesystem and `backquote_command` for parser
  coverage of external-binary output.
- **Tier 2 — active refactor surface.** Currently `nftables/`, `firewalld/`,
  and whichever module is being reviewed. Mandatory tests for new code;
  `perlcritic.t` at severity 5 as a gate.
- **Tier 3 — stable OS-config wrappers.** Covered by `compile.t` plus
  optional per-module `perlcritic.t`. Don't chase line coverage on parsers
  for config files that haven't changed in a decade.

The goal is not coverage-as-a-number. It's:

- Every parser round-trips its serializer.
- Every privilege boundary has a test.
- Every external-binary call has a mock-driven test for its output parser.

## Perlcritic conventions

A few rewrites come up repeatedly when bringing a module under
`perlcritic.t` severity 5. Document them here so reviewers and future
refactors land on the same shape.

### Stringy `eval "use Module"` → block eval + `require`

`perlcritic` (BuiltinFunctions::ProhibitStringyEval) flags
`eval "use Module::Name;";`. The fix is a block eval that does the work
`use` would have done at compile time, deferred to runtime:

```perl
# before
eval "use DBI;";
if ($@) { return "DBI not installed"; }

# after
eval { require DBI; DBI->import; 1 }
        or return "DBI not installed";
```

The trailing `1` makes the block return true on success so the caller's
`or ...` only fires on failure. Pass import args the same way a `use`
would: `Module->import(qw(foo bar))`. If the module exports nothing you
need, drop the `->import` call but keep the `1`.

`acl/acl-lib.pl` has worked examples for the common shapes —
single-module probes, fallback chains (`SDBM_File` → `NDBM_File`,
`MD5` → `Digest::MD5`), and driver lookups (`DBD::mysql`, `DBD::Pg`,
`Net::LDAP`).

## Adding a per-module test directory

```
yourmodule/
  t/
    perlcritic.t   # see nftables/t/perlcritic.t for the template
    run-tests.t    # see nftables/t/run-tests.t for the WEBMIN_CONFIG / tmpdir setup
```

A module's tests are reachable from `prove -lr` at the repo root (no
path arg, so the recursive walk starts at the cwd). `prove -lr t` only
walks within `t/` and will miss `<module>/t/`.

## Caveats

- `WEBMIN_COMPILE_T_STRICT=1` turns missing-CPAN-module skips into failures.
  Use this in CI on a fully-provisioned image; leave it off on dev boxes
  where optional deps (`Pod::Simple::Wiki`, `Encode::Detect::Detector`) may
  not be installed.
- `.pl` is also the Polish translation suffix in Webmin. `compile.t` skips
  `<file>.pl` when a sibling `<file>` (no extension) exists; this catches
  `config.info.pl` and `module.info.pl` data files without a hardcoded list.

