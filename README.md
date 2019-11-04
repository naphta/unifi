# UniFi Controller on Docker
![Build status](https://github.com/naphta/unifi/workflows/Test,%20build,%20and%20push/badge.svg)

## Backstory

First and foremost this project is largely derived from the
https://github.com/jacobalberty/unifi-docker project which
I've been using personally now for around a year.

Recently I'd picked up a Raspberry Pi 4B for the purpose
of running https://github.com/rancher/k3s on. After getting
the "cluster" up and running I noticed that Jacob's project
wasn't being built for ARM64. Firstly I looked into how to
pass a pull request through to him which would enable that
support but as the build process appears to be ran offline
I decided that either a fork or inspired project would be
the way forward.

Keen to move on I decided to go with an inspired project
solely because of the Travis CI integration and I wanted
to try out GitHub Actions specifically. This seemed like
a reasonable use case.

My intention is to diverge this code base more in the
coming weeks/months.

## Planned changes

- Port `docker-build.sh` to use Ansible
- Update MongoDB installation to be compiled from source
  to support more architectures.
- Provide image variants without MongoDB
- Provide PKGURL argument based on current git tag to enable
  quick and easy upgrades where no major code change is
  required.
