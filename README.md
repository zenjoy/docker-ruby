# docker-ruby

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-zenjoy%2Fruby-lightgrey?style=flat)](https://hub.docker.com/r/zenjoy/ruby)
[![License](https://img.shields.io/github/license/zenjoy/docker-ruby)](https://github.com/zenjoy/docker-ruby/blob/main/LICENSE)

A rebuild of the official [`ruby:X.Y.Z-bookworm`](https://hub.docker.com/_/ruby) image, for when a
Ruby security release is out and the official image hasn't been published yet (that usually takes
16 to 24 hours).

The [Dockerfile](Dockerfile) is the Docker Library one
([docker-library/ruby](https://github.com/docker-library/ruby)) with the Ruby version and checksum
turned into build args. Same base (`buildpack-deps:bookworm`), same configure flags (YJIT, ZJIT on
Ruby 4.x, full RELRO), so `zenjoy/ruby:4.0.9-bookworm` can stand in for `ruby:4.0.9-bookworm`.

Images are built for `linux/amd64` and `linux/arm64` and pushed to Docker Hub and GHCR:

```sh
docker pull zenjoy/ruby:4.0.9-bookworm
docker pull ghcr.io/zenjoy/ruby:4.0.9-bookworm
```

Tags: `X.Y.Z-bookworm` and `X.Y-bookworm`. There is no `latest`.

## When to use it

Stay on the official image by default. When a Ruby release fixes something you can't wait for:

1. Run the [Build Ruby image](../../actions/workflows/build.yml) workflow with the version and the
   SHA256 of `ruby-X.Y.Z.tar.xz` from the ruby-lang.org release post. The workflow also checks it
   against `cache.ruby-lang.org/pub/ruby/index.txt`.
2. Point the app's base image at `zenjoy/ruby:X.Y.Z-bookworm`.
3. Switch back to `ruby:X.Y.Z-bookworm` once the official image is published.

Nothing rebuilds these images on a schedule, so they don't pick up Debian security updates after
they're built. Don't stay on one longer than needed.

## Keeping in sync with upstream

When docker-library changes its template (new rustup or Rust pin, configure flags, cleanup steps),
copy the change into the Dockerfile. Pull requests build the image for both platforms and run a
smoke test, without pushing.

Older `zenjoy/ruby` tags without the `-bookworm` suffix (`3.3.10`, `4.0.1`, ...) came from the
previous bullseye-slim build and are no longer updated.

## Container signatures

Images are signed with [Cosign](https://docs.sigstore.dev/cosign/overview/) using
[keyless signatures](https://docs.sigstore.dev/cosign/keyless/). To verify one:

```sh
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp https://github.com/zenjoy/docker-ruby/.github/workflows/ \
  zenjoy/ruby:4.0.9-bookworm
```

## License

View [license information](https://github.com/zenjoy/docker-ruby/blob/main/LICENSE) for the software
contained in this image.
