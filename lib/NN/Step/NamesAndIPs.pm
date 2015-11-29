package NN::Step::NamesAndIPs;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use MooseX::Types::Path::Class qw( Dir File );

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has root_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '.',
);

has names_and_ips_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_names_and_ips_file',
);

sub run ($self) {
    my $file = $self->names_and_ips_file;

    $self->logger->info("Writing names and IPs to $file");

    my $data = do {
        local $/;
        <DATA>
    };
    # CSV line ending per http://tools.ietf.org/html/rfc4180
    $data =~ s/\n/\r\n/g;
    $file->spew($data);
}

sub _build_names_and_ips_file ($self) {
    return $self->root_dir->file('names-and-ips.csv');
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
"Alexander Marer",42.235.92.147
"Andrew Bernard Cray",205.145.143.62
"Aziz Koury",87.160.78.69
"Dessa Rowlins",155.135.137.3
"Don Beasley",99.234.11.102
"Eliza Danielsson",239.31.31.175
"Fay Delaney",169.17.211.36
"Francois Vo",152.105.252.87
"Gabrysia Dudek",122.111.226.225
"Hildegard Brinton",211.63.237.205
"Huey-Ling Chen",106.91.124.141
"Jian Lung",190.43.11.31
"Katsuki Akimoto",193.3.30.143
"Larry Pooter",173.11.12.99
"Lung Thi Ang Tau",43.234.155.190
"Marius Duckler",95.151.247.254
"Nino Calabrese",74.41.205.12
"Rafaela Lira",148.172.205.63
"Ronald Crump",236.198.51.246
"Shing Hsu",104.128.60.60
"Stanislawa Kowalska",71.216.33.158
"Thalia Arana",189.161.98.89
