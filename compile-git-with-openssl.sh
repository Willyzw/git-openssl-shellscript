#!/usr/bin/env bash
set -e

# Gather command line options
for i in "$@"; do 
  case $i in 
    -skiptests|--skip-tests) # Skip tests portion of the build
    SKIPTESTS=YES
    shift
    ;;
    -d=*|--build-dir=*) # Specify the directory to use for the build
    BUILDDIR="${i#*=}"
    shift
    ;;
    -skipinstall|--skip-install) # Skip dpkg install
    SKIPINSTALL=YES
    ;;
    *)
    #TODO Maybe define a help section?
    ;;
  esac
done

# Use the specified build directory, or create a unique temporary directory
BUILDDIR=${BUILDDIR:-$(mktemp -d)}
echo "BUILD DIRECTORY USED: ${BUILDDIR}" 
mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

# Download the source tarball from GitHub
apt update
apt install curl -y
git_tarball_url="https://github.com/git/git/archive/v2.29.0.tar.gz"
echo "DOWNLOADING FROM: ${git_tarball_url}"
curl -k -L --retry 5 "${git_tarball_url}" --output "git-source.tar.gz"
tar -xf "git-source.tar.gz" --strip 1

# Source dependencies
# Don't use gnutls, this is the problem package.
apt remove --purge libcurl4-gnutls-dev -y || true
# Using apt-get for these commands, they're not supported with the apt alias on 14.04 (but they may be on later systems)
apt-get autoremove -y
apt-get autoclean
# Meta-things for building on the end-user's machine
apt install build-essential autoconf dh-autoreconf -y
# Things for the git itself
apt install libcurl4-openssl-dev tcl-dev gettext asciidoc -y
apt install libexpat1-dev libz-dev -y

# Build it!
make configure
# --prefix=/usr
#    Set the prefix based on this decision tree: https://i.stack.imgur.com/BlpRb.png
#    Not OS related, is software, not from package manager, has dependencies, and built from source => /usr
# --with-openssl
#    Running ripgrep on configure shows that --with-openssl is set by default. Since this could change in the
#    future we do it explicitly
./configure --prefix=/usr --with-openssl
make 
if [[ "${SKIPTESTS}" != "YES" ]]; then
  make test
fi

# Install
if [[ "${SKIPINSTALL}" != "YES" ]]; then
  # If you have an apt managed version of git, remove it
  if apt remove --purge git -y; then
    apt-get autoremove -y
    apt-get autoclean
  fi
  # Install the version we just built
  make install #install-doc install-html install-info
  echo "Make sure to refresh your shell!"
  bash -c 'echo "$(which git) ($(git --version))"'
fi
