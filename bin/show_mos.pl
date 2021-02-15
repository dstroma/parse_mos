#!/usr/bin/perl

use warnings;
use strict;
use lib './lib/';
use Geo::MOS::Fetch;
use Geo::MOS::Parse;

my $loc = $ARGV[0];
die 'No location given' unless $loc;

my $fetcher  = Geo::MOS::Fetch->new(location => $loc);
my $forecast = $fetcher->fetch;

my $parsed  = Geo::MOS::Parse->new(plaintext => $forecast);
my $report  = $parsed->report(timezone => 'America/New_York');

print $report;

