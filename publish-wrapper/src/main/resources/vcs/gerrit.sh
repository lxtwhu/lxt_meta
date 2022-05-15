#!/usr/bin/sh

CUR_DIR=$(cd "$(dirname "$0")"&& pwd)

VCS_DIR=$CUR_DIR
INITIATOR_DIR=$(cd "$CUR_DIR/.."&& pwd)
ROOT_DIR=$(cd "$INITIATOR_DIR/../../../.."&& pwd)

. "$INITIATOR_DIR/common/utils.sh"
#. "$ROOT_DIR/build/node.cfg"

