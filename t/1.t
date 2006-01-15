#!perl

# Test loading

use strict;
use warnings;

use Test::More tests => 1;

# Load module
BEGIN { use_ok('Config::Generic') };

