@@@@@@@@@
OHMYREPOS
@@@@@@@@@

A collection of
`myrepos <https://myrepos.branchable.com/>`__
command extensions and actions.

#####
Setup
#####

Add a bunch of includes and appends to the top of your ``.mrconfig``,
like this::

  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/any-action-runtime"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/git-auto-commit"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/git-check-status"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/infuse-no-op"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/link-private-exclude"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/link-private-ignore"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/remote-add"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/sorted-commit"
  include = cat "${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/sync-travel-remote"

You could instead include them all at once, but then the files are concatenated
together, which makes it difficult to debug, because then lines number make
no sense, e.g.,::

  # include = cat ${OHMYREPOS_LIB:-${HOME}/.ohmyrepos/lib}/*

To take full advantage of all the features (discussed below),
wire the additional behavior, as well::

  [DEFAULT]
  # Use the _append feature to chain setup and teardown functions.
  # Also: The any-teardown comes last, so it runs last.
  setup_dispatch_append = git_any_cache_setup "${@}"
  setup_dispatch_append = git_status_cache_setup "${@}"
  setup_dispatch_append = git_travel_cache_setup "${@}"
  teardown_dispatch_append = git_travel_cache_teardown "${@}"
  teardown_dispatch_append = git_status_cache_teardown "${@}"
  teardown_dispatch_append = git_any_cache_teardown "${@}"

  [DEFAULT]
  autocommit = true

############
Dependencies
############

This project uses Bash functionality from my Bash dotfiles project,
`home-fries <https://github.com/landonb/home-fries>`__.

- Clone the repo to ``$HOME/.homefries``,
  or set the ``OHMYREPOS_LIB`` environment variable
  to the path to the ``home-fries/lib`` directory.

############################
Usage: ``.mrconfig`` Actions
############################

``infuse``
==========

Maybe I have a private script I like to run for some of the projects
I work on.

- Whenever I make changes to one of these scripts, or whenever
  I setup myrepos on a new machine, after ``mr checkout``, I run
  ``mr infuse`` and run my infuser scripts.

For example, suppose the script is named ``infuse-ohmyrepos.sh``,
then my ``mrconfig`` rule looks like this::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = ${HOME}/.mrinfuse/infuse-ohmyrepos.sh "${@}"

You can omit the ``"${@}"`` unless you want to pass arguments to your
infuser.

``link_private_exclude``
========================

Do you add files to your repo that you don't want to commit,
but there's already a ``.gitignore`` file committed?

- For instance, I might add a symlink from the root of a project
  to a private notes file. I don't need other developers to know
  that I like to do that.

I could just edit ``.git/info/exclude``, but I'd rather automate
the process, and I'd also like to have my private ``.gitignore``
managed in a separate repo.

Ohmyrepos includes a command, ``link_private_exclude``, that will
search up from the project root (``MR_REPO``), find your private
ignore file, and symlink it from ``.git/info/exclude``.

- The command will not clobber the existing ``exclude`` file
  if it's not already a symlink, and if it looks like you've
  edited it (if it deviates from the default file that ``git init``
  creates).

- The convention is that the file will be found in a ``.mrinfuse``
  directory in a parent directory, and within that directory is
  a path the mirrors the project path -- with the exception that
  files the are placed under ``.git`` will be located in a ``_git``
  directory under ``.mrinfuse``.

For instance, here's where you might find my private ignore file::

  $ cat /path/to/projects/.mrinfuse/ohmyrepos/_git/info/exclude
  Notes-no-one-needs-to-see.rst

And then here's how I've wired the ``.mrconfig`` rule::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = link_private_exclude

After running ``mr infuse``, the infuse action will be placed the
symlink, e.g.,::

  $ cd /path/to/projects/.mrinfuse/ohmyrepos
  $ readlink .git/info/exclude
  ../../../.mrinfuse/ohmyrepos/_git/info/exclude

``link_private_exclude_force``
==============================

To ``--force`` the symlink, use ``link_private_exclude_force``.

``link_private_ignore``
=======================

Likewise, if you've got a private ``.ignore`` file
(for ``rg``, ``ag``, ``grep``, etc.),
use the ``link_private_ignore`` command.

- Suppose that I checked out someone's project and built the code,
  but then I ran ripgrep, and the results included a ton of noise
  from the build directory.

  I could create my own ``.ignore`` file at the root of the project,
  but it's better to use a symlink to store the file elsewhere,
  because then I can keep my private file under revision control,
  and also I don't have to ask anyone upstream to pull a change just
  for an ignore file.

  - Also, if you work from multiple machines, you can easily
    setup this symlink on each machine with the ``infuse``
    command.

    If you switch machines frequently, say between a desktop
    machine and a laptop, and need to be able to work offline,
    if you only make small tweaks to project (like adding symlinks),
    having a infuser to apply those tweaks (and reapply them as
    necessary) is key.

