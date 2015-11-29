use strict;
use warnings;

use Test::More 0.96;

use Log::Dispatch;
use Log::Dispatch::TestDiag;
use Path::Class qw( tempdir );
use NN::Step::ScoreNames;
use Stepford::Runner;

my $dir = tempdir( CLEANUP => 1 );

my $logger = Log::Dispatch->new(
    outputs => [ [ 'TestDiag', min_level => 'debug' ] ] );
Stepford::Runner->new(
    step_namespaces => 'NN::Step',
    logger          => $logger,
    )->run(
    final_steps => 'NN::Step::ScoreNames',
    config => { root_dir => $dir },
    );

my $file = $dir->file('name-scores.csv');
ok( -e $file, "$file exists" );

my $content = $file->slurp;
like(
    $content,
    qr/(?:
            ^
            [A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12},
            -?\d+
            \r\n
            $
        )+/msx,
    'content contains UUIDs and scores'
);

done_testing();
