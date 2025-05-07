ARG DEBIAN=bullseye
ARG RUBY=3.3

FROM debian:bullseye-slim AS base-bullseye

FROM base-${DEBIAN} AS ruby-2.6
ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.10
ENV RUBY_DOWNLOAD_SHA256 5fd8ded51321b88fdc9c1b4b0eb1b951d2eddbc293865da0151612c2e814c1f2

FROM base-${DEBIAN} AS ruby-2.7
ENV RUBY_MAJOR 2.7
ENV RUBY_VERSION 2.7.8
ENV RUBY_DOWNLOAD_SHA256 f22f662da504d49ce2080e446e4bea7008cee11d5ec4858fc69000d0e5b1d7fb

FROM base-${DEBIAN} AS ruby-3.0
ENV RUBY_MAJOR 3.0
ENV RUBY_VERSION 3.0.7
ENV RUBY_DOWNLOAD_SHA256 1748338373c4fad80129921080d904aca326e41bd9589b498aa5ee09fd575bab

FROM base-${DEBIAN} AS ruby-3.1
ENV RUBY_MAJOR 3.1
ENV RUBY_VERSION 3.1.7
ENV RUBY_DOWNLOAD_SHA256 658acc455b6bda87ac6cc1380e86552b9c1af87055e7a127589c5bf7ed80b035

FROM base-${DEBIAN} AS ruby-3.2
ENV RUBY_MAJOR 3.2
ENV RUBY_VERSION 3.2.8
ENV RUBY_DOWNLOAD_SHA256 1cccd3100155275293ae5d4ea0a1a1068f5de69e71732220f144acce26327a3c

FROM base-${DEBIAN} AS ruby-3.3
ENV RUBY_MAJOR 3.3
ENV RUBY_VERSION 3.3.8
ENV RUBY_DOWNLOAD_SHA256 44ae70fee043da3ce48289b7a52618ebe32dc083253993d486211c7e445c8642

FROM base-${DEBIAN} AS ruby-3.4
ENV RUBY_MAJOR 3.4
ENV RUBY_VERSION 3.4.3
ENV RUBY_DOWNLOAD_SHA256 174dcd8c516694f833fd3c93ea227fa6c3321464577a3882a6fc7e4fe20237fd

FROM ruby-${RUBY} AS release

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
  && { \
  echo 'install: --no-document'; \
  echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

ENV LANG C.UTF-8
ENV RUBY_MAJOR $RUBY_MAJOR
ENV RUBY_VERSION $RUBY_VERSION
ENV RUBY_DOWNLOAD_SHA256 $RUBY_DOWNLOAD_SHA256

ARG BUILD_AT
ENV BUILD_AT $BUILD_AT

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  bzip2 \
  ca-certificates \
  libffi-dev \
  libgmp-dev \
  libssl-dev \
  libyaml-dev \
  procps \
  zlib1g-dev \
  ; \
  rm -rf /var/lib/apt/lists/*

# skip installing gem documentation
RUN set -eux; \
  mkdir -p /usr/local/etc; \
  { \
  echo 'install: --no-document'; \
  echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
  \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  bison \
  dpkg-dev \
  libgdbm-dev \
  ruby \
  autoconf \
  g++ \
  gcc \
  libbz2-dev \
  libgdbm-compat-dev \
  libglib2.0-dev \
  libncurses-dev \
  libreadline-dev \
  libxml2-dev \
  libxslt-dev \
  make \
  wget \
  xz-utils \
  ; \
  rm -rf /var/lib/apt/lists/*; \
  \
  wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
  echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
  \
  mkdir -p /usr/src/ruby; \
  tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
  rm ruby.tar.xz; \
  \
  cd /usr/src/ruby; \
  \
  # hack in "ENABLE_PATH_CHECK" disabling to suppress:
  #   warning: Insecure world writable dir
  { \
  echo '#define ENABLE_PATH_CHECK 0'; \
  echo; \
  cat file.c; \
  } > file.c.new; \
  mv file.c.new file.c; \
  \
  autoconf; \
  gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
  ./configure \
  --build="$gnuArch" \
  --disable-install-doc \
  --enable-shared \
  ; \
  make -j "$(nproc)"; \
  make install; \
  \
  apt-mark auto '.*' > /dev/null; \
  apt-mark manual $savedAptMark > /dev/null; \
  find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
  | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
  | sort -u \
  | xargs -r dpkg-query --search \
  | cut -d: -f1 \
  | sort -u \
  | xargs -r apt-mark manual \
  ; \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  \
  cd /; \
  rm -r /usr/src/ruby; \
  # verify we have no "ruby" packages installed
  if dpkg -l | grep -i ruby; then exit 1; fi; \
  [ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
  # update bundler to latest version
  gem update --system; \
  gem install bundler; \
  # rough smoke test
  ruby --version; \
  gem --version; \
  bundle --version

# don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG="$GEM_HOME" \
  LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH $GEM_HOME/bin:$PATH

CMD [ "irb" ]
