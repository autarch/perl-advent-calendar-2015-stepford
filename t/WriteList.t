use strict;
use warnings;

use Test::More 0.96;

use Log::Dispatch;
use Log::Dispatch::TestDiag;
use Path::Class qw( tempdir );
use NN::Step::WriteList;
use Stepford::Runner;

my $dir = tempdir( CLEANUP => 1 );

my $logger = Log::Dispatch->new(
    outputs => [ [ 'TestDiag', min_level => 'debug' ] ] );
Stepford::Runner->new(
    step_namespaces => 'NN::Step',
    logger          => $logger,
    )->run(
    final_steps => 'NN::Step::WriteList',
    config => { root_dir => $dir },
    );

my $file = $dir->file('naughty-nice-list.txt');
ok( -e $file, "$file exists" );

my $content = $file->slurp;
for my $name ( 'Alexander Marer', 'Fay Delaney', 'Shing Hsu' ) {
    like(
        $content,
        qr/
            ^
            \Q$name\E\ is\ .+ \(-?\d+\).
            \n
            $
        /msx,
        "content contains evaluation for $name"
    );
}

done_testing();
