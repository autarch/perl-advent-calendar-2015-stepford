#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw( $Bin );
use GraphViz2;

sub main {
    my $gv = GraphViz2->new(
        global => { directed => 1 },
        graph => {
            size  => '10,10',
            ratio => 'fill',
        },
    );

    $gv->add_edge(
        from => 'Get list of children',
        to   => 'Assign UUIDs',
    );

    $gv->add_edge(
        from => 'Assign UUIDs',
        to   => 'Name score',
    );

    $gv->add_edge(
        from => 'Assign UUIDs',
        to   => 'IP score',
    );

    $gv->add_edge(
        from => 'Download GeoLite2 database',
        to   => 'IP score',
    );

    $gv->add_edge(
        from => 'Get list of children',
        to   => 'Combine scores',
    );

    $gv->add_edge(
        from => 'IP score',
        to   => 'Combine scores',
    );

    $gv->add_edge(
        from => 'Name score',
        to   => 'Combine scores',
    );

    $gv->run(
        format      => 'svg',
        output_file => "$Bin/../output/step-graph.svg",
    );
}

main();
