#-*- mode: cperl -*-
use strict;
use warnings;

use Test::Quattor qw(simple);
use Test::More;
use NCM::Component::nrpe;
use CAF::Object;

my $cmp = NCM::Component::nrpe->new('nrpe');

my $cfg = get_config_for_profile('simple');

=pod

=head1 DESCRIPTION

Tests for the ncm-nrpe component

This is a very simplistic component.  We'll just check it writes a
correct file and it detects successful and failed restarts of the
daemon.

=cut

is($cmp->Configure($cfg), 1, "Normal execution succeeds");

my $fh = get_file("/etc/nagios/nrpe.cfg");

like($fh, qr{^allowed_hosts=a,b$}m, "allowed_hosts printed correctly");
like($fh, qr{^command\[cmd\]=foobar$}m, "command lines printed correctly");
like($fh, qr{^include=foo$}m, "include lines printed correctly");
like($fh, qr{^include_dir=bar$}m, "include_dir lines printed correctly");

like($fh, qr{^nrpe_user=nagios$}m, "Ordinary lines printed correctly");

# Set failing restart
set_command_status("service nrpe restart", 1);
is($cmp->Configure($cfg), 1, "No failure reported, restart no called (no changes in file)");


# reset contents, to trigger a failing restart
set_file_contents('/etc/nagios/nrpe.cfg', '#empty');
is($cmp->Configure($cfg), 0, "Failure in restart is notified");
is($cmp->{ERROR}, 1, "Error is reported");

done_testing();
