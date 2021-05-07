#
# MTS web command (copied from go/matt, with <user> removed from help output)
#
a4-mts() {
    baseUrl=http://go/mts
    self=${FUNCNAME[0]}
    action=${1:-help}
    shift
    req=${baseUrl}/${action}
    case "$action" in
        mutName)
            req=${req}$(printf '/%s' "$@")
            ;;
        help)
            ;;
        *)
            req=${req}/${USER}$(printf '/%s' "$@")
            ;;
    esac

    echo "GET $req"
    echo "---"
    curl -sSL $req |
        sed -r 's/go\/mts\//'$self' /g;s/\// /;s/\// /;s/(&lt;)/</g;s/&gt;/>/g;s/ <user>//g'
    echo
}

alias a4-matt='a4-mts "$@"'

#
# Useful a4c container commands
#

alias a4c-nicknames='a4c ps | tail -n +2 | awk '\''{printf "%s ", $2}'\'''

join_by ()
{
    local IFS="$1";
    shift;
    echo "$*"
}

a4c-restart-all-shells ()
{
    pdsh -w $(join_by , $(a4c-nicknames)) -R exec a4c shell --restart %h -q a4-whatami -l | dshbak
}

a4c-shell-all ()
{
    pdsh -w $(join_by , $(a4c-nicknames)) -R exec a4c shell %h -q "$@" | dshbak
}

#
# Other stuff
#
a4-take-note() {
    if [[ -z "$@" ]]; then
        $EDITOR /project/NOTE
    else
        if [[ "$1" == "-d" ]]; then
            rm -f /project/NOTE
        else
            echo "$@" > /project/NOTE
        fi
    fi
    if [[ ! -z "$WP" && -e "$HOME/bin/a4-whatami" ]]; then
        $HOME/bin/a4-whatami --badges
    fi
}

# Show how to join current tmux session
alias join-tmux="echo \"a ssh -t `hostname` '`which tmux` attach -t `tmux display-message -p '#S'`'\""

# Arista pasteboard (http://pb)
alias pb='curl -F c=@- pb'

alias a4c-images-cleanup='docker rmi $(disknanny report -u $USER | grep unused\ image | egrep -o "$USER\.\S*")'

emacs-url() {
    if [[ -z "$@" ]]; then
        emacs
    else
        CMD="emacs --debug-init -Q --eval '(url-handler-mode 1)'"
        for f in "$@"; do
           CMD="$CMD --eval '(find-file \"${f}\")'"
        done
        bash -c "$CMD"
    fi
}
