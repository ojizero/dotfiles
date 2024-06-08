# DevOps plugin

> This plugin provides some helpful "DevOps" related aliases and functions. Accumulated from my time working on infrastructure stuff.

## Aliases

| Alias                 | Command                                                                           |
| :-------------------- | :-------------------------------------------------------------------------------- |
| `k`                   | `kubectl`                                                                         |
| `tf`                  | `terraform`                                                                       |
| `nsenter`             | `docker run -it --rm --privileged --pid=host justincormack/nsenter1`              |
| `dockerdive`          | `docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive` |
| `dockerclean`         | `docker rmi --force $(docker images -q)`                                          |
| `dockerremovedangles` | `docker rmi --force $(docker images -f "dangling=true" -q)`                       |
| `ktail`               | `kubetail`, see [functions](#functions)                                           |

## Functions

| Function                                                                                | Behaviour                                                                                                               |
| :-------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------- |
| `kubetail <selectors> <container> [...args]`                                            | Run `kubectl logs` with for a give container from a given selectors. Other options are passed to the `kubectl` command. |
| `local-forward <local-connection> <remote-connection> <...ssh-required-args> [...args]` | Forwards a given local port to connect, via SSH, to a remote connection, via some SSH host.                             |
| `listening [grep-matching-pattern]`                                                     | Return a list of ports with servers listening on them.                                                                  |
