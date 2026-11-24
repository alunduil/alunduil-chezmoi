# The fresh Debian host docs/tutorials/bootstrap.md starts from: systemd as
# init, as in Crostini's container, and a login user with passwordless sudo.
# The apt lists stay, as on an installed host. script/checks/fresh-host
# supplies the user.
FROM debian:trixie@sha256:3cda3ca472ce45507a5109c6a3907093e24d9ae67d55954c9a07a45665dafba2

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

# overlay2, which daemon.json sets, can't mount on the image's own overlay
# filesystem. A volume puts Docker's data on the runner's disk instead.
VOLUME /var/lib/docker

CMD ["/sbin/init"]
