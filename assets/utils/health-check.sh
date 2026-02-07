#!/bin/sh

check_api(){
    DURATION=$(</dev/stdin)
    if (($DURATION <= 5000 )); then
        exit 60
    else
        curl --silent --fail "mempool-rdts.embassy:8999/api/v1/difficulty-adjustment" &>/dev/null
        RES=$?
        if test "$RES" != 0; then
            echo "Mempool BIP-110 API is unreachable" >&2
            exit 1
        fi
    fi
}

check_web(){
    DURATION=$(</dev/stdin)
    if (($DURATION <= 5000 )); then
        exit 60
    else
        curl --silent --fail mempool-rdts.embassy:8080 &>/dev/null
        RES=$?
        if test "$RES" != 0; then
            echo "The Mempool BIP-110 UI is unreachable" >&2
            exit 1
        fi
    fi
}


case "$1" in
	api)
        check_api
        ;;
	web)
        check_web
        ;;
    *)
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "         api"
        echo "         web"
esac