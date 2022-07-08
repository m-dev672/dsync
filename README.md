# dsync

A rsync like differential file sync script written in Lua.

The script only detects "local" side's updates, and detection and uploading are based on a per file, not on a per chunk.

It's suitable for limited linux like system which can use lua, like a-shell.

## Installation

```:bash
apt install lua
```

```:bash
curl -Lo /usr/local/bin/dsync.lua https://raw.githubusercontent.com/m-dev672/dsync/main/dsync.lua
```

## Usage

```:bash
dsync "-i $ID_FILE -p $PORT" $LOCAL_DIR $USER@$HOST:$REMOTE_DIR
```
