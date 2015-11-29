package NN::Step::AssignUUIDs;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use Data::GUID;
use MooseX::Types::Path::Class qw( File );
use Text::CSV_XS;

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has names_and_ips_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has names_and_ips_with_uuids_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_names_and_ips_with_uuids_file',
);

sub run ($self) {
    my $in_fh  = $self->names_and_ips_file->openr;
    my $file   = $self->names_and_ips_with_uuids_file;
    my $out_fh = $file->openw;

    $self->logger->info("Adding UUIDs and writing to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline($in_fh) ) {
        $csv->print( $out_fh, [ @{$fields}, Data::GUID->new->as_string ] );
    }
}

sub _build_names_and_ips_with_uuids_file ($self) {
    return $self->names_and_ips_file->parent->file(
        'names-and-ips-with-uuids.csv');
}

__PACKAGE__->meta->make_immutable;

1;
