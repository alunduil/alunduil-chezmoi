# The fresh Debian host docs/tutorials/bootstrap.md starts from: systemd as
# init, as in Crostini's container, and a login user with passwordless sudo.
# The apt lists stay, as on an installed host. script/checks/fresh-host
# supplies the user.
FROM debian:bookworm@sha256:d74df7598108a173a621eda4d58a2adbf850b2d9a9d81bc2cca1a6c21174a880

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
