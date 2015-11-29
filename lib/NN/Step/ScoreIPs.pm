package NN::Step::ScoreIPs;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use GeoIP2::Database::Reader;
use List::Util 1.33 qw( sum );
use MooseX::Types::Path::Class qw( File );
use Text::CSV_XS;
use Try::Tiny;

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has children_with_uuids_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has geolite2_database_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has ip_scores_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_ip_scores_file',
);

has _geoip2_reader => (
    is      => 'ro',
    isa     => 'GeoIP2::Database::Reader',
    lazy    => 1,
    default => sub ($self) {
        GeoIP2::Database::Reader->new(
            file    => $self->geolite2_database_file,
            locales => ['en'],
        );
    },
);

sub run ($self) {
    my $in_fh  = $self->children_with_uuids_file->openr;
    my $file   = $self->ip_scores_file;
    my $out_fh = $file->openw;

    $self->logger->info("Writing IP scores to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline($in_fh) ) {
        $csv->print(
            $out_fh,
            [ $fields->[-1], $self->_score_for_ip( $fields->[1] ) ]
        );
    }

    close $in_fh;
    close $out_fh;
}

sub _score_for_ip ($self, $ip) {
    my $reader = $self->_geoip2_reader;
    my $model = try { $reader->city( ip => $ip ) };

    # No record? They must be at least a little naughty.
    return -5 unless $model;

    # Yay, Taiwan!
    if ( ( $model->country->name // q{} ) =~ 'Taiwan' ) {
        return 142;
    }

    my $city_name = $model->city->name // q{};

    # All the cool people live here.
    if ( $city_name eq 'Minneapolis' ) {
        return 500;
    }

    # I really didn't like growing up here very much. Too many naughty people!
    if ( $city_name eq 'North Haven' ) {
        return -100;
    }

    # Back to good old numerology
    my $country_score = sum( map { ord $_ } map { split //, ( $_ // q{} ) }
            ( $model->country->name ) ) // 15;
    my $city_score = ( sum( map { ord $_ } split //, $city_name ) ) // 20;

    return $country_score = $city_score;
}

sub _build_ip_scores_file ($self) {
    return $self->children_with_uuids_file->parent->file('ip-scores.csv');
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Score each IP
