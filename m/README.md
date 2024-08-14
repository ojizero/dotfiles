# m

>  Miniaturized Swiss Army Knife for macOS.

This CLI offers a much more limited clone for [m-cli](https://github.com/rgcr/m-cli)
targetted for my own specific needs and usage.

## Why?

This module was added since m-cli is looking for maintainers and hasn't been updated
in Homebrew in quite a while and is just a precaution in case the project dies.

### Why not contribute?

Simply not enough time, and my needs a much more narrow than even what m-cli offers.

## Available Commands

### `update`

> Aliases: `up` and `upgrade`.

Manages updating system, with support for Homebrew packages.

```

    usage: m update [ list | install | all [--with-brew] | brew | help ]


    Examples:
      m help                                                        # prints this help message
      m update list                                                 # list available updates
      m update all [--with-brew]                                    # install all the available updates
                                                                    # includes home brew if --with-brew is passed
      m update install iTunesX-12.4.1 RAWCameraUpdate6.20-6.20      # install specific updates
      m update brew                                                 # install all the available updates from Homebrew

```

### `dns`

Manage the system DNS.

```

    usage:  m dns [ list | add | flush | help ]

    Examples:
      m dns list                    # lists DNS servers
      m dns add [IP/Hostname]       # adds DNS server
      m dns flush                   # flushes local DNS

```

### `localhost`

Manage the system `/etc/hosts` file.

```
    usage: m localhost [ help ]

    Examples:
      m localhost ls                              # list current records in localhost
      m localhost add 127.0.0.1 webpage.local     # add a new host to the localhost file
      m localhost remove webpage.local            # remove a host from the localhost file

```
