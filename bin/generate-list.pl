#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../lib";

use Getopt::Long;
use Log::Dispatch;
use Stepford::Runner;

sub main {
    my $debug;
    my $jobs;
    my $root;

    GetOptions(
        'debug'  => \$debug,
        'jobs:i' => \$jobs,
        'root:s' => \$root,
    );

    my $logger = Log::Dispatch->new( outputs =>
            [ [ 'Screen', min_level => $debug ? 'debug' : 'warning' ] ] );

    Stepford::Runner->new(
        step_namespaces => 'NN::Step',
        logger          => $logger,
        )->run(
        config => { $root ? ( root_dir => $root ) : () },
        final_steps => 'NN::Step::WriteList',
        );

    exit 0;
}
