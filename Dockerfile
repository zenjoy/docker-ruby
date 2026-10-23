# syntax=docker/dockerfile:1

# Mirror of the official Docker Library image (docker-library/ruby, `<major.minor>/<suite>/Dockerfile`;
# bookworm and trixie share the template), so `zenjoy/ruby:X.Y.Z-trixie` is a drop-in for
# `ruby:X.Y.Z-trixie`. Only the version pin and the Debian suite are lifted into build args, so a Ruby
# security release can be built before the official image lands.
# Keep the RUN steps in sync with upstream; don't diverge.
#
# https://github.com/docker-library/ruby/blob/master/Dockerfile.template

ARG DEBIAN_SUITE=trixie

FROM buildpack-deps:${DEBIAN_SUITE}

ARG DEBIAN_SUITE
ARG RUBY_VERSION
ARG RUBY_DOWNLOAD_SHA256

# skip installing gem documentation with `gem install`/`gem update`
RUN set -eux; \
	mkdir -p /usr/local/etc; \
	echo 'gem: --no-document' >> /usr/local/etc/gemrc

ENV LANG=C.UTF-8

ENV RUBY_VERSION=${RUBY_VERSION}
ENV RUBY_DOWNLOAD_URL=https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.xz
ENV RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256}

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
	[ -n "$RUBY_VERSION" ] && [ -n "$RUBY_DOWNLOAD_SHA256" ]; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		libgdbm-dev \
		ruby \
	; \
	\
	rustArch=; \
	dpkgArch="$(dpkg --print-architecture)"; \
	case "$dpkgArch" in \
		'amd64') rustArch='x86_64-unknown-linux-gnu'; rustupUrl='https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init'; rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;; \
		'arm64') rustArch='aarch64-unknown-linux-gnu'; rustupUrl='https://static.rust-lang.org/rustup/archive/1.28.2/aarch64-unknown-linux-gnu/rustup-init'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;; \
	esac; \
	\
	if [ -n "$rustArch" ]; then \
		mkdir -p /tmp/rust; \
		\
		wget -O /tmp/rust/rustup-init "$rustupUrl"; \
		echo "$rustupSha256 */tmp/rust/rustup-init" | sha256sum --check --strict; \
		chmod +x /tmp/rust/rustup-init; \
		\
		export RUSTUP_HOME='/tmp/rust/rustup' CARGO_HOME='/tmp/rust/cargo'; \
		export PATH="$CARGO_HOME/bin:$PATH"; \
		/tmp/rust/rustup-init -y --no-modify-path --profile minimal --default-toolchain '1.91.1' --default-host "$rustArch"; \
		\
		rustc --version; \
		cargo --version; \
	fi; \
	\
	wget -O ruby.tar.xz "$RUBY_DOWNLOAD_URL"; \
	echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
	\
	mkdir -p /usr/src/ruby; \
	tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
	rm ruby.tar.xz; \
	\
	cd /usr/src/ruby; \
	\
	autoconf; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
# ZJIT only exists from Ruby 4.0; upstream's 3.x templates leave the flag out
	zjit=; \
	case "$RUBY_VERSION" in 3.*) ;; *) zjit="${rustArch:+--enable-zjit}" ;; esac; \
# full RELRO: "-z now" disables lazy binding so the loader can map the GOT read-only at startup
# https://github.com/docker-library/ruby/pull/529
	export LDFLAGS='-Wl,-z,relro -Wl,-z,now'; \
	./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
		${rustArch:+--enable-yjit} \
		$zjit \
	; \
	make -j "$(nproc)"; \
	make install; \
	\
	rm -rf /tmp/rust; \
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
# upstream: `apt-get dist-clean` on trixie and later, bookworm's apt doesn't have it
	case "$DEBIAN_SUITE" in bookworm) rm -rf /var/lib/apt/lists/* ;; *) apt-get dist-clean ;; esac; \
	\
	cd /; \
	rm -r /usr/src/ruby; \
# verify we have no "ruby" packages installed
	if dpkg -l | grep -i ruby; then exit 1; fi; \
	[ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
# rough smoke test
	ruby --version; \
	gem --version; \
	bundle --version

# don't create ".bundle" in all our apps
ENV GEM_HOME=/usr/local/bundle
ENV BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH=$GEM_HOME/bin:$PATH
RUN set -eux; \
	mkdir "$GEM_HOME"; \
# adjust permissions of GEM_HOME for running "gem install" as an arbitrary user
	chmod 1777 "$GEM_HOME"

CMD [ "irb" ]
