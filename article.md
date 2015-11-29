# Building Santa's Naughty and Nice List with Stepford

Keeping the naughty and nice list up to date has been taking up way too much
elvish time that they'd rather use for drinking pine juice and playing Dark
Souls. So the elves pooled their money and hired me to automate building the
list. Looking at how they'd built the list before, I realized that
[Stepford](https://metacpan.org/release/Stepford) was the perfect tool for the
job!

## What is Stepford?

[Stepford](https://metacpan.org/release/Stepford) is a tool that takes a set
of steps (tasks), figures out their dependencies, and then runs them in the
right order to get the result you ask for. The result itself is just another
step that you specify when creating the
[`Stepford::Runner`](https://metacpan.org/pod/Stepford::Runner) object. Steps
are Perl classes built using Moose. Step dependencies are attributes with a
special `trait`.

### Dependencies and Productions

The "big thing" that Stepford does for you is look at the dependencies and
productions of all your steps in order to figure out the overall dependency
tree for the result you asked for.

Both dependencies and productions are declared as Moose attributes with a
special `trait`. Here's an example;

```perl
has geolite2_database => (
    traits   => ['StepDependency'],
    is       => 'ro',
    isa      => File,
    required => 1,
);

has scored_ip_list => (
    traits   => ['StepProduction'],
    is       => 'ro',
    isa      => File,
);
```

We'll see how to actually populate the `scored_ip_list` later.

Stepford matches a production to a dependency solely by name, which means that
attribute names for productions and dependencies must be unique to a given set
of steps.

### Step Classes

A "Step class" is any class which consumes the
[`Stepford::Role::Step`](https://metacpan.org/pod/Stepford::Role::Step) role
(or another role which in turn consumes that role).

## What Goes Into the Naughty and Nice List?

The elves gave me a long list of requirements, but honestly it all seemed like
too much trouble. And since these elves are not very technically savvy, I'm
going to take the easy route instead and just make some stuff up.

Here's what we're going to do:

* Get the names and IP addresses for all the children in the world, or at
  least a few of them and assign them a UUID.
* Download the
  [free GeoLite2 database](http://dev.maxmind.com/geoip/geoip2/geolite2/) from
  MaxMind.
* Use the GeoLite2 database to look at each child's geographical location and
  use that to give their IP a naughty/nice score. This will be very
  scientific.
* Look at each child's name and use that to give their name a naughty/nice
  score. Again, this will be very scientific.
* Combine the IP and name scores into a single score per child and store that
  in a SQLite database.

If we make a dependency graph for those steps, here's what we come up with:

<a href="./step-graph.svg"><img src="./step-graph.svg" height="450" width="450"></a>

Looking at this graph, we can see a couple interesting things. First, we have
two steps, "Get all names & IPs" and "Download GeoLite2 databases", with no
dependencies. Next, we have steps that are dependencies dependency for more
than one other steps, "Assign UUIDs" and "Get all names & IPs". Finally, the
"Combine scores" step has three dependencies.

Figuring all this stuff out is what Stepford is for. In fact, it calculates a
graph just like this internally.

## Building our First Step

Let's start by building the step to "Get all names & IPs". All Stepford steps
for a single set of steps should live under the same namespace. We're going to
use `NN::Step` as our namespace prefix.

```perl
package NN::Step::NamesAndIPs;

use strict;
use warnings;
use autodie;
use experimental 'signatures';

use Data::GUID;
use MooseX::Types::Path::Class qw( Dir File );
use Text::CSV_XS;

use Moose;

with 'Stepford::Role::Step::FileGenerator';

no warnings 'experimental::signatures';

has root_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '.',
);

has name_and_ip_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_name_and_ip_file',
);

sub run ($self) {
    my $file = $self->name_and_ip_file;
    my $fh   = $file->openw;

    $self->logger->info("Writing names and IPs with UUID to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline(*DATA) ) {
        $csv->print( $fh, [ @{$fields}, Data::GUID->new->as_string ] );
    }

    close $fh;
}

sub _build_name_and_ip_file ($self) {
    return $self->root_dir->file('names-and-ips-with-uuids.csv');
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
...
```

Let's look at the interest bits more closely.

```perl
with 'Stepford::Role::Step::FileGenerator';
```

All Stepford classes must consume one of the Step roles provided by
Stepford. This particular role tells Stepford that all of this step's outputs
are in the form of files. This lets Stepford calculate the step's last run
time by looking at the file's modification time. For non-file steps, you have
to provide a `last_run_time` method of your own.

```perl
has root_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => '.',
);

has name_and_ip_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_name_and_ip_file',
);
```

This class has two attributes. The `root_dir` attribute is neither a
dependency nor a production. We'll see how we can set these sorts of
attributes later on. The `name_and_ip_file` attribute is a production. Some
other steps will depend on this production.

```perl
sub run ($self) {
    my $file = $self->name_and_ip_file;
    my $fh   = $file->openw;

    $self->logger->info("Writing names and IPs with UUID to $file");

    my $csv = Text::CSV_XS->new( { eol => "\r\n" } );
    while ( my $fields = $csv->getline(*DATA) ) {
        $csv->print( $fh, [ @{$fields}, Data::GUID->new->as_string ] );
    }

    close $fh;
}
```

Every Step class must provide a `run` method. This method is expected to do
whatever work the step does. In this case we take the data in `DATA` and turn
it into a new CSV file.

### Atomic File Steps

I could have used
[`Stepford::Role::Step::FileGenerator::Atomic`](https://metacpan.org/pod/Stepford::Role::Step::FileGenerator::Atomic)
instead. If your step is writing a file, using this role will prevent you from
leaving behind a half-finished file if the step exits mid-work. I didn't use
it in my example code just to keep things a little simpler, but I highly
recommend it for production code.

## More Steps

The other steps are pretty similar. They take some data and spit something new
out, usually a file. Let's take a look at a selection from the step that adds
the UUIDs:

```perl
package NN::Step::AssignUUIDs;

...

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
```

This step depends on the `children_file` created by the `NamesAndIPs`
step. Stepford will figure this out and make sure that the steps are run in
the correct order.

The `AssignUUIDs` step in turn has its own `StepProduction` which future steps
will depend on.

The remaining steps follow a similar pattern. They take an input file and
produce an output file. The last step, `CombineScores`, is a little different,
so let's see how:



## Why Stepford?

Stepford is lot like `make`, `rake`, and many other tools. Stepford was
originally created to help improve our automation around building
[GeoIP databases](https://www.maxmind.com/en/geoip2-databases) at
[MaxMind](https://www.maxmind.com/).

I investigated `make` and `rake`, which are both great tools. However, what
makes them shine is how they integrate with certain environments. The `make`
tool is great is you're interacting with a lot of existing command line tools
like compilers, linkers, etc. And of course `rake` is great if you're dealing
with existing Ruby code.

But our database building code was going to be written in Perl, so it made
sense to write a tool in Perl.
