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

# AUTHOR

Curtis "Ovid" Poe <curtis.poe@gmail.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Curtis "Ovid" Poe.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```