As an example, here's a look at what's inside and where you might
find my private ignore file::

  $ cat /path/to/projects/.mrinfuse/ohmyrepos/.ignore
  build/

And then here's how I'd wire my ``.mrconfig`` rule::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = link_private_ignore

Now you can just run ``mr infuse`` to setup the symlink — or just for
this particular project, use the ``-d`` option, e.g.,::

  mr -d /path/to/projects/ohmyrepos infuse

Hint: If you have both a private ``exclude`` and a private ``ignore``,
you can list both commands, e.g.,::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse =
    link_private_exclude
    link_private_ignore

``link_private_ignore_force``
=============================

To ``--force`` the symlink, use ``link_private_ignore_force``.

``symlink_*`` Commands
======================

There are a number of additional commands for adding symlinks.

For symlinks to objects in the ``.mrinfuse`` directory, use
``symlink_mrinfuse_file`` and ``symlink_mrinfuse_dir``.

These commands are basically more general versions of the
previous two commands.

For arbitrary symlinks that can be created anywhere and can link
to wherever, look to ``symlink_overlay_file`` and ``symlink_overlay_dir``.

``symlink_mrinfuse_file``
=========================

An easy way to illustrate using ``symlink_mrinfuse_file`` is showing
how it's just a more general version of the ``link_private_exclude``
and ``link_private_ignore`` commands.

For instance, you could place the private ignore file this way instead::

  $ ls /path/to/projects/.mrinfuse/ohmyrepos
  .ignore

And in ``.mrconfig``::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = symlink_mrinfuse_file ".ignore"

If you want to use a different name for the target file, pass it as a parameter.

E.g., suppose I had a slightly different ``.ignore`` on different machines.
I could create host-specific files, and then I could key off that name, e.g.,::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = symlink_mrinfuse_file ".ignore-$(hostname)" ".ignore"

Note that ``symlink_mrinfuse_file`` fails if the source file is missing.

``symlink_mrinfuse_file_optional``
==================================

Like ``symlink_mrinfuse_file``, but does not care if the source file is absent.

``symlink_mrinfuse_dir``
========================

The ``symlink_mrinfuse_dir`` command works similarly to
the ``symlink_mrinfuse_file`` command, but for directories.

There is currently no optional variant of this command.

``symlink_mrinfuse_file_first``
===============================

If you'd like to symlink to a specific file is it's available,
but to fall back to another file(s) otherwise, use
``symlink_mrinfuse_file_first``.

E.g., consider the machine-specific ``.ignore`` example, suppose
that I didn't always bother to create a file for each host. I
could instead fallback to symlink a default file. E.g.,::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse =
    symlink_mrinfuse_file_first ".ignore-$(hostname)" ".ignore" ".ignore"

Note that ``.ignore`` is specified twice, as the last two parameters,
because the final one is the target file name, which must be specified.

``symlink_mrinfuse_file_first_optional``
========================================

Use the optional variant of the first-file command if it's okay that
none of the source files exist.

``symlink_overlay_file``
========================

To create a symlink to any file (i.e., to a file *not* under a parent-level
``.mrinfuse/`` directory), use ``symlink_overlay_file``.

You can use either relative paths or absolute paths, considering that the
symlink command (``/bin/ls``) runs in the context of the project directory
(aka ``$MR_REPO``).

For example, let's symlink a private notes file in my project working tree::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse = symlink_overlay_file "/path/to/notes/OhMyRepos.rst"

This will create a symlink titled "OhMyRepos.rst" in my project root.

I could alternatively specify an alternative target destination, e.g.,::

  [/path/to/projects/ohmyrepos]
  checkout = git clone 'git@github.com:landonb/ohmyrepos.git' 'ohmyrepos'
  infuse =
    symlink_overlay_file "/path/to/notes/backlog/OhMyRepos.rst" "docs/Private-Notes.rst"

``symlink_overlay_dir``
=======================

The ``symlink_overlay_dir`` command works similarly to
the ``symlink_overlay_file`` command, but for directories.

``symlink_overlay_file_first``
==============================

The ``symlink_overlay_file_first`` command works similarly to
the ``symlink_mrinfuse_file_first`` command, but for using source
paths relative to the project's root (i.e., related to ``$MR_REOP``,
and not relative to ``.mrinfuse``).

``symlink_overlay_file_first_optional``
=======================================

