FROM cowrie/cowrie:latest

# Persona is overridden at deploy time by ECS environment variables.
# Env var names follow the COWRIE_<SECTION>_<STANZA> rule - verify against etc/cowrie.cfg.dist.
ENV COWRIE_HONEYPOT_HOSTNAME=svr04
ENV COWRIE_SSH_VERSION="SSH-2.0-OpenSSH_7.4"

# Optional custom config (JSON logging etc). Path assumed from the official image - verify.
COPY config/cowrie.cfg /cowrie/cowrie-git/etc/cowrie.cfg

EXPOSE 2222
