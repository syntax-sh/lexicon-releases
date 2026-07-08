# lexicon-releases

Prebuilt binary releases for [lexicon](https://syntax.sh/lexicon), the CLI
that builds a shared, indexed cache of vendor library/API documentation for
coding agents. The source is private; releases are published here.

## Install

**Homebrew (macOS / Linux):**

```sh
brew install syntax-sh/tap/lexicon
```

**npm** (bundled per-platform binaries — no install scripts, works with
`--ignore-scripts`):

```sh
npm install -g @syntax-sh/lexicon
```

**With [mise](https://mise.jdx.dev):**

```toml
# mise.toml
[tools]
"ubi:syntax-sh/lexicon-releases" = { version = "latest", exe = "lexicon" }
```

**Shell installer (macOS / Linux):**

```sh
curl --proto '=https' --tlsv1.2 -LsSf https://syntax.sh/lexicon/install.sh | sh
```

**Windows (PowerShell):**

```powershell
powershell -c "irm https://syntax.sh/lexicon/install.ps1 | iex"
```

## Verifying releases

Every artifact is a `.tar.gz` with a `.sha256` checksum file published
alongside it. Release tags are pushed by the source repo's CI (cargo-dist)
and the npm packages are published from this repo's
[`publish-npm` workflow](.github/workflows/publish-npm.yml) with
[npm provenance](https://docs.npmjs.com/generating-provenance-statements),
so each npm version is attested against this repository and workflow.

Supported targets: macOS arm64/x86_64, Linux x86_64, Windows x86_64.