Use ``symlink_overlay_file_first_optional`` as you would
``symlink_overlay_file_first`` but do not care if the source
file is present or not.

``mr infuse`` options
=====================

Each of the symlink calls can be passed the CLI args (``${@}``)
which allow you to specify some options from the command line.

E.g.,::

  $ mr infuse [-f/--force] [-s/--safe]

Use ``--force`` to always overwrite symlinks.

Use ``--safe`` to move existing files to a different file name,
to allow a symlink to be created at the old name (and to not clobber
the existing file).

The options are setup automatically via ``.mrconfig``, but if you
want to use these symlinks from within your own scripts, you can
call the argument parser directly, e.g., from within a shell script
of yours, call::

  infuser_prepare "/path/to/projects/ohmyrepos" "${@}"

``autocommit``: ``git_auto_commit_one``
=======================================

Do you have certain (private) files or (private) repos that you maintain,
but for which you don't particularly need meaningful commit messages?

For instance, I have a repo to manage my (private) notes, but I feel
it's a waste of time have to ``git add`` and then ``git commit -m``
all the time. So let's automate it!

In this example, I also show how I setup a private repository that's
not hosted online anywhere.

- I use an environment variable, ``OMR_TRAVEL``, to pass a local path
  to another copy of the repo -- this could be a path to an encrypted
  filesystem on a USB thumb drive, or it could be an ``ssh://`` URL to
  one of my other development machines.

This example shows how I might wire my notes repo to automate add and
commit my notes file when it changes::

  [/path/to/notes]
  checkout = [ -z ${OMR_TRAVEL} ] && fatal 'You must set OMR_TRAVEL' ||
    git clone "${OMR_TRAVEL}/path/to/notes" 'notes'
  autocommit =
    git_auto_commit_parse_args "${@}"
    # Auto-commit private Ohmyrepos notes.
    git_auto_commit_one 'backlog/OhMyRepos.rst'

``autocommit``: ``git_auto_commit_parse_args``
==============================================

Note the call to ``git_auto_commit_parse_args`` in the previous example,
which lets you specify command line options, e.g.,::

  $ mr autocommit [-y/--yes]

Use ``--yes`` to tell autocommit to actually auto-commit changes it finds,
otherwise it'll actually prompt you for approval first (how nice of it!).

``autocommit``: ``git_auto_commit_all``
=======================================

I could instead auto-commit all changes to a repo using ``git_auto_commit_all``.

Suppose I have two notes file (or however many), e.g.,::

  $ ls /path/to/notes/backlog
  OhMyRepos.rst DubsVim.rst

Then I could have them all committed automatically thuslyy::

  [/path/to/notes]
  checkout = [ -z ${OMR_TRAVEL} ] && fatal 'You must set OMR_TRAVEL' ||
    git clone "${OMR_TRAVEL}/path/to/notes" 'notes'
  autocommit = git_auto_commit_all "${@}"

``autocommit``: ``git_auto_commit_new``
=======================================

If you really don't care to audit your commits, you can sweep up new
(untracked) files on auto-commit, too.

Generally, if you want to auto-commit new files, you probably also want
to auto-commit changes to existing files, so oftentimes the two options
are combined, e.g.,::

  [/path/to/notes]
  checkout = [ -z ${OMR_TRAVEL} ] && fatal 'You must set OMR_TRAVEL' ||
    git clone "${OMR_TRAVEL}/path/to/notes" 'notes'
  autocommit = git_auto_commit_all "${@}" && git_auto_commit_new "${@}"

``autocommit``: Ignore Most Projects
====================================

Because most projects probably will not have auto-commit files,
you'll want to add a dummy, no-op action to the ``.mrconfig``,
so that the ``mr autocommit`` command happily skips projects
that don't use it.

As shown earlier, add this to your ``.mrconfig``::

  [DEFAULT]
  autocommit = true

``sort_file_then_commit``
=========================

I use ``sort_file_then_commit`` to sort my Vim spell file, so I can diff it
sensibly.

Because I publish my Vim project (at ``~/.vim``) publicly, I keep the copy
of my spell file in a private repo and symlink it.

Suppose that the spell file is under ``~/.dotfiles/home/.vim/spell``.
Here's how the ``.mrconfig`` might look::

  [${HOME}/.dotfiles]
  checkout = [ -z ${OMR_TRAVEL} ] && fatal 'You must set OMR_TRAVEL' ||
    git clone "${OMR_TRAVEL}/${MR_HOME:-${HOME}}/.dotfiles" '.dotfiles'
    autocommit =
      # Sort the spell file, for easy diff'ing, or merging/meld'ing.
      # - The .vimrc startup file will remake the .spl file when you restart Vim.
      sort_file_then_commit 'home/.vim/spell/en.utf-8.add'

