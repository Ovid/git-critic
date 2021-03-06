# NAME

git-perl-critic - Command-line interface for Perl Git::Critic module

# VERSION

version 0.7

# SYNOPSIS

```
git-perl-critic main
```

# DESCRIPTION

This is a command line interface to `Git::Critic`.  We only report
[Perl::Critic](https://metacpan.org/pod/Perl::Critic) failures on lines
changed.

Note that this means you're diffing two branches. The branch you're diffing
_against_ is usually your company's primary branch. Typical names are
`main`, `master`, `dev`, and so on. However, you can pick any branch to be the
primary branch you're diffing against.

So, if your primary branch is `main`, you should `cd` into your repository
and run:

```
git-perl-critic main
```

If you prefer a more "fluent" interface:

```
git-perl-critic --against main
```

If your git repository is currently not checked out into the branch you wish to diff,
pass the `--critique` option to specify the name of the branch you wish to critique.

```perl
git-perl-critic main --critique my-development-branch
```

But maybe you have created a branch off of `my-development-branch`:

```perl
git checkout my-development-branch
git checkout -b my-spike-branch
# hack, hack, hack
git-perl-critique my-development-branch
```

To be fully verbose:

```perl
git-perl-critic --critique my-spike-branch --against my-development-branch
```

If you prefer, you can target particular commits:

```
git-perl-critic --critique 747ba0e --against 15616b5
```

Or mix them:

```
git-perl-critic --critique 747ba0e --against main
```

If you're on an entirely unrelated branch, you can specify the branch you want
to use as your primary branch and the branch you want to critique:

```perl
git-perl-critic my-development-branch --critique my-spike-branch # same thing
git-perl-critic --against my-development-branch --critique my-spike-branch # same thing
```

## Option Explanations

All options are optional.

### `--against $branch_name`

The name of the branch you will critique against. If you don't pass this argument, you
must pass the branch name directly. The following two are equivalent:

```
git-perl-critic --against main
git-perl-critic main
```

### `--critique $branch_name`

This must be the name of the branch you wish to critique.

### `--severity $number_or_name`

This is the `Perl::Critic` severity level. You may pass a string or an integer. If omitted, the
default severity level is "gentle" (5).

```perl
SEVERITY NAME   ...is equivalent to...   SEVERITY NUMBER
--------------------------------------------------------
-severity => 'gentle'                     -severity => 5
-severity => 'stern'                      -severity => 4
-severity => 'harsh'                      -severity => 3
-severity => 'cruel'                      -severity => 2
-severity => 'brutal'                     -severity => 1
```

### `--max_file_size $bytes`

`Perl::Critic` can be very, very slow on large files. Pass a positive integer
to this option to skip files over a certain number of bytes.

### `--verbose`

This is a debugging tool to show some useful information while running this script.

### `--man,--help`

Various ways of displaying this documentation.

# OPTIONS

Options:

```
Option           Argument type   Description
--against,a      Str             Git branch to critique against
--critique,-c    Str             Git branch to critique (default is current branch)
--severity,s     Str|Int         Perl::Critic severity level
--max_file_size  Bytes           Maximum file size in bytes to check
--profile        Filename        Optional Perl::Critic configuration file
```

Debugging options:

```
--help,-h,-?                   Show brief help
--man                          Show full help
--verbose                      Show internal Git::Critic commands
```

# SEE ALSO

[https://metacpan.org/pod/Test::Perl::Critic::Progressive](https://metacpan.org/pod/Test::Perl::Critic::Progressive)

# SPONSOR

This work is sponsored by [All Around the World](https://allaroundtheworld.fr).
Contact them if you need expert help in software development. We work with many
different languages. Not just Perl.

# AUTHOR

Curtis "Ovid" Poe <curtis.poe@gmail.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Curtis "Ovid" Poe.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```
