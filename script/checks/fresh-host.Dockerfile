# The fresh Debian host docs/tutorials/bootstrap.md starts from: systemd as
# init, as in Crostini's container, and a login user with passwordless sudo.
# The apt lists stay, as on an installed host. script/checks/fresh-host
# supplies the user.
FROM debian:trixie@sha256:9c6e381421d0f48d1b8133e573f33c185ee16cbf505eda9c4a8a4791b25ea8a6

ARG USER
ARG UID

# Linger starts the user's systemd manager at boot, as a desktop login would.
# Noninteractive debconf stands in for the person answering package prompts.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    dbus dbus-user-session sudo systemd systemd-sysv \
  && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && useradd --create-home --shell /bin/bash --uid "$UID" "$USER" \
  && echo "$USER ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/$USER" \
  && mkdir -p /var/lib/systemd/linger \
  && touch "/var/lib/systemd/linger/$USER"

CMD ["/sbin/init"]
