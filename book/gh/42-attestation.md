# attestation

Verify the integrity and provenance of artifacts, and download or prepare
attestation bundles for offline use.

## Mental model

An attestation is a cryptographically signed statement — a provenance claim —
that ties an artifact (a binary, container image, or archive) to the
GitHub Actions workflow that built it. The signature is anchored in Sigstore's
transparency log and in GitHub's own Sigstore instance, so anyone with the
public trust root can confirm that the artifact was produced by exactly the
workflow, on exactly the repository or runner, at exactly the commit you
expect.

Three concepts underpin every `attestation` command:

- **Subject.** The artifact being attested: a local file path or an OCI image
  URI (`oci://<image-uri>`).
- **Predicate.** The nature of the claim. The default predicate type is
  `https://slsa.dev/provenance/v1` (SLSA Provenance v1). Other predicate types
  can be verified with `--predicate-type`.
- **Actor identity.** The workflow and repository that signed the attestation.
  At minimum you must name the owning organization (`--owner`) or repository
  (`--repo`); for stronger guarantees you pin the exact workflow path with
  `--signer-workflow`.

Online verification (`verify`) reaches out to the GitHub API to fetch
attestations automatically. Offline verification requires you to first
`download` the attestation bundle and obtain a trusted root file via
`trusted-root`, then pass both to `verify --bundle` and
`verify --custom-trusted-root`.

## Synopsis

```text
gh attestation verify   [<file-path> | oci://<image-uri>] [--owner | --repo] [flags]
gh attestation download [<file-path> | oci://<image-uri>] [--owner | --repo] [flags]
gh attestation trusted-root [--tuf-url <url> --tuf-root <file-path>] [--verify-only] [flags]
```

`gh` also accepts the alias `gh at` for `gh attestation`.

## Everyday usage

### Verify a local binary against its owning repository

```sh
gh attestation verify myapp-linux-amd64 --repo my-org/myapp
```

### Verify using the owning organization (looser, still useful)

```sh
gh attestation verify myapp-linux-amd64 --owner my-org
```

### Verify a container image

```sh
# You must be authenticated with the registry before running this.
gh attestation verify oci://ghcr.io/my-org/myapp:v1.2.3 --owner my-org
```

### Download attestations for offline storage

```sh
gh attestation download myapp-linux-amd64 --repo my-org/myapp
# Writes: sha256:<digest>.jsonl  (sha256-<digest>.jsonl on Windows)
```

### Verify offline using a previously downloaded bundle

```sh
# Fetch the trusted root first (one-off, or refresh periodically)
gh attestation trusted-root > trusted_root.jsonl

# Then verify without network access
gh attestation verify myapp-linux-amd64 \
  --repo my-org/myapp \
  --bundle sha256:abc123.jsonl \
  --custom-trusted-root trusted_root.jsonl
```

### Emit full JSON for policy evaluation

```sh
gh attestation verify myapp-linux-amd64 --owner my-org --format json
```

## Key options

### verify

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-R` / `--repo` | Scope lookup to a specific `<owner>/<repo>` | Strongest identity check; use when you know the exact repo |
| `-o` / `--owner` | Scope lookup to a GitHub organization | When the repo is uncertain but the org is trusted |
| `--signer-workflow` | Require the signing workflow to match `[host/]<owner>/<repo>/<path>/<to>/<workflow>` | Pin the exact build definition; recommended for production |
| `--signer-repo` | Require the signing workflow's repo to match `<owner>/<repo>` | Needed when the signer is a reusable workflow in a separate repo |
| `-b` / `--bundle` | Path to a local bundle file (JSON or JSON lines) | Offline verification |
| `--bundle-from-oci` | Fetch the bundle from the OCI registry instead of GitHub | When attestations are stored in-registry |
| `--custom-trusted-root` | Path to a `trusted_root.jsonl` file | Offline or air-gapped verification |
| `--cert-identity` | Require the certificate SAN to match this value exactly | Exact signer identity enforcement |
| `-i` / `--cert-identity-regex` | Require the certificate SAN to match this regex | Flexible signer identity enforcement |
| `--predicate-type` | Require attestations to use this predicate type | Verifying non-SLSA attestations (default: `https://slsa.dev/provenance/v1`) |
| `--deny-self-hosted-runners` | Fail if any attestation was produced on a self-hosted runner | Enforce GitHub-hosted runner policy |
| `-d` / `--digest-alg` | Digest algorithm: `sha256` or `sha512` (default `sha256`) | SHA-512 artifact digests |
| `-L` / `--limit` | Maximum number of attestations to fetch (default 30) | Large repositories with many attestations |
| `--format` | Output format: `json` | Downstream policy enforcement |
| `-q` / `--jq` | Filter JSON output with a jq expression | Quick field extraction |
| `--no-public-good` | Do not verify attestations signed with the Sigstore public good instance | Custom trust roots only |
| `--hostname` | Target a specific GitHub host | GitHub Enterprise Server |

