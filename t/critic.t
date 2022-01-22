#!/usr/bin/env perl

use Test::Most;
use Git::Critic;

ok my $critic = Git::Critic->new( primary_branch => 'main' ),
  'We should be able to create a git critic object';

is $critic->primary_branch, 'main', 'We can set the name of our primary branch';

$critic->_add_to_run_queue('current');
is $critic->current_branch, 'current', '... and our current branch';

$critic->_add_to_run_queue(<<'END');
lib/Git/Critic.pm
t/critic.t
not-perl.py
END
$DB::single = 1;
my @files = $critic->_get_modified_perl_files;
eq_or_diff \@files, [ 'lib/Git/Critic.pm', 't/critic.t' ],
  '... we should be able to get a list of modified files';

my @lines    = $critic->_get_diff('lib/Git/Critic.pm');
my @failures = $critic->run;
explain \@failures;

done_testing;
