# NAME

Git::Critic - Only run Perl::Critic on lines changed in the current branch

# VERSION

version 0.1

# SYNOPSIS

```perl
my $critic = Git::Critic->new( primary_branch => 'main' );
my @critiques = $critic->run;
say foreach @critiques;
```

# DESCRIPTION

Running [Perl::Critic](https://metacpan.org/pod/Perl::Critic) on legacy code
is often useless. You're flooded with tons of critiques, even if you use the
gentlest critique level. This module lets you only report Perl::Critic errors
on lines you've changed in your current branch.

# AUTHOR

Curtis "Ovid" Poe <curtis.poe@gmail.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Curtis "Ovid" Poe.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```
