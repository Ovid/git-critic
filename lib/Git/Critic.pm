package Git::Critic;

# ABSTRACT: Only run Perl::Critic on lines changed in the current branch
use v5.10.0;
use strict;
use warnings;
use autodie ":all";

use Capture::Tiny 'capture_stdout';
use Carp;
use File::Basename 'basename';
use List::Util qw(uniq);
use Moo;
use Types::Standard qw( ArrayRef Bool Int Str);

our $VERSION = '0.3';

#
# Moo attributes
#

has primary_branch => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has current_branch => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_current_branch',
);

has max_file_size => (
    is      => 'ro',
    isa     => Int,
    default => 0,
);

has severity => (
    is      => 'ro',
    isa     => Int | Str,
    default => 5,
);

has verbose => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

# this is only for tests
has _run_test_queue => (
    is       => 'ro',
    isa      => ArrayRef,
    default  => sub { [] },
    init_arg => undef,
);

#
# Builders
#

sub _build_current_branch {
    my $self = shift;
    return $self->_run( 'git', 'rev-parse', '--abbrev-ref', 'HEAD' );
}

#
# The following methods are for the tests
#

# return true if we have any data in our test queue
sub _run_queue_active {
    my $self = shift;
    return scalar @{ $self->_run_test_queue };
}

sub _add_to_run_queue {
    my ( $self, $result ) = @_;
    push @{ $self->_run_test_queue } => $result;
}

sub _get_next_run_queue_response {
    my $self = shift;
    shift @{ $self->_run_test_queue };
}

#
# These call system commands
#

# if we have a response added to the run queue via _add_to_run_queue, return
# that instead of calling the system command. Let it die if the system command
# fails

sub _run {
    my ( $self, @command ) = @_;
    if ( $self->_run_queue_active ) {
        return $self->_get_next_run_queue_response;
    }

    if ( $self->verbose ) {
        say STDERR "Running command: @command";
    }

    # XXX yeah, this needs to be more robust
    chomp( my $result = capture_stdout { system(@command) } );
    warn $result;
    return $result;
}

# same as _run, but don't let it die
sub _run_without_die {
    my ( $self, @command ) = @_;
    if ( $self->verbose ) {
        say STDERR "Running command: @command";
    }
    chomp(
        my $result = capture_stdout {
            no autodie;
            system(@command);
        }
    );
    return $result;
}

# get Perl files which have been changed in the current branch
sub _get_modified_perl_files {
    my $self           = shift;
    my $primary_branch = $self->primary_branch;
    my $current_branch = $self->current_branch;
    my @files          = uniq sort grep { /\S/ && $self->_is_perl($_) }
      split /\n/ => $self->_run( 'git', 'diff', '--name-only',
        "$primary_branch..$current_branch" );
    return @files;
}

# get the diff of the current file
sub _get_diff {
    my ( $self, $file ) = @_;
    my $primary_branch = $self->primary_branch;
    my $current_branch = $self->current_branch;
    my @diff =
      split /\n/ =>
      $self->_run( 'git', 'diff', "$primary_branch..$current_branch", $file );
    return @diff;
}

# remove undefined arguments. This makes a command line
# script easier to follow
around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;

    my $arg_for = $class->$orig(@args);
    foreach my $arg ( keys %$arg_for ) {
        if ( not defined $arg_for->{$arg} ) {
            delete $arg_for->{$arg};
        }
    }
    return $arg_for;
};

