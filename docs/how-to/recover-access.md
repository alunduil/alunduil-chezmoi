# Recovering access

Every secret this repo deploys lives in the `chezmoi` 1Password vault,
so recovering a host means recovering 1Password first. This guide covers
two cases: a lost device with the account intact, and a lost account.

## Keep the Emergency Kit

The 1Password Emergency Kit holds the sign-in address, email, and Secret
Key. Together with the account password, it signs in on a host with no
other 1Password device. Print it, store it in a physical safe, and print
a fresh copy whenever the Secret Key or password changes.

## Recover on a new host

1. Follow [the bootstrap](../tutorials/bootstrap.md). When it asks you
   to sign in to 1Password, use the Emergency Kit and the account
   password.
2. Remove the lost device from the account in 1Password, under
   **Settings → Devices** on the web.

The second apply restores every token, the GPG key, and SSH access.

## Recover without the 1Password account

When the account itself is gone, nothing in this repo can restore the
vault. Replace each credential at its source:

1. Restore the GPG key from its paper backup
   ([pgp-signing.md](pgp-signing.md)).
2. Create a new 1Password account, a vault named `chezmoi`, and an SSH
   key item in it. Register the public key on GitHub and in the Home
   Assistant SSH add-on.
3. Issue a new token at Codecov, GitHub, Grafana Cloud, TrueNAS, and
   UptimeRobot, and store each as an API Credential item with the token
   in its `credential` field.
4. Replace each item ID in `.chezmoidata/onepassword.yaml`.
5. Revoke every old token at its service.
