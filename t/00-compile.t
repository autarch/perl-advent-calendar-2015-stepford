use strict;
use warnings;

use Test::Compile;

Test::Compile->new->all_files_ok;
Test::Compile->new->done_testing;
