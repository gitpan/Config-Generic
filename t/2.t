#!perl

# Test invalid specifications

use strict;
use warnings;
use File::Basename;

use Test::More qw(no_plan);
use Config::Generic;

# Helper function
sub getcontent {
    my $fh;
    open($fh, "<", shift) or die $!;
    return join("", <$fh>);
}

my($parser,$config);

chdir(dirname $0);
for my $file (glob("invalid-*.spec")) {
    eval { $parser = new Config::Generic(getcontent($file)) };
    ok($@);
}

