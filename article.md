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
[Stepford::Runner](https://metacpan.org/pod/Stepford::Runner) object. Steps
are Perl classes built using Moose. Step dependencies are attributes with a
special `trait`.

## Dependencies and Productions

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

Looking at this graph, we can see a couple interesting things. First, we two
steps, "Get all names & IPs" and "Download GeoLite2 databases", with no
dependencies. Next, we have one step that is a dependency for two other steps,
"Assign UUIDs". Finally, the "Combine scores" step has two dependencies.

Figuring all this stuff out is what Stepford is for, and in fact it calculates
a graph just like this internally.

## Building our First Step

Let's start by building the step to "Get all names & IPs". All Stepford steps
for a single set of steps should live under the same namespace. We're going to
use `NN::Step` as our namespace prefix.

```perl
package NN::Step::NamesAndIPs;

use strict;



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