If I also symlink the ``.dotfiles/home`` directory to ``~/.mrinfuse``,
e.g.,::

  $ cd $HOME
  $ /bin/ln -s .dotfiles/home .mrinfuse

then I can easily wire my Vim rule to overlay the spell file symlink.
Here's what the Vim project rule might look like (and look, it clones
my awesome Vim project, Dubs Vim!)::

  [${HOME}/.vim]
  checkout = git clone 'git@github.com:landonb/dubs-vim.git' '.vim'
  infuse = symlink_mrinfuse_file 'spell/en.utf-8.add'

``any-action-runtime``
======================

The ``any-action-runtime`` command is used to print elapsed time for
the action called, at the end of all the output.

This behavior is wired using ``myrepos``' ``_append`` hooks, e.g.,::

  [DEFAULT]
  setup_dispatch_append = git_any_cache_setup "${@}"
  ...
  teardown_dispatch_append = git_any_cache_teardown "${@}"

``remote_add``
==============

If you want to wire more git-remote URLs to a project, use ``remote_add``.

For instance, I like to use a remote named 'upstream' to store the URL
of the original project for any project that I've forked.

I also call the command ``wireupstream``, so I can then call
``mr -d /path/to/project wireupstream``.

Here's an example that shows how I've got the ``myrepos`` remotes wired,
one to my fork (what git sets to 'origin' by default), and another remote
I wire to the upstream ``myrepos`` project::

  [/path/to/projects/myrepos]
  checkout = git clone 'git@github.com:landonb/myrepos.git' 'myrepos'
  wireupstream = remote_add upstream 'git://myrepos.branchable.com/'

################################
Usage: ``mr`` Command Extensions
################################

``mystatus``
============

Call ``mr mystatus`` to see a colorful, concise ``mr status``-like output,
one line per project indicating it's status.

This command prints the list of repos with changes at the end of its
out, as a copy-and-paste-worthy block of text.

E.g., (and imagine this printed in color)::

  $ mr -d / mystatus
  [DBUG] 2020-02-12 @ 13:23:55   unchanged   /home/user
  [DBUG] 2020-02-12 @ 13:23:55   untracked   /home/user/.dotfiles  ✗
  [DBUG] 2020-02-12 @ 13:23:55   unchanged   /home/user/.vim
  [DBUG] 2020-02-12 @ 13:23:55   unchanged   /path/to/notes
  [DBUG] 2020-02-12 @ 13:23:56    unstaged   /path/to/projects/ohmyrepos  ✗
  [WARN] 2020-02-12 @ 13:23:56 GRIZZLY! We found 2 repos which need attention.
  [NOTC] 2020-02-12 @ 13:23:56
  [NOTC] 2020-02-12 @ 13:23:56 Here's some copy-pasta if you wanna fix it:

    cd /home/user/.dotfiles && git status
    cd /path/to/projects/ohmyrepos && git status

  [INFO] 2020-02-12 @ 13:23:56
  [INFO] 2020-02-12 @ 13:23:56 Elapsed: 01.23 secs.
  [INFO] 2020-02-12 @ 13:23:56
  mr mystatus: finished (3 ok; 2 failed; 0 skipped)

``sync-travel-remote``: ``ffssh``, ``travel``, and ``unpack``
=============================================================

Ohmyrepos offers methods to manage remotes across *mirrored* devices,
be they an offline storage device (such as a USB thumb drive)
or another machine (that you can reach via ``ssh``).

- Mirrored, as in, you have the same set of repositories on each
  device, and they can be found at the same (final) path.

  I.e., the root path components will differ, because the paths
  lead to different devices, but the paths will be the same after
  that. E.g., I might have a repo accessible at the same relative
  path locally and on a USB and ssh remote, which might look like
  this::

    /path/to/projects/ohmyrepos

    /media/user/usb_device/path/to/projects/ohmyrepos

    ssh://my_other_machine/path/to/projects/ohmyrepos

- For local-path mirrors, the repos are managed bare, so that files
  are not unnecessarily duplicated. (E.g., the local path might be
  to an encrypted filesystem that you mount off a thumb drive that
  you carry around as a backup device.) You can then either ff-merge
  your local repos into the mirror, or you can ff-merge the mirror
  repos into your local repos, thereby making it easy for you to
  switch between development machines.

- For ssh mirrors, you can ff-merge the mirrored repos into your
  local repos. (The ssh paths are simply added as remotes to each
  of your local repos, then fetched, and then a --ff-only merge is
  attempted, but only in the local repository is tidy (nothing
  unstaged, uncommitted, nor untracked).)

