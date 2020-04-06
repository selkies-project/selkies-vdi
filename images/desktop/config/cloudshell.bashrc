
# If not running interactively, return
case $- in
    *i*) ;;
      *) return;;
esac
if [ -f "/google/devshell/bashrc.google" ]; then
  source "/google/devshell/bashrc.google"
fi

unset CLOUDSDK_CONFIG
unset DEVSHELL_GCLOUD_CONFIG
unset DEVSHELL_CLIENT
unset DEVSHELL_CLIENT_PORT
unset DEVSHELL_CLIENT_DIR
unset DEVSHELL_CLIENTS_DIR
unset CREDENTIALS_SERVICE_PORT

export DOCKER_HOST="tcp://127.0.0.1:2376"
export DOCKER_TLS="true"
export DOCKER_CERT_PATH="/var/run/docker-certs"

# Default to use git-prompt as PS1
source /usr/share/code-server/git-prompt.sh
PS1='[\u@\W$(__git_ps1 " (%s)")]\$ '