### download

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-R` / `--repo` | Scope lookup to `<owner>/<repo>` | Retrieve attestations for a specific repo |
| `-o` / `--owner` | Scope lookup to a GitHub organization | Retrieve all org-level attestations |
| `--predicate-type` | Filter downloaded bundles by predicate type | When only one attestation type is needed |
| `-L` / `--limit` | Maximum number of attestations to fetch (default 30) | Limit bundle file size |
| `-d` / `--digest-alg` | Digest algorithm: `sha256` or `sha512` (default `sha256`) | SHA-512 artifact digests |
| `--hostname` | Target a specific GitHub host | GitHub Enterprise Server |

### trusted-root

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--tuf-url` | URL of a custom TUF repository mirror | Custom or enterprise Sigstore deployments |
| `--tuf-root` | Path to the TUF `root.json` obtained out-of-band | Required alongside `--tuf-url` |
| `--verify-only` | Check local TUF repository integrity without printing a bundle | Periodic health-check without output |
| `--hostname` | Target a specific GitHub host | GitHub Enterprise Server |

## Best practices

**Always pin the signer workflow for production gates.** Specifying `--owner`
alone trusts any workflow in any repository belonging to that organization.
Specifying `--repo` narrows it to one repository. Adding `--signer-workflow`
locks down the exact `.yml` file. For a supply-chain security gate in CI,
use all three in combination:

```sh
gh attestation verify dist/myapp \
  --repo my-org/myapp \
  --signer-workflow my-org/myapp/.github/workflows/release.yml
```

**Verify before deploying, not after.** Run `gh attestation verify` as an
explicit step in your deployment pipeline. A passing attestation check means
the binary was produced by your controlled workflow from your controlled
source — not a tampered artifact injected after the build.

**Use `--deny-self-hosted-runners` in high-security environments.** Self-hosted
runners are harder to audit. GitHub-hosted runners run in ephemeral VMs with
a known baseline. If your security policy requires ephemeral, GitHub-managed
build environments, add this flag to your verification commands.

**Store trusted roots alongside attestation bundles for air-gapped use.**
Run `gh attestation trusted-root > trusted_root.jsonl` on a machine with
internet access, then copy both the `.jsonl` bundle and `trusted_root.jsonl`
into the air-gapped environment. The trusted root is tied to a specific TUF
snapshot, so refresh it periodically (e.g., weekly) as the TUF repository
rotates keys.

**Pipe `--format json` output into a policy engine for custom enforcement.**
The JSON array returned by a successful verification contains
`signature.certificate` and `verifiedTimestamps` fields whose contents
cannot be forged by the signing workflow. Build your allow/deny logic on
those fields. Be cautious when reading `statement.predicate` — that content
is user-controlled and could be manipulated if the workflow were compromised.

## Pitfalls & gotchas

**`--owner` does not mean "any repo in the org is fine forever."** It means
the attestation's certificate must show an owner that matches the flag value.
This is a good floor but a weak ceiling. Pair it with `--signer-workflow` to
avoid accidentally accepting an attestation from a fork or a workflow you did
not author.

**Reusable workflows require `--signer-repo` or `--signer-workflow` pointed at
the reusable workflow, not the caller.** When a release is signed inside a
reusable workflow hosted at `actions/slsa-goreleaser`, the certificate SAN
names that reusable workflow, not your repo's caller workflow. Using
`--repo my-org/myapp` alone will fail. You need:

```sh
gh attestation verify dist/myapp \
  --owner my-org \
  --signer-repo actions/slsa-goreleaser
```

**OCI verification requires prior registry authentication.** `gh` does not
handle registry login. Run `docker login ghcr.io` (or the equivalent for
your registry) before passing `oci://` URIs to `verify` or `download`.

**Bundle file names contain colons on non-Windows systems.** The file
written by `download` is named `sha256:<digest>.jsonl` on Linux/macOS. On
Windows the colon is illegal and the file becomes `sha256-<digest>.jsonl`.
Write scripts to handle both forms if they run cross-platform.

