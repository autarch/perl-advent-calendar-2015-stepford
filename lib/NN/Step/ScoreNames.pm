package NN::Step::ScoreNames;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use List::Util 1.33 qw( sum );
use MooseX::Types::Path::Class qw( File );
use Text::CSV_XS;

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has children_with_uuids_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has name_scores_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_name_scores_file',
);

sub run ($self) {
    my $in_fh  = $self->children_with_uuids_file->openr;
    my $file   = $self->name_scores_file;
    my $out_fh = $file->openw;

    $self->logger->info("Writing name scores to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline($in_fh) ) {
        $csv->print(
            $out_fh,
            [ $fields->[-1], $self->_score_for_name( $fields->[0] ) ]
        );
    }

    close $in_fh;
    close $out_fh;
}

sub _score_for_name ($self, $name) {

    # We all know that serial killers have three names. Serial killers are
    # very naughty.
    if ( ( split / /, $name ) == 3 ) {
        return -666;
    }

    # My wife is very nice so anyone with the same first name must be nice
    # too.
    if ( $name =~ /^Huey-Ling/ ) {
        return 50;
    }

    # That's some bad luck.
    if ( length $name == 13 ) {
        return -13;
    }

    # Lucky 7s.
    if ( ( length $name ) % 7 == 0 ) {
        return ( ( length $name ) / 7 ) * 5;
    }

    # XXX - investigate Kabbalastic numerology?
    #
    # Time to get really scientific about this!
    my ( $first, $last ) = split / /, $name;
    return ( ( sum( map { ord $_ } split //, $first ) )
        - ( sum( map { ord $_ } split //, $last ) ) );
}

sub _build_name_scores_file ($self) {
    return $self->children_with_uuids_file->parent->file('name-scores.csv');
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Score each name
