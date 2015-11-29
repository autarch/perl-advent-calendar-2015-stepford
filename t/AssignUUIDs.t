use strict;
use warnings;

use Test::More 0.96;

use Log::Dispatch;
use Log::Dispatch::TestDiag;
use Path::Class qw( tempdir );
use NN::Step::AssignUUIDs;
use Stepford::Runner;

my $dir = tempdir( CLEANUP => 1 );

my $logger = Log::Dispatch->new(
    outputs => [ [ 'TestDiag', min_level => 'debug' ] ] );
Stepford::Runner->new(
    step_namespaces => 'NN::Step',
    logger          => $logger,
    )->run(
    final_steps => 'NN::Step::AssignUUIDs',
    config => { root_dir => $dir },
    );

my $file = $dir->file('names-and-ips-with-uuids.csv');
ok( -e $file, "$file exists");

my $content = $file->slurp;
like(
    $content,
    qr/(?:
            ^
            "[ a-zA-Z]+",
            \d+\.\d+\.\d+\.\d+,
            [A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12}
            \r\n
            $
        )+/msx,
    'content contains names, IPs, and UUIDs'
);

done_testing();
