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
```

You'll see how to actually populate the `ip_scores_file` later.

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

Here's what I'm going to do:

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
* Combine the IP and name scores into a single score per child and generate a
  text file with the naughty/nice list.

If I make a dependency graph for those steps, here's what I come up with:

<a href="./step-graph.svg"><img src="./step-graph.svg" height="450" width="450"></a>

Looking at this graph, you can see a couple interesting things. First, three
are two steps, "Get list of children" and "Download GeoLite2 databases", with
no dependencies. Next, there are steps that are dependencies dependency for
more than one other steps, "Assign UUIDs" and "Get list of children". Finally,
the "Combine scores" step has three dependencies.

Figuring all this stuff out is what Stepford is for. In fact, it calculates a
graph just like this internally.

## Building our First Step

Let's start by building the step to "Get list of children". All the step
classes for a single set of steps should live under the same namespace. I'm
going to use `NN::Step` as our namespace prefix.

```perl
package NN::Step::Children;

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

has children_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_children_file',
);

sub run ($self) {
    my $file = $self->children_file;

    $self->logger->info("Writing names and IPs to $file");

    my $data = do {
        local $/;
        <DATA>;
    };

    # CSV line ending per http://tools.ietf.org/html/rfc4180
    $data =~ s/\n/\r\n/g;
    $file->spew($data);
}

sub _build_children_file ($self) {
    return $self->root_dir->file('children.csv');
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
...
```

Let's look at the interesting bits more closely.

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

has children_file => (
    traits  => ['StepProduction'],
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_children_file',
);
```

This class has two attributes. The `root_dir` attribute is neither a
dependency nor a production. You'll see how you can set this attribute later
on. The `children_file` attribute is a production. Some other steps will
depend on this production.

```perl
sub run ($self) {
    my $file = $self->children_file;

    $self->logger->info("Writing names and IPs to $file");

    my $data = do {
        local $/;
        <DATA>;
    };

    # CSV line ending per http://tools.ietf.org/html/rfc4180
    $data =~ s/\n/\r\n/g;
    $file->spew($data);
}
```

Every Step class must provide a `run` method. This method is expected to do
whatever work the step does. In this case I take the data in `DATA` and turn
it into a new CSV file.

The `logger` attribute it provided to each step by the
[`Stepford::Runner`](https://metacpan.org/pod/Stepford::Runner) class. You'll
learn more about that class later.

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

This step depends on the `children_file` created by the `Children`
step. Stepford will figure this out and make sure that the steps are run in
the correct order.

The `AssignUUIDs` step in turn has its own `StepProduction` which future steps
will depend on.

The remaining steps follow a similar pattern. They take an input file and
produce an output file. The last step, `WriteList`, is a little different,
so let's see how:

```perl
package NN::Step::WriteList;

use Moose;

with 'Stepford::Role::Step';
```

The first different is that I'm consuming the
[`Stepford::Role::Step`](https://metacpan.org/pod/Stepford::Role::Step) role
instead of
[`Stepford::Role::Step::FileGenerator`](https://metacpan.org/pod/Stepford::Role::Step::FileGenerator).

This is mostly so I can demonstrate how to write a `last_run_time` method.


```perl
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
```

This step has three dependencies, unlike the previous steps you've seen. Each
of these dependencies comes from a separate step. Stepford will figure all
that out for us and run those steps before this one.

And here's the `last_run_time` method:

```perl
sub last_run_time ($self) {
    my $file = $self->_naughty_nice_list;
    return undef unless -e $file;

    return $file->stat->mtime;
}
```

This is pretty straightforward. If the file exists, I return its last
modification time. If not, I return C<undef>.

Stepford uses the value of each step's `last_run_time` to determine whether or
not a given step needs to be run at all. If the data in a dependency is newer
than the data in the step that depends on that data, there's no point in
regenerating the dependency's data.

## Running Your Steps

Now that I've written my steps, how do I run them? Here's the script I wrote:

```perl#!/usr/bin/env perl

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

    my $logger = Log::Dispatch->new(
        outputs => [
            [
                'Screen',
                newline => 1,
                min_level => $debug ? 'debug' : 'warning',
            ]
        ]
    );

    Stepford::Runner->new(
        step_namespaces => 'NN::Step',
        logger          => $logger,
        )->run(
        config => { $root ? ( root_dir => $root ) : () },
        final_steps => 'NN::Step::WriteList',
        );

    exit 0;
}

main();
```

The only interesting bit is the piece where we use
[`Stepford::Runner`](https://metacpan.org/pod/Stepford::Runner).

```perl
    Stepford::Runner->new(
        step_namespaces => 'NN::Step',
        logger          => $logger,
        jobs            => $jobs // 1,
        )->run(
        config => { $root ? ( root_dir => $root ) : () },
        final_steps => 'NN::Step::WriteList',
        );
```

The `Stepford::Runner` constructor takes several named arguments. The
`step_namespaces` argument tells Stepford under what namespace it should look
for your steps. It will load all the classes that it finds here.

You can pass multiple namespaces as an array reference. When two steps have a
production of the same name, then the step that comes first i n the list of
namespaces wins. This is useful for testing, as it lets you mock out steps as
needed.

The logger can be any object that provides a certain set of methods (such as
`debug` and `info`).

Finally, if you set `jobs` to a value greater than one, Stepford will run
steps in parallel wherever possible, running to `$jobs` steps at once.

The call to the `run` method also accepts named argument. The `config`
argument is a hash reference that will be passed to the constructor of each
step class as it is created. Remember way back up above when I mentioned that
I'd show you how to set the `root_dir` attribute of the `NN::Step::Children`
class. This is how you do that.

The `final_steps` argument can be a single step class name, or an array
reference of names. This is what you're asking Stepford to do, and it will
figure out all the steps necessary to get there.

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

If you're in a similar situation, with a code base that executes a series of
steps towards one or more final products, then Stepford might be a good choice
for you as well.

It certainly worked well for those elves. Sure, the naughty and nice list they
get is complete and utter nonsense, but it's lot quicker to generate, giving
them more time for their pine juice-fueled Dark Souls speedruns.
