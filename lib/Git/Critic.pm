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
use Types::Standard qw( ArrayRef Int Str);

our $VERSION = '0.1';

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
    default => 20_000,
);

has severity => (
    is      => 'ro',
    isa     => Int | Str,
    default => 5,
);

has verbose => (
    is      => 'ro',
    isa     => Int,
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
    return capture_stdout { system(@command) };
}

# same as _run, but don't let it die
sub _run_without_die {
    my ( $self, @command ) = @_;
    if ( $self->verbose ) {
        say STDERR "Running command: @command";
    }
    return capture_stdout {
        no autodie;
        system(@command);
    };
}

# get
sub _get_modified_perl_files {
    my $self           = shift;
    my $primary_branch = $self->primary_branch;
    my @files          = uniq sort grep { /\S/ && $self->_is_perl($_) }
      split /\n/ =>
      $self->_run( 'git', 'diff', '--name-only', "$primary_branch..." );
    return @files;
}

sub _get_diff {
    my ( $self, $file ) = @_;
    my $primary_branch = $self->primary_branch;
    my @diff =
      split /\n/ => $self->_run( 'git', 'diff', "$primary_branch...", $file );
    return @diff;
}

sub run {
    my $self = shift;

    # We walking through every file you've changed and parse the diff to
    # figure out the start and end of every change you've made. Any perlcritic
    # failures which are *not* on those lines are ignored
    my @files = $self->_get_modified_perl_files;
    my $found;
    my %reported;
    my @failures;
  FILE: foreach my $file (@files) {
        next FILE unless -e $file;    # it was deleted
        next FILE
          unless -s _ < $self->max_file_size;    # large files are very slow
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

sub _is_perl {
    my ( $self, $file ) = @_;
    return unless -e $file;    # sometimes we get non-existent files
    return 1 if $file =~ /\.(?:p[ml]|t)$/;
    open my $fh, '<', $file;
    my $first_line = <$fh>;
    close $fh;
    return $first_line =~ /^#!.*\bperl\b/;    # yeah, it's a heuristic
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
gentlest critique level. This module lets you only report Perl::Critic errors
on lines you've changed in your current branch.
