# docker-ruby

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-zenjoy%2Fruby-lightgrey?style=flat)](https://hub.docker.com/r/zenjoy/ruby)
[![License](https://img.shields.io/github/license/zenjoy/docker-ruby)](https://github.com/zenjoy/docker-ruby/blob/main/LICENSE)

The official [Debian](https://hub.docker.com/_/debian) Docker image with Ruby.

Available on [Docker Hub](https://hub.docker.com/r/zenjoy/ruby) or
[GitHub Container Registry](https://ghcr.io/zenjoy/ruby) (GHCR) for AMD64 or ARM64.

```sh
# Docker Hub
docker pull zenjoy/ruby:latest

# GHCR
docker pull ghcr.io/zenjoy/ruby:latest
```

## Container signatures

All images are automatically signed via [Cosign](https://docs.sigstore.dev/cosign/overview/) using
[keyless signatures](https://docs.sigstore.dev/cosign/keyless/). You verify the integrity of these
images as follows:

```sh
cosign verify \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp https://github.com/zenjoy/docker-ruby/.github/workflows/ \
  zenjoy/ruby:latest
```

## Contributing

Feel free to contribute and make things better by opening an
[Issue](https://github.com/zenjoy/docker-ruby/issues) or
[Pull Request](https://github.com/zenjoy/docker-ruby/pulls).

## License

View [license information](https://github.com/zenjoy/docker-ruby/blob/main/LICENSE) for the software
contained in this image.
