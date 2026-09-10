# Changelog

What changed in each release, and which image it is.

The release artifact is the container image named under each version. Its index digest is what
[cosign signs](SECURITY.md), so the digest — not this file and not a tag — is what identifies a
release. Deployments learn that a newer version exists by reading the release feed at
`https://flintbay.io/releases.json` and comparing it against their own version locally; nothing
about the deployment is sent anywhere.

Headings are the bare version, so the anchor for a version is its number without the dots:
`#012` for 0.1.2.

## 0.1.2

Released 2026-09-10.

- Pasting an address into Connection Studio no longer inserts it twice.
- The default font size now follows the form factor of the device you are on.

```
ghcr.io/flintbayhq/flintbay:0.1.2
index  sha256:237cc19ad09730d2835fc1c4c9cd60c7f9e992c752f980139e83922b5b97a073
amd64  sha256:03aca0a98dd72215330183266dfd61abd8b779776e4812cfda9ea594511d27cb
arm64  sha256:a8fee7fc1a7b548f4a9708c36ea68dba81d54581236ea15ab6997c5db3a8764c
```

## 0.1.1

Released 2026-09-08.

- The version shown in About is now read from the image itself, instead of a placeholder that
  always said 1.0.0.
- The interface tells you when a newer version has been released. The check compares versions on
  your deployment and sends nothing about it.
- Release verification in CI now pins every action by commit and checks each architecture by its
  own digest.

```
ghcr.io/flintbayhq/flintbay:0.1.1
index  sha256:67f8a427ee83625ddcf510cabe87dd488fef97cfa30cc1c25f79597b660a9a7e
```

## 0.1.0

Released 2026-09-08. First stable release.

- One protected multi-architecture image for amd64 and arm64.
- The published index is signed with cosign and can be verified before deploying.

```
ghcr.io/flintbayhq/flintbay:0.1.0
index  sha256:b934d968c031d7889b83ae8a0bba72d764ed9880927044bf79acc119122cfbde
```
