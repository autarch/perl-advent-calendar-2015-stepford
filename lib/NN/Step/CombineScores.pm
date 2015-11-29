package NN::Step::CombineScores;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use MooseX::Types::Path::Class qw( File );
use Text::CSV_XS;

use Moose;

with 'Stepford::Role::Step';

no warnings 'experimental::signatures';

has children_with_uuids_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has ip_scores_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has name_scores_file => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has _naughty_nice_list => (
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_naughty_nice_list',
);

sub run ($self) {
    $self->logger->info('Scoring all the children');

    my %children    = $self->_children_by_uuid;
    my %ip_scores   = $self->_ip_scores;
    my %name_scores = $self->_name_scores;

    my $fh = $self->_naughty_nice_list->openw;

    for my $name ( sort { lc $a cmp lc $b } keys %children ) {
        my $uuid        = $children{$name}{uuid};
        my $total_score = $ip_scores{$uuid} + $name_scores{$uuid};

        print {$fh} "$name is "
            . $self->_interpret_score($total_score)
            . " ($total_score).\n";
    }
}

sub last_run_time ($self) {
    my $file = $self->_naughty_nice_list;
    return undef unless -e $file;

    return $file->stat->mtime;
}

sub _children_by_uuid ($self) {
    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    $csv->column_names(qw( name ip uuid ));

    my $fh = $self->children_with_uuids_file->openr;

    my %children;
    while ( my $child = $csv->getline_hr($fh) ) {
        $children{ $child->{name} } = $child;
    }
    return %children;
}

sub _ip_scores ($self) {
    return $self->_scores_from( $self->ip_scores_file );
}

sub _name_scores ($self) {
    return $self->_scores_from( $self->name_scores_file );
}

sub _scores_from ($self, $file) {
    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    $csv->column_names(qw( uuid score ));

    my $fh = $file->openr;

    my %scores;
    while ( my $item = $csv->getline_hr($fh) ) {
        $scores{ $item->{uuid} } = $item->{score};
    }
    return %scores;
}

sub _interpret_score ($self, $score) {
    if ( $score < -500 ) {
        return 'very, very naughty and should be eaten by Krampus';
    }
    elsif ( $score < -50 ) {
        return 'fairly naughty and deserves coal';
    }
    elsif ( $score < 0 ) {
        return 'a bit naughty and deserves sock as a gift';
    }
    elsif ( $score > 500 ) {
        return 'very, very nice and deserves all the toys';
    }
    elsif ( $score > 50 ) {
        return 'fairly nice and deserves one nice gift';
    }
    else {
        return
            'nice (but not all that nice) and deserve a gift along with a reminder that they can do better';
    }
}

sub _build_naughty_nice_list ($self) {
    return $self->children_with_uuids_file->parent->file(
        'naughty-nice-list.txt');
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Combines scores to produce the final list
