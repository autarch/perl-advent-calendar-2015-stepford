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

has children_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has children_with_uuids_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_children_with_uuids_file',
);

sub run ($self) {
    my $in_fh  = $self->children_file->openr;
    my $file   = $self->children_with_uuids_file;
    my $out_fh = $file->openw;

    $self->logger->info("Adding UUIDs and writing to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline($in_fh) ) {
        $csv->print( $out_fh, [ @{$fields}, Data::GUID->new->as_string ] );
    }

    close $in_fh;
    close $out_fh;
}

sub _build_children_with_uuids_file ($self) {
    return $self->children_file->parent->file('children-with-uuids.csv');
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Assign UUIDs to each child
