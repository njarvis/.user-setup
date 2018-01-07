# Server Setup

## Make sudo passwordless

```
$ sudo visudo
# change lines to include NOPASSWD:

  # Allow members of group sudo to execute any command
  %sudo	ALL=(ALL:ALL) NOPASSWD: ALL
```

## Useful packages

```
sudo apt emacs24-nox mosh
```

# TO DO

* network setup
  * bind
  * dhcp static
  * smokeping
  * mrtg
  
