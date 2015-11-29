package NN::Step::DownloadGeoLite2;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use IO::Uncompress::Gunzip qw( gunzip $GunzipError );
use LWP::Simple qw( getstore is_success );
use MooseX::Types::Path::Class qw( Dir File );
use Path::Class qw( tempdir );

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has root_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '.',
);

has geolite2_database_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_geolite2_database_file',
);

sub run ($self) {
    my $dir = tempdir( CLEANUP => 1 );
    my $gz_file = 'GeoLite2-City.mmdb.gz';

    my $url
        = 'http://geolite.maxmind.com/download/geoip/database/' . $gz_file;
    $self->logger->info("Downloading $url");

    my $dl_to = $dir->file($gz_file);
    my $status = getstore( $url, $dl_to->stringify );
    die "Could not download $url (status = $status)"
        unless is_success($status);

    gunzip( $dl_to->stringify => $self->geolite2_database_file->stringify )
        or die "Could gunzip $dl_to: $GunzipError";

    return;
}

sub _build_geolite2_database_file ($self) {
    return $self->root_dir->file('GeoLite2-City.mmdb');
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Download the GeoLite2 City database file