``travel`` and ``unpack``
=========================

To shuffle your managed repositories to and from a travel device,
such as a USB thumb drive, set the ``MR_TRAVEL`` environment and
call the ``travel`` command.

For instance, suppose I mounted a device to ``/media/user/usb_device``,
then I'd simply call::

  MR_TRAVEL=/media/user/usb_device mr -d / -j 2 travel

If I then "travel" to another machine and want to update all the
repos of that machine to the more recent versions on the USB drive,
run the ``unpack`` command similarly, e.g.,::

  MR_TRAVEL=/media/user/usb_device mr -d / -j 2 unpack

What's the point of this exercise if everything's on the cloud
these days? Well, if you're like me, not everything *is* on the
cloud -- I still manage a lot of private data on my own networks,
refusing to let it touch someone else's metal.

Note that the repos on the travel device are managed as ``--bare``
repositories, so really your local project branches and commits
are just pulled into the bare repo on ``travel``. And then on
``unpack``, whatever branch was last active is checked out, and
an ff-merge is attempted against the local working tree.

``ffssh``
=========

Really, the easiest way to keep two or more machines' git repos
mirrored and up to date with one another is using the extremely
convenient ``ffssh`` command.

Suppose I have two machine, ``@fry`` and ``@leela``, and that I've
been working of ``@fry`` for a while, so it's got the latest versions
of all my work. But now I want to switch to ``@leela``, so I log on
to ``@leela`` and run the ``ffssh`` command.

- First, the remote will be fetched for each project, e.g.,
  ``git fetch <host>`` will be called, so at least the machine
  to which you've switched will have the latest work available
  to it (should you need to sever the network connection now,
  or whatever).

- Next, the tool will switch to the branch that is active on
  the remote machine, and it will attempt a ``git merge --ff-only``.

  If the branch cannot be fast-forwarded, the URL path will be
  included in a list of repos that could not be updated that is
  printed at the end of the operation.

  (This behavior encourages you not to rewrite history, even on your
  own private feature branches, if you plan to keep machines easily
  synced. But it's easy to workaround this -- if you know you need
  to switch machines but also know you're in the middle of rebasing
  a branch you have on both machines, you might just want to create
  a new branch (unique to both machines) and then the operation will
  just switch to that new branch, no ff-merge necessary, and no
  complaints.)

The command simply requires the name of the remote host.
But we'll also throw in the ``-j`` option and run it on two CPUs.
Here's how we'd pull changes from ``@fry`` into projects on ``@leela``::

  @leele $ MR_REMOTE=fry mr -d / -j 2 ffssh

To make this even easier, you could wire a unique alias for each
machine, and then you never have to specify the ``MR_REMOTE``.

I have it wired so I just type ``ff`` on a machine and it knows
what to do.

For instance, from your ``.bashrc``, you could have::

  wire_ff_alias () {
    case $(hostname) in
      fry)
        MR_REMOTE=leela
        ;;
      leela
        MR_REMOTE=fry
        ;;
      *)
        >&2 echo -e "Unrecognized host: $(hostname)"
        ;;
    esac

    alias ff="MR_REMOTE=${MR_REMOTE} mr -d / -j 2 ffssh"
  }
  wire_ff_alias

###################################
Other ``.mrconfig`` settings I like
###################################

I've currently got upwards of 300 repos that I manage with ``myrepos``,
so I tweaked the ``mr`` output to make it prettier, to be more concise
(unlike this readme), and to make it easier to glance and glean
information from the output.

Here's a look at how I've set the ``no_print`` options to tweak output::

  [DEFAULT]
  # For all actions/any action, do not print line separator/blank line
  # between repo actions.
  no_print_sep = true
  # For mystatus action, do not print action or directory header line.
  no_print_action_mystatus = true
  no_print_dir_mystatus = true
  # For mystatus action, do not print if repo fails (action will do it).
  no_print_failed_mystatus = true
  #
  no_print_action_ffssh = true
  no_print_dir_ffssh = true
  no_print_failed_ffssh = true
  #
  no_print_action_travel = true
  no_print_dir_travel = true
  no_print_failed_travel = true
  #
  no_print_action_unpack = true
  no_print_dir_unpack = true
  no_print_failed_unpack = true
  #
  # Along with [DEFAULT]autocommit = true, nicer (lot less) output.
  no_print_action_autocommit = true
  no_print_dir_autocommit = true
  no_print_failed_autocommit = true

Enjoy!
======

Seriously, if you've made it this far, congrats!

I hope you find ``myrepos`` and ``ohmyrepos`` useful -- I sure do!!

