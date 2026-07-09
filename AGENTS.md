# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-fips` is a small SIMP Puppet module that manages **FIPS 140-2 mode** on
Enterprise Linux systems. It sets the `fips` kernel boot parameter, installs or
removes the `dracut-fips` package(s), keeps the `nss` and `fipscheck`-provider
packages at the desired state, and rebuilds the initramfs so the change takes
effect on the next boot. On crypto-policy-capable systems (EL8+) it delegates
the policy side to the `crypto_policy` module.

The module is intentionally conservative. **By default it mirrors the system's
current FIPS status rather than forcing a state** — `fips::enabled` defaults to
the live `fips_enabled` fact — because unexpectedly toggling FIPS is dangerous:
changing FIPS status changes the cryptographic modules in use and can render
existing keys and certificates unusable (`manifests/init.pp`). The
supported way to enable FIPS across all SIMP modules is to set
`simp_options::fips: true` in Hiera (`manifests/init.pp`).

### Business logic

The module is a single public class; there are no defines and no other classes.

- **`fips` (`manifests/init.pp`)** — Public entry class (not
  `assert_private()`'d; consumers `include 'fips'`). Key parameters
  (`init.pp`):
  - `$fipscheck_package_name` (`String`, **no default**) — required; supplied
    from module data (`data/common.yaml` → `libxcrypt`; overridden to
    `fipscheck` for RedHat-8 and Amazon-2 via `data/os/*.yaml`). This is the
    package providing the `fipscheck` binary.
  - `$enabled` (`Boolean`) — the master switch. Defaults to
    `simplib::lookup('simp_options::fips', { 'default_value' => $facts['fips_enabled'] })`
    (`init.pp`), i.e. the **current** system state when `simp_options::fips`
    is unset.
  - `$aesni` (`Boolean`) — auto-detected: true when the CPU flags include `aes`
    (`init.pp`).
  - `$dracut_ensure`, `$fipscheck_ensure`, `$nss_ensure` (`String`) — each
    defaults to `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' })`
    (`init.pp`).

  Control flow and resources:
  - `$fips_kernel_value` selector: `$enabled ? { true => '1', default => '0' }`
    (`init.pp`).
  - **crypto_policy branch** (`init.pp`): when the fact
    `simplib__crypto_policy_state` is populated (EL8+ with the crypto-policy
    tools), it calls `simplib::assert_optional_dependency($module_name,
    'simp/crypto_policy')`, `include`s `crypto_policy`, and **forces
    `$fips_package_status = 'installed'` even when `$dracut_ensure == 'absent'`**
    — EL8+ rolls FIPS into the base dracut package, so it must never be
    uninstalled. Otherwise `$fips_package_status = $dracut_ensure`.
  - **legacy branch** (`init.pp`): on non-crypto-policy systems,
    `$fips_package_status = $enabled ? { true => $dracut_ensure, default => 'absent' }`
    — here the dracut package *is* removed when disabling.
  - `kernel_parameter { 'fips' }` (`init.pp`) set to `$fips_kernel_value`,
    notifying `Reboot_notify['fips']` and `Exec['dracut_rebuild']`.
  - **`boot` kernel parameter** (`init.pp`): managed **only** when both
    `$facts['boot_dir_uuid']` and `$facts['root_dir_uuid']` are set. If the two
    UUIDs are equal (same partition) → `kernel_parameter { 'boot': ensure =>
    absent }`; if different (separate `/boot`) → `value => "UUID=${boot_dir_uuid}"`.
    Both notify the reboot.
  - `package { 'dracut-fips' }` at `$fips_package_status`, notifying the rebuild
    (`init.pp`); `package { $fipscheck_package_name }` at `$fipscheck_ensure`
    (`init.pp`); `package { 'nss' }` at `$nss_ensure` (`init.pp`).
  - **aesni branch** (`init.pp`): if `$aesni`, adds
    `package { 'dracut-fips-aesni' }` and pins ordering — enabling installs
    `dracut-fips` before `dracut-fips-aesni`, disabling reverses it, because the
    packages fail if removed/installed in the wrong order.
  - `reboot_notify { 'fips' }` (`init.pp`).
  - `exec { 'dracut_rebuild' }` (`init.pp`) — `refreshonly => true`,
    `subscribe => Package['nss']`. Its command is
    `command fips-mode-setup ${_fips_mode_setup_opt} || dracut -f --regenerate-all`,
    where the leading `command` is the shell builtin (verbatim from the manifest),
    `$_fips_mode_setup_opt` is `--enable` when enabling FIPS else `--disable`, and
    the `||` fallback covers systems without `fips-mode-setup`.

### Gotchas / non-obvious details

- **The module mirrors state; it does not force it.** With no configuration,
  applying `fips` will *not* toggle FIPS — `$enabled` defaults to the
  `fips_enabled` fact (`init.pp`). To actually enable, set
  `simp_options::fips: true` in Hiera.
- **A reboot is required for every FIPS change.** All FIPS-relevant resources
  notify `reboot_notify { 'fips' }` (`init.pp`); the state only takes
  effect after the host reboots.
- **On EL8+, never uninstall `dracut-fips`.** The crypto_policy branch forces it
  to `installed` even when `$dracut_ensure == 'absent'` (`init.pp`);
  disabling FIPS there is handled by `fips-mode-setup --disable`, not by removing
  the package. Legacy systems (e.g. Amazon 2) *do* remove it when disabling.
- **Changing FIPS can break existing crypto material** (keys/certs) —
  understand the impact before flipping it (`init.pp`).
- **NSS and dracut must stay in sync** or the system may not reboot
  (`init.pp`); the rebuild exec subscribes to `Package['nss']`.
- **`boot` kernel parameter is silently skipped** unless both boot/root UUID
  facts are present (`init.pp`) — this is why the unit spec injects those
  facts.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  the manifest consumes the `simp_options::*` seam via `simplib::lookup`
  (provided by `simp/simplib`). `simp_options` appears only as a fixture
  (`.fixtures.yml`). `simp/crypto_policy` is an **optional** dependency
  (`metadata.json` `simp.optional_dependencies`), asserted at runtime with
  `simplib::assert_optional_dependency` only on crypto-policy systems.
- Two cosmetic docstring typos exist near `init.pp` ("yo set", duplicated
  "ALL") — harmless, left as-is.

## The `simp_options` / `simplib::lookup` seam

This is the module's real business-logic seam (the natural target for a
lookup-path unit test). All calls are in `manifests/init.pp`:

