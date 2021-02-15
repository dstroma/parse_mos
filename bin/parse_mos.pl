#!/usr/bin/perl

use warnings;
use strict;
use lib './lib/';
use Geo::MOS::Parse;

my $file = $ARGV[0];
die 'No file given' unless $file;

open my $fh, '<', $file;
my $forecast = join('', <$fh>);
close $fh;

my $parsed  = Geo::MOS::Parse->new(plaintext => $forecast);
my $report  = $parsed->report(); # timezone => 'America/New_York');

print $report;

