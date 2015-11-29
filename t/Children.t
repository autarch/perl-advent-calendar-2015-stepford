use strict;
use warnings;

use Test::More 0.96;

use Log::Dispatch;
use Log::Dispatch::TestDiag;
use Path::Class qw( tempdir );
use NN::Step::Children;

my $dir = tempdir( CLEANUP => 1 );

my $logger = Log::Dispatch->new(
    outputs => [ [ 'TestDiag', min_level => 'debug' ] ] );
NN::Step::Children->new(
    root_dir => $dir,
    logger   => $logger,
)->run;

my $file = $dir->file('children.csv');
ok( -e $file, "$file exists" );

my $content = $file->slurp;
like(
    $content,
    qr/(?:
            ^
            "[ a-zA-Z]+",
            \d+\.\d+\.\d+\.\d+
            \r\n
            $
        )+/msx,
    'content contains names & IPs in CSV form'
);

done_testing();
