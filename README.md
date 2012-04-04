![SUSE LINUX Products GmbH](http://de.opensuse.org/images/thumb/d/d0/Icon-distribution.png/48px-Icon-distribution.png) subootstrap
==================================================================================================================================

------------------------


What is it?
-----------

subootstrap is a tool to create openSUSE filesystems on a host system by using [kiwi](http://opensuse.github.com/kiwi/). subootstrap contains a script which make the subfilesystem compatiple with [lxc](http://lxc.sourceforge.net/).


Version
-------

0.0.1(alpha)


How to use it
-------------

```bash
subootstrap 12.1-JeOS /path/where/you/want/to/store/the/filesystem [-h lxc] [-A x86_64]
```

-h activate one of the hook scripts 
return
-A set the architecture for the system


How to use it with lxc
----------------------

Go to lxc template directory (like /usr/lib64/lxc/templates) and change the content of lxc-opensuse to

```bash
#!/bin/bash

bash subootstrap $yourversion $yourpath -h lxc
```

Now open the Terminal login you in as root and then type in:
```bash
lxc-create -n yourname -t opensuse
```

License
-------

Copyright (C) 2012 SUSE LINUX Products GmbH.

subootstrap is licensed under the MIT license. See LICENSE for details.