#!perl

# Parse first valid specification

use strict;
use warnings;
use Config::Generic;
use File::Basename;

use Test::More qw(no_plan);

# Helper function
sub getcontent {
    my $fh;
    open($fh, "<", shift) or die $!;
    return join("", <$fh>);
}

my($parser,$config);

chdir(basename $0);

$parser = new Config::Generic(getcontent("valid-1.spec"));
ok($parser->isa("Config::Generic"));

# Test 5: Parse invalid files
for my $file (glob("invalid-1-*.rc")) {
    eval { $config = $parser->parse(getcontent($file)); };
    ok($@);
}


# Test 6: Parse invalid files
for my $file (glob("valid-1-*.rc")) {
    $config = $parser->parse(getcontent($file));
    ok($config->isa("Config::Generic::UnnamedSection"));
}
