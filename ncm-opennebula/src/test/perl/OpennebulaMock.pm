package OpennebulaMock;

use Test::MockModule;
use Test::More;
use Data::Dumper;
use base 'Exporter';
use XML::Simple;

use rpcdata;

our @EXPORT = qw(rpc_history_reset rpc_history_ok diag_rpc_history);


my @rpc_history = ();
my @rpc_history_full = ();

# DEBUG only (can't get the output in unittests otherwise)
sub dlog {
    my ($type, @args) = @_;
    diag("[".uc($type)."] ".join(" ", @args));
}
our $nco = new Test::MockModule('NCM::Component::opennebula');
foreach my $type ("error", "info", "verbose", "debug", "warn") {
    $nco->mock( $type, sub { shift; dlog($type, @_); } );
}

sub dump_rpc {
    return Dumper(\@rpc_history);
}

sub diag_rpc_history {
    diag("DEBUG rpc_history ".join(", ", @rpc_history));
};

# similar to Test::Quattor::command_history_reset
sub rpc_history_reset {
    @rpc_history = ();
    @rpc_history_full = ();
}

# similar to Test::Quattor::command_history_ok
sub rpc_history_ok {
    my $rpcs = shift;

    my $lastidx = -1;
    foreach my $rpc (@$rpcs) {
        # start iterating from lastidx+1
        my ( $index )= grep { $rpc_history[$_] =~ /$rpc/  } ($lastidx+1)..$#rpc_history;
        return 0 if !defined($index) or $index <= $lastidx;
        $lastidx = $index;
    };
    # in principle, when you get here, all is ok.                                                                                                                                        
    # but at least 1 command should be found, so lastidx should be > -1                                                                                                                  

    return $lastidx > -1;
    
}

sub mock_rpc_basic {
    my ($self, $method, @params) = @_;
    push(@rpc_history, $method);
    push(@rpc_history_full, [$method, @params]);
    if ($method eq "one.host.allocate") {
        return []; # return ARRAY
    } else {
        return ();# return hash reference
    }
};


sub mock_rpc {
    my ($self, $method, @params) = @_;
    my @params_values;
    foreach my $param (@params) {
        push(@params_values, $param->[1]);
    };

    push(@rpc_history, $method);
    push(@rpc_history_full, [$method, @params]);
    # we need to reset the loop for some reason
    keys %rpcdata::cmds;
    while (my ($short, $data) = each %rpcdata::cmds) {
        my $sameparams = join(" _ ", @params_values) eq join(" _ ", @{$data->{params}});
        my $samemethod = $method eq $data->{method};
        note("This is my shortname:", $short);
        note("rpc internal params: ", join(" _ ", @params_values));
        note("rpc dictionary params: ", join(" _ ", @{$data->{params}})); 
        note("rpc method: ", $method);

        if ($samemethod && $sameparams && defined($data->{out})) {
	        if ($data->{out} =~ m/^\d+$/) {
                note("is id ", $data->{out});
                return $data->{out};
            } else {
                note("is xml ", $data->{out});
                return XMLin($data->{out}, forcearray => 1);
	        } 
        }
    }
};

sub mock_ssh {
    my ($self, $command, $host) = @_;
    # reset loop
    keys %sshdata::ssh;
    while (my ($short, $data) = each %sshdata::ssh) {
        my $sameparams = $command eq $data->{command};
        note("This is my shortname:", $short);
        note("ssh internal command: ", $command);
        note("ssh dictionary command: ", $data->{command});
        
        if ($sameparams) {
            note("ssh command found: ", $data->{out});
            return $data->{out};
        }

    }
};

our $opennebula = new Test::MockModule('Net::OpenNebula');
$opennebula->mock( '_rpc',  \&mock_rpc);

1;