| File | Key | `default_value` |
|------|-----|-----------------|
| `init.pp` | `simp_options::fips` | `$facts['fips_enabled']` (live fact) |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json`):

- `simp/simplib` `>= 4.9.0 < 6.0.0` (provides `simplib::lookup`,
  `simplib::assert_optional_dependency`, `reboot_notify`, and the
  `fips_enabled` / `cpuinfo` / `boot_dir_uuid` / `root_dir_uuid` /
  `simplib__crypto_policy_state` facts)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (provides `member()`)
- `puppet/augeasproviders_grub` `>= 3.1.0 < 6.0.0` (provides the
  `kernel_parameter` type/provider)

Optional dependency (from `metadata.json` `simp.optional_dependencies`):

- `simp/crypto_policy` `>= 0.1.4 < 3.0.0` — used only on crypto-policy systems.

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation,
not runtime deps): `augeasproviders_core`, `simp_options` (plus the runtime and
optional deps above are also checked out as fixtures).

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0`. (SIMP is migrating Puppet → OpenVox; when
`metadata.json` switches this to `openvox`, update this line to match.)

Supported OS matrix (from `metadata.json`): Amazon 2; CentOS 9/10; RedHat
8/9/10; OracleLinux 8/9/10; Rocky 8/9/10; AlmaLinux 8/9/10.

## Repository layout

- `manifests/init.pp` — the sole manifest; the `fips` class (all logic).
- `data/common.yaml` — default `fips::fipscheck_package_name: libxcrypt`.
- `data/os/RedHat-8.yaml`, `data/os/Amazon-2.yaml` — override to `fipscheck`.
- `hiera.yaml` — module data hierarchy (v5): OS name+major → OS family+major →
  common.
- `metadata.json` — deps, optional deps, OS matrix, Puppet requirement.
- `spec/classes/init_spec.rb` — rspec-puppet unit tests (injects the
  boot/root UUID and FIPS facts).
- `spec/acceptance/suites/default/00_default_spec.rb` — beaker acceptance suite
  (enables FIPS via `simp_options::fips: true`, reboots, asserts the
  `fips_enabled` fact and package states); nodesets under
  `spec/acceptance/nodesets/` (plus a `gce` suite's nodesets).
- `REFERENCE.md` — generated Puppet Strings reference.
- No `types/`, `lib/`, or `templates/` — this module has no custom data types,
  Ruby types/providers/functions/facts, or templates. Every custom type, fact,
  and function it uses comes from the dependencies above.
- **Acceptance runs in CI:** `.github/workflows/pr_tests.yml` has an
  `acceptance` job (matrix `almalinux8`, `almalinux10`) whose final step runs
  `bundle exec rake beaker:suites[default,<node>]` under
  `BEAKER_HYPERVISOR=vagrant_libvirt`.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run the single class spec
bundle exec rspec spec/classes/init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run the default beaker acceptance suite
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`,
`simp-rake-helpers ~> 5.24.0`, `simp-rspec-puppet-facts ~> 4.0.0`,
`simp-beaker-helpers ~> 2.0.0`. Rubocop is pinned to `~> 1.88.0`. The tested
Puppet range is `>= 7 < 9`.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on the class —
  they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or
  parameters.
- Keep `$fipscheck_package_name` in module data (`data/*.yaml`), not hard-coded
  in the manifest.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` rather than
  assuming `simp_options` is included.
- Guard optional integrations (`crypto_policy`) with
  `simplib::assert_optional_dependency` and a fact check, as the crypto_policy
  branch does — don't hard-`include` optional modules.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in `manifests/init.pp`.
