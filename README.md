# CKAD Exam Preparation

## Known Issues

### Fedora Linux

- The container might not be able to access the docker-daemon (see: [github issue](https://github.com/devcontainers/features/issues/1235))
  - solution: enable the ip_tables kernel module: `sudo modprobe ip_tables`