**`download` is still in public preview and may change.** The `--help`
output notes this explicitly. Avoid hard-coding the output file format or
naming convention in production pipelines until the subcommand reaches GA.

**Attestations are fetched from the GitHub API by default — not from the
artifact itself.** The artifact and its attestation are independent objects.
If an artifact is copied to a new registry without its attestation being
republished, `verify` will fail. Use `--bundle-from-oci` when the registry
stores the attestation alongside the image.

## Worked examples

### End-to-end: build, attest, verify in a GitHub Actions release workflow

A typical release workflow produces a binary, generates an attestation via
`actions/attest-build-provenance`, and then a deployment job verifies before
rolling out.

```yaml
jobs:
  release:
    permissions:
      id-token: write      # Required to mint the OIDC token for signing
      contents: write      # Required to upload release assets
      attestations: write  # Required to create attestations
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make dist/myapp
      - name: Attest build provenance
        uses: actions/attest-build-provenance@v1
        with:
          subject-path: dist/myapp

  deploy:
    needs: release
    steps:
      - name: Download release asset
        run: gh release download v1.2.3 --pattern "myapp" --repo my-org/myapp
      - name: Verify attestation
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh attestation verify myapp \
            --repo my-org/myapp \
            --signer-workflow my-org/myapp/.github/workflows/release.yml
```

### Offline verification in an air-gapped environment

On a machine with internet access, prepare the verification bundle:

```sh
# Download the attestation bundle
gh attestation download dist/myapp --repo my-org/myapp
# -> writes sha256:abc123def456.jsonl

# Fetch the current trusted root
gh attestation trusted-root > trusted_root.jsonl
```

Transfer `sha256:abc123def456.jsonl`, `trusted_root.jsonl`, and `dist/myapp`
to the air-gapped machine. Then verify:

```sh
gh attestation verify dist/myapp \
  --repo my-org/myapp \
  --bundle sha256:abc123def456.jsonl \
  --custom-trusted-root trusted_root.jsonl
```

```text
Loaded digest sha256:abc123def456... for file://dist/myapp
Loaded 1 attestation from the bundle
✓ Verification succeeded!

sha256:abc123def456...
  - Attestation verified using a bundle with 1 attestation(s).
```

### Extracting certificate fields for policy decisions

After verifying, extract the source repository and ref from the certificate to
enforce a "tagged release only" policy:

```sh
gh attestation verify dist/myapp --owner my-org --format json | \
  jq '.[].verificationResult.signature.certificate | {
    sourceRepository: .extensions.sourceRepository,
    sourceRef:        .extensions.sourceRepositoryRef
  }'
```

```text
{
  "sourceRepository": "https://github.com/my-org/myapp",
  "sourceRef":        "refs/tags/v1.2.3"
}
```

Fail the deployment if the ref is not a tag:

```sh
ref=$(gh attestation verify dist/myapp --owner my-org --format json \
  | jq -r '.[0].verificationResult.signature.certificate.extensions.sourceRepositoryRef')

if [[ "$ref" != refs/tags/* ]]; then
  echo "ERROR: artifact was not built from a tagged release (got: $ref)" >&2
  exit 1
fi
```

## Recovery

If verification fails with "no attestations found", the artifact may not have
been attested, or you may have specified the wrong `--owner` / `--repo`. Check
that the repository name matches exactly, then try broadening to `--owner` to
rule out a repository naming mismatch.

If verification fails with a certificate identity error, a reusable workflow
is likely the actual signer. Inspect the raw attestation to find the true SAN:

```sh
gh attestation download dist/myapp --repo my-org/myapp
jq '.[0].bundle.verificationMaterial.certificate.rawBytes' sha256:*.jsonl
```

Decode the base64-encoded certificate and look at the SAN extension to
determine the correct value for `--signer-workflow` or `--signer-repo`.

If the trusted root becomes stale and offline verification fails with a
timestamp or certificate error, refresh the trusted root on a connected
machine and re-transfer it:

```sh
gh attestation trusted-root > trusted_root.jsonl
```

## See also

- *auth* — `gh auth login` is required before calling the GitHub API; set
  `GH_TOKEN` for CI use.
- *release* — `gh release download` retrieves the artifacts you then pass to
  `gh attestation verify`.
- *run* — `gh run view` lets you trace which Actions run produced a given
  artifact before verifying its attestation.