sub run {
    my $self = shift;

    my $primary_branch = $self->primary_branch;
    my $current_branch = $self->current_branch;
    if ( $primary_branch eq $current_branch ) {

        # in the future, we might want to allow you to check the primary
        # branch X commits back
        return;
    }

    # We walking through every file you've changed and parse the diff to
    # figure out the start and end of every change you've made. Any perlcritic
    # failures which are *not* on those lines are ignored
    my @files = $self->_get_modified_perl_files;
    my $found;
    my %reported;
    my @failures;
  FILE: foreach my $file (@files) {
        next FILE unless -e $file;    # it was deleted
        if ( $self->max_file_size ) {
            next FILE
              unless -s _ <= $self->max_file_size;    # large files are very slow
        }
        my $severity = $self->severity;
        my $critique =
          $self->_run_without_die( 'perlcritic', "--severity=$severity",
            $file );
        next FILE unless $critique; # should never happen unless perlcritic dies
        my @critiques = split /\n/, $critique;

        # @@ -3,8 +3,9 @@        @@ -3,8 +3,9 @@
        my @chunks = map {
            /^ \@\@\s+ -\d+,\d+\s+
                    \+(?<start>\d+)
                    ,(?<lines>\d+)
               \s+\@\@/xs
              ? [ $+{start}, $+{start} + $+{lines} ]
              : ()
        } $self->_get_diff($file);
      CRITIQUE: foreach my $this_critique (@critiques) {
            next CRITIQUE if $this_critique =~ / source OK$/;
            $this_critique =~ /\bline\s+(?<line_number>\d+)/;
            unless ( defined $+{line_number} ) {
                warn "Could not find line number in critique $critique";
                next;
            }
            foreach my $chunk (@chunks) {
                my ( $min, $max ) = @$chunk;
                if ( $+{line_number} >= $min && $+{line_number} <= $max ) {
                    push @failures => "$file: $critique"
                      unless $reported{$critique}++;
                    next CRITIQUE;
                }
            }
        }
    }
    return @failures;
}

# a heuristic to determine if the file in question is Perl. We might allow
# a client to override this in the future
sub _is_perl {
    my ( $self, $file ) = @_;
    return unless -e $file;    # sometimes we get non-existent files
    return 1 if $file =~ /\.(?:p[ml]|t)$/;

    # if we got to here, let's check to see if "perl" is in a shebang
    open my $fh, '<', $file;
    my $first_line = <$fh>;
    close $fh;
    if ( $first_line =~ /^#!.*\bperl\b/ ) {
        say STDERR "Found changed Perl file: $file" if $self->verbose;
        return $file;
    }
    return;
}

# vim: filetype=perl

1;

__END__

=head1 SYNOPSIS

    my $critic = Git::Critic->new( primary_branch => 'main' );
    my @critiques = $critic->run;
    say foreach @critiques;

=head1 DESCRIPTION

Running L<Perl::Critic|https://metacpan.org/pod/Perl::Critic> on legacy code
is often useless. You're flooded with tons of critiques, even if you use the
gentlest critique level. This module lets you only report C<Perl::Critic>
errors on lines you've changed in your current branch.

=head1 COMMAND LINE

We include a C<git-perl-critic> command line tool to make this easier. You
probably want to check those docs instead.

=head1 CONSTRUCTOR ARGUMENTS

=head2 C<primary_branch>

This is the only required argument.

This is the name of the branch you will diff against. Usually it's C<main>,
C<master>, C<development>, and so on, but you may specify another branch name
if you prefer.

=head2 C<current_branch>

Optional.

This is the branch you wish to critique. Defaults to the currently checked out branch.

=head2 C<max_file_size>

Optional.

Positive integer representing the max file size of file you wish to critique.
C<Perl::Critic> can be slow on large files, so this can speed things up by
passing a value, but at the cost of ignoring some C<Perl::Critic> failures.

=head2 C<severity>

Optional.

This is the C<Perl::Critic> severity level. You may pass a string or an integer. If omitted, the
default severity level is "gentle" (5).

    SEVERITY NAME   ...is equivalent to...   SEVERITY NUMBER
    --------------------------------------------------------
    -severity => 'gentle'                     -severity => 5
    -severity => 'stern'                      -severity => 4
    -severity => 'harsh'                      -severity => 3
    -severity => 'cruel'                      -severity => 2
    -severity => 'brutal'                     -severity => 1

=head2 C<verbose>

Optional.

If passed a true value, will print messages to C<STDERR> explaining various things the
module is doing. Useful for debugging.

=head1 METHODS

=head2 C<run>

    my $critic = Git::Critic->new(
        primary_branch => 'main' 
        current_branch => 'my-development-branch',
        severity       => 'harsh',
        max_file_size  => 20_000,
    );
    my @critiques = $critic->run;
    say foreach @critiques;

Returns a list of all C<Perl::Critic> failures in changed lines in the current branch.

If the current branch and the primary branch are the same, returns nothing.
This may change in the future.
